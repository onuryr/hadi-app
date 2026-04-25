import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'login_screen.dart';
import 'create_activity_screen.dart';
import 'activity_detail_screen.dart';
import 'profile_screen.dart';
import 'inbox_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../services/chat_service.dart';
import '../services/deep_link_service.dart';
import '../services/favorites_service.dart';
import '../utils/category_defaults.dart';

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
  int _unreadCount = 0;
  Set<String> _favoriteIds = {};
  Timer? _searchDebounce;

  static const _radiusOptions = [5, 10, 25, 50, 100];
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const _apiBase = 'https://hadi-production-e4f3.up.railway.app';
  static const _pageSize = 20;

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
  ];

  RealtimeChannel? _messageChannel;

  @override
  void initState() {
    super.initState();
    _loadActivities();
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

  Future<List<Map<String, dynamic>>> _fetchPage(int page) async {
    if (_cachedLat == null) {
      final position = await _getLocation();
      _cachedLat = position?.latitude ?? 41.0082;
      _cachedLng = position?.longitude ?? 29.0234;
    }
    final params = {
      'lat': _cachedLat.toString(),
      'lng': _cachedLng.toString(),
      'radiusKm': _radiusKm.toString(),
      'page': page.toString(),
      'pageSize': _pageSize.toString(),
      if (_selectedCategoryId != null) 'categoryId': _selectedCategoryId.toString(),
      if (_searchQuery.isNotEmpty) 'q': _searchQuery,
    };
    final uri = Uri.parse('$_apiBase/api/activities/nearby').replace(queryParameters: params);
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Sunucu hatası: ${response.statusCode}');
    final decoded = jsonDecode(response.body);
    final List<dynamic> data = decoded is Map ? (decoded['items'] as List? ?? []) : decoded as List;
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
      'lat': item['lat'],
      'lng': item['lng'],
      'image_url': item['imageUrl'],
      'category_id': categoryNameToId[item['categoryName'] as String? ?? ''],
    }).toList();
  }

  Future<void> _loadActivities() async {
    setState(() { _loading = true; _error = null; _page = 1; });
    try {
      final results = await Future.wait([_fetchPage(1), FavoritesService.getFavoriteIds()]);
      final items = results[0] as List<Map<String, dynamic>>;
      final favs = results[1] as Set<String>;
      setState(() {
        _activities = items;
        _favoriteIds = favs;
        _page = 1;
        _hasMore = items.length == _pageSize;
        _loading = false;
      });
      _refreshUnread();
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _refreshUnread() async {
    final count = await ChatService.unreadActivityCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  Future<void> _toggleFavorite(String activityId) async {
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
      final items = await _fetchPage(_page + 1);
      setState(() {
        _activities.addAll(items);
        _page++;
        _hasMore = items.length == _pageSize;
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
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Widget _buildMapView() {
    final markers = <Marker>{};
    for (final a in _activities) {
      final lat = a['lat'];
      final lng = a['lng'];
      if (lat == null || lng == null) continue;
      markers.add(Marker(
        markerId: MarkerId(a['id'].toString()),
        position: LatLng((lat as num).toDouble(), (lng as num).toDouble()),
        infoWindow: InfoWindow(
          title: a['title'] ?? '',
          snippet: '${a['category_name'] ?? ''} • ${_formatDistance(a['distance_km'])}',
          onTap: () => _showActivitySheet(a),
        ),
        onTap: () => _showActivitySheet(a),
      ));
    }
    final center = _cachedLat != null && _cachedLng != null
        ? LatLng(_cachedLat!, _cachedLng!)
        : const LatLng(41.0082, 29.0234);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 12),
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }

  void _showActivitySheet(Map<String, dynamic> activity) {
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
            Text('👥 ${activity['participant_count'] ?? 0}/${activity['max_participants'] ?? '?'} katılımcı'),
            Text('📏 ${_formatDistance(activity['distance_km'])} uzakta'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final deleted = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: activity)),
                  );
                  if (deleted == true) _loadActivities();
                },
                child: const Text('Detayları Gör'),
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
    final dt = DateTime.parse(scheduledAt);
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hadi'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            tooltip: _showMap ? 'Liste' : 'Harita',
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          Badge.count(
            count: _unreadCount,
            isLabelVisible: _unreadCount > 0,
            backgroundColor: Colors.red,
            offset: const Offset(-4, 4),
            child: IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Mesajlar',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InboxScreen()),
                );
                _refreshUnread();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Çıkış yap', onPressed: _signOut),
        ],
      ),
      floatingActionButton: FloatingActionButton(
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
              decoration: InputDecoration(
                hintText: 'Aktivite ara...',
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
                fillColor: Colors.grey.shade100,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.my_location, size: 16),
                    label: Text('$_radiusKm km'),
                    onPressed: () async {
                      final selected = await showModalBottomSheet<int>(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Arama yarıçapı',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        _loadActivities();
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Tümü'),
                    selected: _selectedCategoryId == null,
                    onSelected: (_) {
                      setState(() => _selectedCategoryId = null);
                      _loadActivities();
                    },
                  ),
                ),
                ..._categories.map((c) {
                  final id = c['id'] as int;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${c['icon']} ${c['name']}'),
                      selected: _selectedCategoryId == id,
                      onSelected: (_) {
                        setState(() => _selectedCategoryId = id);
                        _loadActivities();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _showMap
                    ? _buildMapView()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text('Aktiviteler yüklenemedi', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadActivities,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              : _activities.isEmpty
                  ? const Center(child: Text('Yakında aktif aktivite bulunamadı'))
                  : RefreshIndicator(
                      onRefresh: _loadActivities,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _activities.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _activities.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final activity = _activities[index];
                          final imageUrl = activityImageUrl(
                            imageUrl: activity['image_url'],
                            categoryId: activity['category_id'],
                          );
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () async {
                                final deleted = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => ActivityDetailScreen(activity: activity),
                                  ),
                                );
                                if (deleted == true) _loadActivities();
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
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
