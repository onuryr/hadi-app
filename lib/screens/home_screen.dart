import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_cluster_manager_2/google_maps_cluster_manager_2.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'login_screen.dart';
import 'create_activity_screen.dart';
import 'activity_detail_screen.dart';
import 'profile_screen.dart';
import 'inbox_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../services/chat_service.dart';
import '../services/deep_link_service.dart';
import '../services/favorites_service.dart';
import '../utils/category_defaults.dart';
import '../widgets/activity_card_skeleton.dart';
import '../widgets/clustered_activities_map.dart';
import '../widgets/verified_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;
  String? _error;
  int? _selectedCategoryId;
  double? _cachedLat;
  double? _cachedLng;
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _showMap = false;
  String _searchQuery = '';
  int _radiusKm = 10;
  String _sortBy = 'distance';
  String _whenFilter = 'all'; // all | tonight | weekend | next_week
  int _unreadCount = 0;
  Set<String> _favoriteIds = {};
  Timer? _searchDebounce;

  static const _radiusOptions = [5, 10, 25, 50, 100];
  Map<String, String> _sortOptions(AppLocalizations l) => {
    'distance': l.sortDistance,
    'date': l.sortDate,
    'participants': l.sortParticipants,
    'newest': l.sortNewest,
  };
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const _apiBase = 'https://hadi-production-e4f3.up.railway.app';
  static const _pageSize = 15;

  static const _categories = [
    {'id': 1, 'name': 'Yürüyüş', 'icon': '🚶'},
    {'id': 2, 'name': 'Koşu', 'icon': '🏃'},
    {'id': 3, 'name': 'Halı Saha', 'icon': '⚽'},
    {'id': 4, 'name': 'Basketbol', 'icon': '🏀'},
    {'id': 5, 'name': 'Bisiklet', 'icon': '🚴'},
    {'id': 6, 'name': 'Konser', 'icon': '🎵'},
    {'id': 7, 'name': 'Tiyatro', 'icon': '🎭'},
    {'id': 8, 'name': 'Yemek', 'icon': '🍽️'},
    {'id': 9, 'name': 'Müze', 'icon': '🏛️'},
    {'id': 10, 'name': 'Sinema', 'icon': '🎬'},
    {'id': 11, 'name': 'Kahve', 'icon': '☕'},
    {'id': 12, 'name': 'Oyun', 'icon': '🎲'},
    {'id': 13, 'name': 'Doğa', 'icon': '⛺'},
    {'id': 14, 'name': 'Dans', 'icon': '💃'},
    {'id': 15, 'name': 'Atölye', 'icon': '🎨'},
    {'id': 16, 'name': 'Yoga', 'icon': '🧘'},
    {'id': 17, 'name': 'Diğer', 'icon': '✨'},
  ];

  RealtimeChannel? _messageChannel;
  String? _myAvatarUrl;
  List<Map<String, dynamic>> _trending = [];

  @override
  void initState() {
    super.initState();
    _loadPrefsAndActivities();
    _loadMyAvatar();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loadingMore &&
          _hasMore) {
        _loadMore();
      }
    });
    _subscribeToMessages();
  }

  Future<void> _loadMyAvatar() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await _supabase
          .from('users')
          .select('avatar_url')
          .eq('id', uid)
          .maybeSingle();
      if (mounted) {
        setState(() => _myAvatarUrl = row?['avatar_url'] as String?);
      }
    } catch (_) {}
  }

  Future<void> _loadPrefsAndActivities() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _radiusKm = prefs.getInt('home_radius_km') ?? 10;
      _sortBy = prefs.getString('home_sort_by') ?? 'distance';
    });
    _loadActivities();
  }

  Future<void> _savePref(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is int) await prefs.setInt(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  void _subscribeToMessages() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    _messageChannel = _supabase.channel('home_messages_$userId');
    _messageChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final senderId = payload.newRecord['sender_id']?.toString();
            if (senderId != null && senderId != userId) {
              _refreshUnread();
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_messageChannel != null) _supabase.removeChannel(_messageChannel!);
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _searchQuery = value.trim());
      _loadActivities();
    });
  }

  Future<Position?> _getLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    // Hızlı yol: son bilinen konum
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) return lastKnown;
    // Fallback: yeni konum iste (yavaş)
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 3),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTrending() async {
    if (_cachedLat == null) return [];
    final params = {
      'lat': _cachedLat.toString(),
      'lng': _cachedLng.toString(),
      'radiusKm': '50',
      'limit': '8',
    };
    final uri = Uri.parse('$_apiBase/api/activities/trending').replace(queryParameters: params);
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map<Map<String, dynamic>>((item) => {
      'id': item['id'],
      'title': item['title'],
      'location_name': item['locationName'],
      'scheduled_at': item['scheduledAt'],
      'max_participants': item['maxParticipants'],
      'distance_km': item['distanceKm'],
      'participant_count': item['participantCount'],
      'category_name': item['categoryName'],
      'creator_name': item['creatorName'],
      'creator_rating_avg': item['creatorRatingAvg'],
      'creator_is_verified': item['creatorIsVerified'] == true,
      'creator_rating_count': item['creatorRatingCount'],
      'lat': item['lat'],
      'lng': item['lng'],
      'image_url': item['imageUrl'],
      'category_id': categoryNameToId[item['categoryName'] as String? ?? ''],
    }).toList();
  }

  Future<(List<Map<String, dynamic>>, bool)> _fetchPage(int page) async {
    if (_cachedLat == null) {
      final position = await _getLocation();
      _cachedLat = position?.latitude ?? 41.0082;
      _cachedLng = position?.longitude ?? 29.0234;
    }
    final params = {
      'lat': _cachedLat.toString(),
      'lng': _cachedLng.toString(),
      'radiusKm': _radiusKm.toString(),
      'sortBy': _sortBy,
      'page': page.toString(),
      'pageSize': _pageSize.toString(),
      if (_selectedCategoryId != null) 'categoryId': _selectedCategoryId.toString(),
      if (_searchQuery.isNotEmpty) 'q': _searchQuery,
    };
    final uri = Uri.parse('$_apiBase/api/activities/nearby').replace(queryParameters: params);
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Sunucu hatası: ${response.statusCode}');
    final Map<String, dynamic> decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> data = decoded['items'] as List<dynamic>;
    final bool hasMore = decoded['hasMore'] as bool? ?? false;
    final items = data.map<Map<String, dynamic>>((item) => {
      'id': item['id'],
      'title': item['title'],
      'location_name': item['locationName'],
      'scheduled_at': item['scheduledAt'],
      'max_participants': item['maxParticipants'],
      'distance_km': item['distanceKm'],
      'participant_count': item['participantCount'],
      'category_name': item['categoryName'],
      'creator_name': item['creatorName'],
      'creator_rating_avg': item['creatorRatingAvg'],
      'creator_is_verified': item['creatorIsVerified'] == true,
      'creator_rating_count': item['creatorRatingCount'],
      'lat': item['lat'],
      'lng': item['lng'],
      'image_url': item['imageUrl'],
      'category_id': categoryNameToId[item['categoryName'] as String? ?? ''],
    }).toList();
    return (items, hasMore);
  }

  Future<void> _loadActivities() async {
    final loadStart = DateTime.now();
    setState(() { _loading = true; _error = null; _page = 1; _loadingMore = false; });
    try {
      final (pageResult, favs) = await (
        _fetchPage(1),
        FavoritesService.getFavoriteIds(),
      ).wait;
      final (items, hasMore) = pageResult;
      final elapsed = DateTime.now().difference(loadStart);
      if (elapsed < const Duration(milliseconds: 300)) {
        await Future.delayed(const Duration(milliseconds: 300) - elapsed);
      }
      setState(() {
        _activities = items;
        _favoriteIds = favs;
        _page = 1;
        _hasMore = hasMore;
        _loading = false;
      });
      _refreshUnread();
      _loadTrending();
    } catch (e) {
      final elapsed = DateTime.now().difference(loadStart);
      if (elapsed < const Duration(milliseconds: 300)) {
        await Future.delayed(const Duration(milliseconds: 300) - elapsed);
      }
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _loadingMore = false);
    try {
      final (pageResult, favs) = await (
        _fetchPage(1),
        FavoritesService.getFavoriteIds(),
      ).wait;
      final (items, hasMore) = pageResult;
      setState(() {
        _activities = items;
        _favoriteIds = favs;
        _page = 1;
        _hasMore = hasMore;
        _error = null;
      });
      _refreshUnread();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).refreshError)),
        );
      }
    }
  }

  Future<void> _refreshUnread() async {
    final count = await ChatService.unreadActivityCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  ({DateTime? from, DateTime? to}) _whenRange() {
    final now = DateTime.now();
    switch (_whenFilter) {
      case 'tonight':
        final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (from: now, to: endOfToday);
      case 'weekend':
        // Saturday + Sunday of current week (or upcoming if past)
        final daysUntilSat = (DateTime.saturday - now.weekday) % 7;
        final sat = DateTime(now.year, now.month, now.day + daysUntilSat);
        final sunEnd = sat.add(const Duration(days: 2)).subtract(const Duration(seconds: 1));
        return (from: sat.isBefore(now) ? now : sat, to: sunEnd);
      case 'next_week':
        final daysUntilMon = (DateTime.monday - now.weekday) % 7;
        final mon = DateTime(now.year, now.month, now.day + (daysUntilMon == 0 ? 7 : daysUntilMon));
        final sunEnd = mon.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
        return (from: mon, to: sunEnd);
      default:
        return (from: null, to: null);
    }
  }

  List<Map<String, dynamic>> _applyWhenFilter(List<Map<String, dynamic>> list) {
    final r = _whenRange();
    if (r.from == null && r.to == null) return list;
    return list.where((a) {
      final sa = a['scheduled_at'];
      if (sa == null) return false;
      final dt = DateTime.parse(sa).toLocal();
      if (r.from != null && dt.isBefore(r.from!)) return false;
      if (r.to != null && dt.isAfter(r.to!)) return false;
      return true;
    }).toList();
  }

  String _whenLabel(AppLocalizations l) => switch (_whenFilter) {
        'tonight' => l.whenTonight,
        'weekend' => l.whenWeekend,
        'next_week' => l.whenNextWeek,
        _ => l.whenLabel,
      };

  Widget _buildTrendingShelf() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(l.trendingToday,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _trending.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final a = _trending[i];
                final imageUrl = activityImageUrl(
                  imageUrl: a['image_url'],
                  categoryId: a['category_id'],
                );
                return SizedBox(
                  width: 220,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ActivityDetailScreen(activity: a),
                          ),
                        );
                        _onRefresh();
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: Colors.grey.shade200),
                              errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a['title'] ?? '',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '👥 ${a['participant_count'] ?? 0}/${a['max_participants'] ?? '?'}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF616161)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTrending() async {
    try {
      final t = await _fetchTrending();
      if (mounted) setState(() => _trending = t);
    } catch (_) {}
  }

  // ignore: unused_element
  Future<void> _surpriseMe() async {
    final myId = _supabase.auth.currentUser?.id;
    Set<String> myActivityIds = {};
    if (myId != null) {
      try {
        final rows = await _supabase
            .from('activity_participants')
            .select('activity_id')
            .eq('user_id', myId);
        myActivityIds = rows
            .map<String>((r) => r['activity_id'].toString())
            .toSet();
      } catch (_) {}
    }
    final pool = _activities
        .where((a) => a['status'] != 'inactive')
        .where((a) {
          final sa = a['scheduled_at'];
          if (sa == null) return true;
          return DateTime.parse(sa).toLocal().isAfter(DateTime.now());
        })
        .where((a) => !myActivityIds.contains(a['id'].toString()))
        .toList();
    if (pool.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).noActivitiesFound)),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    final pick = pool[Random().nextInt(pool.length)];
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: pick)),
    );
    _onRefresh();
  }

  Future<void> _toggleFavorite(String activityId) async {
    HapticFeedback.selectionClick();
    final isNowFavorite = await FavoritesService.toggle(activityId);
    setState(() {
      if (isNowFavorite) {
        _favoriteIds.add(activityId);
      } else {
        _favoriteIds.remove(activityId);
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final (items, hasMore) = await _fetchPage(_page + 1);
      setState(() {
        _activities.addAll(items);
        _page++;
        _hasMore = hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _shareActivity(Map<String, dynamic> activity) async {
    final activityId = activity['id'].toString();
    final title = activity['title'] ?? '';
    final locationName = activity['location_name'] ?? '';
    final scheduledAt = activity['scheduled_at'];
    String date = '';
    if (scheduledAt != null) {
      final dt = DateTime.parse(scheduledAt).toLocal();
      date = '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final link = DeepLinkService.activityUrl(activityId);
    final text = '🎉 $title\n📅 $date\n📍 $locationName\n\nHadi, aktiviteye katıl:\n$link';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _signOut() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.signOutConfirmTitle),
        content: Text(l.signOutConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.signOut, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Widget _buildMapView() {
    final center = _cachedLat != null && _cachedLng != null
        ? LatLng(_cachedLat!, _cachedLng!)
        : const LatLng(41.0082, 29.0234);
    return ClusteredActivitiesMap(
      activities: _applyWhenFilter(_activities),
      initialCenter: center,
      onMarkerTap: _showActivitySheet,
      formatDistance: _formatDistance,
    );
  }

  void _showActivitySheet(Map<String, dynamic> activity) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: activityImageUrl(
                  imageUrl: activity['image_url'],
                  categoryId: activity['category_id'],
                ),
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(height: 140, color: Colors.grey.shade200),
                errorWidget: (_, __, ___) => Container(height: 140, color: Colors.grey.shade200),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              activity['title'] ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (activity['category_name'] != null)
              Text(
                activity['category_name'],
                style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w500),
              ),
            const SizedBox(height: 8),
            Text('📍 ${activity['location_name'] ?? ''}'),
            Text('🕐 ${_formatDate(activity['scheduled_at'])}'),
                          Text('👥 ${activity['participant_count'] ?? 0}/${activity['max_participants'] ?? '?'} ${l.participants}'),
                            Text('📏 ${_formatDistance(activity['distance_km'])} ${l.away}'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: activity)),
                  );
                  _onRefresh();
                },
                child: Text(l.viewDetails),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(dynamic distanceKm) {
    if (distanceKm == null) return '';
    final km = (distanceKm as num).toDouble();
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  String _formatDate(String? scheduledAt) {
    if (scheduledAt == null) return '';
    final dt = DateTime.parse(scheduledAt).toLocal();
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sortOpts = _sortOptions(l);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Image.asset(
            'assets/icon/wordmark_clean.png',
            height: 24,
            fit: BoxFit.contain,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            tooltip: _showMap ? l.listView : l.mapView,
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          Badge.count(
            count: _unreadCount,
            isLabelVisible: _unreadCount > 0,
            backgroundColor: Colors.red,
            offset: const Offset(-4, 4),
            child: IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: l.messages,
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InboxScreen()),
                );
                _refreshUnread();
              },
            ),
          ),
          IconButton(
            icon: _myAvatarUrl != null && _myAvatarUrl!.isNotEmpty
                ? CircleAvatar(
                    radius: 14,
                    backgroundImage: CachedNetworkImageProvider(_myAvatarUrl!),
                  )
                : const Icon(Icons.person),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
              _loadMyAvatar();
              _onRefresh();
            },
          ),
          IconButton(icon: const Icon(Icons.logout), tooltip: l.signOut, onPressed: _signOut),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        // "Beni Şaşırt" mini-FAB temporarily hidden — re-enable when there's
        // a useful pool of nearby activities to randomize from.
        heroTag: 'create-fab',
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateActivityScreen()),
          );
          if (result == true) _loadActivities();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: l.searchActivities,
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
            Row(
              children: [
                Expanded(
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    label: SizedBox(
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.category_outlined, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _selectedCategoryId == null
                                  ? l.categoryLabel
                                  : (_categories.firstWhere(
                                        (c) => c['id'] == _selectedCategoryId,
                                        orElse: () => {'name': l.categoryLabel},
                                      )['name']
                                      as String),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 18),
                        ],
                      ),
                    ),
                    onPressed: () async {
                      final selected = await showModalBottomSheet<int?>(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(l.categoryLabel,
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                              ListTile(
                                leading: const Text('🌐', style: TextStyle(fontSize: 20)),
                                title: Text(l.all),
                                trailing: _selectedCategoryId == null
                                    ? const Icon(Icons.check, color: Colors.deepPurple)
                                    : null,
                                onTap: () => Navigator.of(ctx).pop(-1),
                              ),
                              ..._categories.map((c) {
                                final id = c['id'] as int;
                                return ListTile(
                                  leading: Text(c['icon'] as String,
                                      style: const TextStyle(fontSize: 20)),
                                  title: Text(c['name'] as String),
                                  trailing: _selectedCategoryId == id
                                      ? const Icon(Icons.check, color: Colors.deepPurple)
                                      : null,
                                  onTap: () => Navigator.of(ctx).pop(id),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                      if (selected != null) {
                        final newId = selected == -1 ? null : selected;
                        if (newId != _selectedCategoryId) {
                          setState(() => _selectedCategoryId = newId);
                          _loadActivities();
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    label: SizedBox(
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.sort, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              sortOpts[_sortBy] ?? l.sort,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 18),
                        ],
                      ),
                    ),
                    onPressed: () async {
                      final selected = await showModalBottomSheet<String>(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(l.sort,
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                              ...sortOpts.entries.map((e) => ListTile(
                                    title: Text(e.value),
                                    trailing: e.key == _sortBy
                                        ? const Icon(Icons.check, color: Colors.deepPurple)
                                        : null,
                                    onTap: () => Navigator.of(ctx).pop(e.key),
                                  )),
                            ],
                          ),
                        ),
                      );
                      if (selected != null && selected != _sortBy) {
                        setState(() => _sortBy = selected);
                        _savePref('home_sort_by', selected);
                        _loadActivities();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    label: SizedBox(
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.radar, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '$_radiusKm km',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    onPressed: () async {
                      final selected = await showModalBottomSheet<int>(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(l.searchRadius,
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                              ..._radiusOptions.map((r) => ListTile(
                                    title: Text('$r km'),
                                    trailing: r == _radiusKm
                                        ? const Icon(Icons.check, color: Colors.deepPurple)
                                        : null,
                                    onTap: () => Navigator.of(ctx).pop(r),
                                  )),
                            ],
                          ),
                        ),
                      );
                      if (selected != null && selected != _radiusKm) {
                        setState(() => _radiusKm = selected);
                        _savePref('home_radius_km', selected);
                        _loadActivities();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    label: SizedBox(
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.schedule_outlined, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _whenLabel(l),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 18),
                        ],
                      ),
                    ),
                    onPressed: () async {
                      final selected = await showModalBottomSheet<String>(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(l.whenLabel,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                              for (final entry in {
                                'all': l.whenAll,
                                'tonight': l.whenTonight,
                                'weekend': l.whenWeekend,
                                'next_week': l.whenNextWeek,
                              }.entries)
                                ListTile(
                                  title: Text(entry.value),
                                  trailing: entry.key == _whenFilter
                                      ? const Icon(Icons.check, color: Colors.deepPurple)
                                      : null,
                                  onTap: () => Navigator.of(ctx).pop(entry.key),
                                ),
                            ],
                          ),
                        ),
                      );
                      if (selected != null && selected != _whenFilter) {
                        setState(() => _whenFilter = selected);
                      }
                    },
                  ),
                ),
              ],
            ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: 6,
                    itemBuilder: (_, __) => const ActivityCardSkeleton(),
                  )
                : _showMap
                    ? _buildMapView()
                    : RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: _error != null
                            ? LayoutBuilder(
                                builder: (context, constraints) => SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                                          const SizedBox(height: 8),
                                          Text(l.activitiesLoadFailed, style: Theme.of(context).textTheme.titleMedium),
                                          const SizedBox(height: 16),
                                          ElevatedButton(
                                            onPressed: _loadActivities,
                                            child: Text(l.retry),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Builder(builder: (context) {
                                final filtered = _applyWhenFilter(_activities);
                                if (filtered.isEmpty) {
                                  return LayoutBuilder(
                                    builder: (context, constraints) => SingleChildScrollView(
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                        child: Center(child: Text(l.noActivitiesNearby)),
                                      ),
                                    ),
                                  );
                                }
                                final showLoadMore = _whenFilter == 'all' && _hasMore;
                                // Bugün Popüler shelf temporarily hidden — re-enable when active
                                // activity volume is meaningful (>20 in a city). Backend endpoint is live.
                                const showShelf = false;
                                final shelfOffset = showShelf ? 1 : 0;
                                return ListView.builder(
                                    controller: _scrollController,
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    itemCount: filtered.length + shelfOffset + (showLoadMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (showShelf && index == 0) {
                                        return _buildTrendingShelf();
                                      }
                                      final dataIndex = index - shelfOffset;
                                      if (dataIndex == filtered.length) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Center(child: CircularProgressIndicator()),
                                        );
                                      }
                                      final activity = filtered[dataIndex];
                                      final imageUrl = activityImageUrl(
                                        imageUrl: activity['image_url'],
                                        categoryId: activity['category_id'],
                                      );
                                      return Card(
                                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        clipBehavior: Clip.antiAlias,
                                        child: InkWell(
                                          onTap: () async {
                                            await Navigator.of(context).push<bool>(
                                              MaterialPageRoute(
                                                builder: (_) => ActivityDetailScreen(activity: activity),
                                              ),
                                            );
                                            _onRefresh();
                                          },
                                          onLongPress: () => _shareActivity(activity),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Stack(
                                                children: [
                                                  AspectRatio(
                                                    aspectRatio: 16 / 9,
                                                    child: CachedNetworkImage(
                                                      imageUrl: imageUrl,
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      placeholder: (_, __) => Container(color: Colors.grey.shade200),
                                                      errorWidget: (_, __, ___) => Container(
                                                        color: Colors.grey.shade200,
                                                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: 8,
                                                    right: 8,
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: Colors.black.withValues(alpha: 0.6),
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Text(
                                                            _formatDistance(activity['distance_km']),
                                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        IconButton(
                                                          iconSize: 18,
                                                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                                          style: IconButton.styleFrom(
                                                            backgroundColor: Colors.black.withValues(alpha: 0.6),
                                                            shape: const CircleBorder(),
                                                            padding: EdgeInsets.zero,
                                                          ),
                                                          onPressed: () => _toggleFavorite(activity['id'].toString()),
                                                          icon: Icon(
                                                            _favoriteIds.contains(activity['id'].toString())
                                                                ? Icons.favorite
                                                                : Icons.favorite_border,
                                                            color: _favoriteIds.contains(activity['id'].toString())
                                                                ? Colors.red
                                                                : Colors.white,
                                                            size: 18,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (activity['category_name'] != null)
                                                    Positioned(
                                                      top: 8,
                                                      left: 8,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.deepPurple,
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Text(
                                                          activity['category_name'],
                                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      activity['title'] ?? '',
                                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text('📍 ${activity['location_name'] ?? ''}', style: const TextStyle(fontSize: 13)),
                                                    Text(
                                                      '🕐 ${_formatDate(activity['scheduled_at'])}  👥 ${activity['participant_count'] ?? 0}/${activity['max_participants'] ?? '?'}',
                                                      style: const TextStyle(fontSize: 12, color: Color(0xFF616161)),
                                                    ),
                                                    if (activity['creator_name'] != null) ...[
                                                      const SizedBox(height: 2),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.person_outline, size: 12, color: Color(0xFF616161)),
                                                          const SizedBox(width: 2),
                                                          Flexible(
                                                            child: Text(
                                                              activity['creator_name'] as String,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: const TextStyle(fontSize: 12, color: Color(0xFF616161)),
                                                            ),
                                                          ),
                                                          if (activity['creator_is_verified'] == true) ...[
                                                            const SizedBox(width: 3),
                                                            const VerifiedBadge(size: 12),
                                                          ],
                                                          if (activity['creator_rating_count'] != null && activity['creator_rating_count'] > 0) ...[
                                                            const SizedBox(width: 6),
                                                            const Icon(Icons.star, size: 12, color: Color(0xFFFFA726)),
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              '${(activity['creator_rating_avg'] as num).toStringAsFixed(1)}',
                                                              style: const TextStyle(fontSize: 12, color: Color(0xFF616161), fontWeight: FontWeight.w500),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );

                                    },
                                  );
                              }),
                      ),
          ),
        ],
      ),
    );
  }
}
