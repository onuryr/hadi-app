import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/deep_link_service.dart';
import '../services/rating_service.dart';
import '../services/report_block_service.dart';
import 'activity_detail_screen.dart';
import 'blocked_users_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  late TabController _tabController;

  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _createdActivities = [];
  List<Map<String, dynamic>> _joinedActivities = [];
  List<Map<String, dynamic>> _favoriteActivities = [];
  double _avgRating = 0.0;
  int _ratingCount = 0;
  bool _loading = true;
  bool _saving = false;
  bool _editMode = false;

  bool get _isSelf {
    final current = _supabase.auth.currentUser?.id;
    return widget.userId == null || widget.userId == current;
  }

  String get _viewedUserId =>
      widget.userId ?? _supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isSelf ? 3 : 2, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _loading = false);
      return;
    }
    final userId = _viewedUserId;
    try {
      final baseFutures = [
        _supabase.from('users').select().eq('id', userId).single(),
        _supabase
            .from('activities')
            .select('id, title, location_name, scheduled_at, max_participants, location, description, status')
            .eq('creator_id', userId)
            .order('created_at', ascending: false),
        _supabase
            .from('activity_participants')
            .select('activities(id, title, location_name, scheduled_at, max_participants, location, description, creator_id, status)')
            .eq('user_id', userId)
            .eq('status', 'approved'),
      ];
      if (_isSelf) {
        baseFutures.add(_supabase
            .from('activity_favorites')
            .select('activities(id, title, location_name, scheduled_at, max_participants, location, description, status)')
            .eq('user_id', userId)
            .order('created_at', ascending: false));
      }
      final results = await Future.wait(baseFutures);
      final rating = await RatingService.getUserAverage(userId);

      final user = results[0] as Map<String, dynamic>;
      final created = List<Map<String, dynamic>>.from(results[1] as List);
      final participations = results[2] as List;
      final joined = participations
          .map((p) => p['activities'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .where((a) => a['creator_id'] != userId)
          .toList();
      final favorites = _isSelf && results.length > 3
          ? (results[3] as List)
              .map((f) => f['activities'] as Map<String, dynamic>?)
              .whereType<Map<String, dynamic>>()
              .toList()
          : <Map<String, dynamic>>[];

      _nameController.text = user['display_name'] ?? '';
      _bioController.text = user['bio'] ?? '';

      setState(() {
        _user = user;
        _createdActivities = created;
        _joinedActivities = joined;
        _favoriteActivities = favorites;
        _avgRating = rating.avg;
        _ratingCount = rating.count;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('users').update({
        'display_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
      }).eq('id', userId);
      setState(() {
        _user = {...?_user, 'display_name': _nameController.text.trim(), 'bio': _bioController.text.trim()};
        _editMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil güncellendi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 512);
    if (image == null) return;

    try {
      final userId = _supabase.auth.currentUser!.id;
      final file = File(image.path);
      final ext = image.path.split('.').last.toLowerCase();
      final path = '$userId/avatar.$ext';

      await _supabase.storage.from('avatars').upload(path, file,
          fileOptions: const FileOptions(upsert: true));

      final url = _supabase.storage.from('avatars').getPublicUrl(path);
      await _supabase.from('users').update({'avatar_url': url}).eq('id', userId);

      setState(() => _user = {...?_user, 'avatar_url': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf güncellendi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf yüklenemedi: $e')),
        );
      }
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
    await Share.share(text);
  }

  String _formatDate(String? scheduledAt) {
    if (scheduledAt == null) return '';
    final dt = DateTime.parse(scheduledAt).toLocal();
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  bool _isPast(Map<String, dynamic> a) {
    final sa = a['scheduled_at'];
    if (sa == null) return false;
    return DateTime.parse(sa).toLocal().isBefore(DateTime.now());
  }

  Widget _buildActivityList(List<Map<String, dynamic>> activities) {
    if (activities.isEmpty) {
      return const Center(child: Text('Henüz aktivite yok'));
    }
    final sorted = [...activities]
      ..sort((a, b) {
        final aPast = _isPast(a);
        final bPast = _isPast(b);
        if (aPast != bPast) return aPast ? 1 : -1;
        return (b['scheduled_at'] ?? '').compareTo(a['scheduled_at'] ?? '');
      });
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final a = sorted[index];
        final past = _isPast(a);
        return ListTile(
          leading: Icon(Icons.event, color: past ? Colors.grey : null),
          title: Text(
            a['title'] ?? '',
            style: TextStyle(color: past ? Colors.grey : null),
          ),
          subtitle: Text(
            '${a['location_name'] ?? ''}  •  ${_formatDate(a['scheduled_at'])}',
            style: TextStyle(color: past ? Colors.grey : null),
          ),
          trailing: a['status'] == 'inactive'
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('İptal Edildi',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onErrorContainer)),
                )
              : past
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Tamamlandı',
                          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    )
                  : const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: a)),
          ),
          onLongPress: () => _shareActivity(a),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelf ? 'Profilim' : (_user?['display_name'] ?? 'Profil')),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isSelf && !_loading)
            _editMode
                ? TextButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                : IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => setState(() => _editMode = true),
                  ),
          if (_isSelf && !_loading)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'blocked') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                  );
                } else if (value == 'settings') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'settings', child: Text('Ayarlar')),
                PopupMenuItem(value: 'blocked', child: Text('Engellediklerim')),
              ],
            ),
          if (!_isSelf && !_loading)
            PopupMenuButton<String>(
              onSelected: (value) async {
                final userId = _viewedUserId;
                final name = _user?['display_name']?.toString() ?? 'Kullanıcı';
                if (value == 'report') {
                  final ok = await ReportBlockService.showReportDialog(
                    context,
                    targetType: 'user',
                    targetId: userId,
                  );
                  if (ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Raporunuz iletildi')),
                    );
                  }
                } else if (value == 'block') {
                  final blocked = await ReportBlockService.showBlockConfirmDialog(
                    context,
                    userId: userId,
                    displayName: name,
                  );
                  if (blocked && mounted) Navigator.of(context).pop();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('Raporla')),
                PopupMenuItem(value: 'block', child: Text('Engelle')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _isSelf ? _pickAndUploadAvatar : null,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundImage: _user?['avatar_url'] != null
                                  ? CachedNetworkImageProvider(_user!['avatar_url'])
                                  : null,
                              child: _user?['avatar_url'] == null
                                  ? Text(
                                      (_user?['display_name'] ?? '?')[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 36),
                                    )
                                  : null,
                            ),
                            if (_isSelf)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      (_editMode && _isSelf)
                          ? TextField(
                              controller: _nameController,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                labelText: 'Ad',
                                border: OutlineInputBorder(),
                              ),
                            )
                          : Text(
                              _user?['display_name'] ?? '',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                      if (!_editMode && _ratingCount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '${_avgRating.toStringAsFixed(1)} ($_ratingCount değerlendirme)',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      (_editMode && _isSelf)
                          ? TextField(
                              controller: _bioController,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Hakkımda',
                                border: OutlineInputBorder(),
                                hintText: 'Kendinden bahset...',
                              ),
                            )
                          : Builder(builder: (_) {
                              final bio = (_user?['bio'] as String?)?.trim() ?? '';
                              if (bio.isEmpty) {
                                return Text(
                                  _isSelf ? 'Hakkımda kısmı boş' : 'Henüz bir şey yazmamış',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                );
                              }
                              return Text(
                                bio,
                                textAlign: TextAlign.center,
                              );
                            }),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: [
                    Tab(text: '${_isSelf ? 'Oluşturduklarım' : 'Oluşturdukları'} (${_createdActivities.length})'),
                    Tab(text: '${_isSelf ? 'Katıldıklarım' : 'Katıldıkları'} (${_joinedActivities.length})'),
                    if (_isSelf)
                      Tab(text: 'Favoriler (${_favoriteActivities.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActivityList(_createdActivities),
                      _buildActivityList(_joinedActivities),
                      if (_isSelf) _buildActivityList(_favoriteActivities),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
