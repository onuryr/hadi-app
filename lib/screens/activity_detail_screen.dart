import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/deep_link_service.dart';
import '../services/favorites_service.dart';
import '../services/notification_service.dart';
import '../services/rating_service.dart';
import '../utils/category_defaults.dart';
import '../widgets/star_rating.dart';
import 'chat_screen.dart';
import 'create_activity_screen.dart';
import 'profile_screen.dart';

class ActivityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> activity;

  const ActivityDetailScreen({super.key, required this.activity});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _participants = [];
  Map<String, dynamic> _fullActivity = {};
  bool _loading = true;
  bool _joining = false;
  bool _leaving = false;
  bool _deleting = false;
  bool _isFavorite = false;
  Map<String, int> _myRatings = {};

  bool get _isPast {
    final sa = _fullActivity['scheduled_at'];
    if (sa == null) return false;
    return DateTime.parse(sa).toLocal().isBefore(DateTime.now());
  }

  bool get _wasMember {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    return _isCreator || _participants.any((p) => p['user_id'] == userId);
  }

  bool get _isCreator {
    final userId = _supabase.auth.currentUser?.id;
    return userId != null && _fullActivity['creator_id'] == userId;
  }

  Future<void> _shareActivity() async {
    final activityId = widget.activity['id'].toString();
    final title = _fullActivity['title'] ?? '';
    final locationName = _fullActivity['location_name'] ?? '';
    final scheduledAt = _fullActivity['scheduled_at'];
    String date = '';
    if (scheduledAt != null) {
      final dt = DateTime.parse(scheduledAt).toLocal();
      date = '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final link = DeepLinkService.activityUrl(activityId);
    final text = '🎉 $title\n📅 $date\n📍 $locationName\n\nHadi, aktiviteye katıl:\n$link';
    await Share.share(text);
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          activityId: widget.activity['id'].toString(),
          activityTitle: _fullActivity['title'] ?? '',
        ),
      ),
    );
  }

  Future<void> _openEdit() async {
    final latLng = _parseLocation(_fullActivity['location']);
    final creatorId = _fullActivity['creator_id'];
    final otherParticipants =
        _participants.where((p) => p['user_id'] != creatorId).length;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateActivityScreen(
          existing: _fullActivity,
          existingLocation: latLng,
          lockCategory: otherParticipants > 0,
        ),
      ),
    );
    if (updated == true) await _loadData();
  }

  Future<void> _deleteActivity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aktiviteyi sil?'),
        content: const Text('Bu aktivite ve tüm katılımcıları kalıcı olarak silinecek. Emin misin?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      final activityId = widget.activity['id'];
      final title = _fullActivity['title'] ?? '';
      await NotificationService.notifyActivityDeleted(activityId.toString(), title);
      await _supabase.from('activity_participants').delete().eq('activity_id', activityId);
      await _supabase.from('activities').delete().eq('id', activityId);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktivite silindi')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silme hatası: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fullActivity = Map.from(widget.activity);
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadFullActivity(),
      _loadParticipants(),
      _loadFavoriteStatus(),
      _loadMyRatings(),
    ]);
  }

  Future<void> _loadMyRatings() async {
    final ratings = await RatingService.getMyRatingsForActivity(widget.activity['id'].toString());
    if (mounted) setState(() => _myRatings = ratings);
  }

  Future<void> _rateUser(String ratedUserId, int rating) async {
    try {
      await RatingService.rate(
        activityId: widget.activity['id'].toString(),
        ratedUserId: ratedUserId,
        rating: rating,
      );
      setState(() => _myRatings[ratedUserId] = rating);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Puanın kaydedildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _loadFavoriteStatus() async {
    final fav = await FavoritesService.isFavorite(widget.activity['id'].toString());
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    final newState = await FavoritesService.toggle(widget.activity['id'].toString());
    if (mounted) setState(() => _isFavorite = newState);
  }

  Future<void> _loadFullActivity() async {
    try {
      final data = await _supabase
          .from('activities')
          .select('id, title, description, location_name, scheduled_at, max_participants, location, creator_id, image_url, category_id')
          .eq('id', widget.activity['id'])
          .single();
      if (mounted) setState(() => _fullActivity = {..._fullActivity, ...data});
    } catch (_) {}
  }

  Future<void> _loadParticipants() async {
    try {
      final data = await _supabase
          .from('activity_participants')
          .select('user_id, status, users(display_name, avatar_url)')
          .eq('activity_id', widget.activity['id']);

      if (mounted) {
        setState(() {
          _participants = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinActivity() async {
    final max = _fullActivity['max_participants'] as int?;
    if (max != null && _participants.length >= max) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktivite dolu, katılamazsın')),
      );
      return;
    }

    setState(() => _joining = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('activity_participants').insert({
        'activity_id': widget.activity['id'],
        'user_id': userId,
        'status': 'approved',
      });
      await _loadParticipants();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktiviteye katıldınız!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      setState(() => _joining = false);
    }
  }

  Future<void> _leaveActivity() async {
    setState(() => _leaving = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase
          .from('activity_participants')
          .delete()
          .eq('activity_id', widget.activity['id'])
          .eq('user_id', userId);
      await _loadParticipants();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktiviteden ayrıldınız')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      setState(() => _leaving = false);
    }
  }

  LatLng? _parseLocation(dynamic location) {
    if (location == null) return null;
    try {
      if (location is Map) {
        final coords = location['coordinates'] as List;
        return LatLng(coords[1].toDouble(), coords[0].toDouble());
      }
      if (location is String) {
        if (location.startsWith('{')) {
          final decoded = jsonDecode(location) as Map;
          final coords = decoded['coordinates'] as List;
          return LatLng(coords[1].toDouble(), coords[0].toDouble());
        }
        if (location.startsWith('POINT')) {
          final clean = location.replaceAll('POINT(', '').replaceAll(')', '');
          final parts = clean.trim().split(' ');
          return LatLng(double.parse(parts[1]), double.parse(parts[0]));
        }
        // EWKB hex (PostGIS varsayılan formatı)
        return _parseEwkbHex(location);
      }
    } catch (_) {}
    return null;
  }

  LatLng? _parseEwkbHex(String hex) {
    final bytes = Uint8List.fromList(
      List.generate(hex.length ~/ 2, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)),
    );
    final bd = ByteData.sublistView(bytes);
    final le = bytes[0] == 1;
    final endian = le ? Endian.little : Endian.big;
    final type = bd.getUint32(1, endian);
    final hasSrid = (type & 0x20000000) != 0;
    final coordOffset = 5 + (hasSrid ? 4 : 0);
    final x = bd.getFloat64(coordOffset, endian);
    final y = bd.getFloat64(coordOffset + 8, endian);
    return LatLng(y, x);
  }

  bool get _isParticipant {
    final userId = _supabase.auth.currentUser?.id;
    return _participants.any((p) => p['user_id'] == userId);
  }

  @override
  Widget build(BuildContext context) {
    final activity = _fullActivity;
    final scheduledAt = activity['scheduled_at'] != null
        ? DateTime.parse(activity['scheduled_at'])
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(activity['title'] ?? ''),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_wasMember)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Sohbet',
              onPressed: _openChat,
            ),
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : null,
            ),
            tooltip: 'Favori',
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Paylaş',
            onPressed: _shareActivity,
          ),
          if (_isCreator)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Düzenle',
              onPressed: _openEdit,
            ),
          if (_isCreator)
            IconButton(
              icon: _deleting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.delete_outline),
              tooltip: 'Aktiviteyi sil',
              onPressed: _deleting ? null : _deleteActivity,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: activityImageUrl(
                      imageUrl: activity['image_url'],
                      categoryId: activity['category_id'],
                    ),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.grey.shade200),
                    errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                if (activity['description'] != null &&
                    activity['description'].toString().isNotEmpty) ...[
                  Text(
                    activity['description'],
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                ],
                if (scheduledAt != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      '${scheduledAt.day}/${scheduledAt.month}/${scheduledAt.year} '
                      '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.people),
                  title: Text(
                    '${_participants.length} / ${activity['max_participants'] ?? '?'} katılımcı',
                  ),
                ),
                const Divider(),
                Text(
                  _isPast && _wasMember ? 'Katılımcıları Puanla' : 'Katılımcılar',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._participants.map((p) {
                  final userId = p['user_id']?.toString();
                  final name = p['users']?['display_name'] ?? 'Bilinmiyor';
                  final avatarUrl = p['users']?['avatar_url'] as String?;
                  final currentUserId = _supabase.auth.currentUser?.id;
                  final canRate = _isPast && _wasMember && userId != null && userId != currentUserId;
                  final myRating = userId != null ? (_myRatings[userId] ?? 0) : 0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                      child: avatarUrl == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?') : null,
                    ),
                    title: Text(name),
                    subtitle: canRate
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: StarRating(
                              value: myRating,
                              size: 24,
                              onChanged: (r) => _rateUser(userId, r),
                            ),
                          )
                        : null,
                    onTap: userId == null
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
                            ),
                  );
                }),
                const Divider(height: 32),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on),
                  title: Text(activity['location_name'] ?? ''),
                ),
                Builder(builder: (context) {
                  final latLng = _parseLocation(activity['location']);
                  if (latLng == null) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 220,
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(target: latLng, zoom: 15),
                            markers: {
                              Marker(markerId: const MarkerId('activity'), position: latLng),
                            },
                            zoomControlsEnabled: true,
                            myLocationButtonEnabled: false,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final url = Uri.parse(
                            'https://www.google.com/maps/dir/?api=1&destination=${latLng.latitude},${latLng.longitude}&travelmode=driving',
                          );
                          if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.directions),
                        label: const Text('Yol Tarifi Al'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                }),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _isCreator
          ? null
          : Padding(
        padding: const EdgeInsets.all(16),
        child: _isParticipant
            ? ElevatedButton(
                onPressed: _leaving ? null : _leaveActivity,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade800,
                ),
                child: _leaving
                    ? const CircularProgressIndicator()
                    : const Text('Ayrıl'),
              )
            : ElevatedButton(
                onPressed: _joining ? null : _joinActivity,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _joining
                    ? const CircularProgressIndicator()
                    : const Text('Katıl'),
              ),
      ),
    );
  }
}
