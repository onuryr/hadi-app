import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../services/deep_link_service.dart';
import '../services/favorites_service.dart';
import '../services/rating_service.dart';
import '../services/report_block_service.dart';
import 'activity_detail_screen.dart';
import 'blocked_users_screen.dart';
import 'settings_screen.dart';

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
  bool _isBlocked = false;

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

  int _profileCompletion() {
    int filled = 0;
    if ((_user?['display_name'] as String?)?.trim().isNotEmpty == true) filled++;
    if ((_user?['avatar_url'] as String?)?.isNotEmpty == true) filled++;
    if ((_user?['bio'] as String?)?.trim().isNotEmpty == true) filled++;
    return (filled / 3 * 100).round();
  }

  Widget _buildCompletionBanner() {
    final l = AppLocalizations.of(context);
    final percent = _profileCompletion();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.account_circle_outlined,
              color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.completeProfile(percent),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onPrimaryContainer,
                    )),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 6,
                    backgroundColor: scheme.surface.withValues(alpha: 0.4),
                    valueColor: AlwaysStoppedAnimation(scheme.primary),
                  ),
                ),
                const SizedBox(height: 4),
                Text(l.completeProfileHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                    )),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() => _editMode = true),
            child: Text(l.completeProfileCta),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    if (_loading) return;
    try {
      await _loadProfile(showError: true);
    } catch (_) {}
  }

  Future<void> _loadProfile({bool showError = false}) async {
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

      bool blocked = false;
      if (!_isSelf) {
        try {
          final blocks = await ReportBlockService.getMyBlocks();
          blocked = blocks.any((b) => b['userId']?.toString() == userId);
        } catch (_) {}
      }

      setState(() {
        _user = user;
        _createdActivities = created;
        _joinedActivities = joined;
        _favoriteActivities = favorites;
        _avgRating = rating.avg;
        _ratingCount = rating.count;
        _isBlocked = blocked;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (showError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).refreshError)),
        );
      }
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
          SnackBar(content: Text(AppLocalizations.of(context).profileSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1600,
    );
    if (image == null) return;
    if (!mounted) return;

    final l = AppLocalizations.of(context);
    final cropped = await ImageCropper().cropImage(
      sourcePath: image.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: l.cropPhotoTitle,
          toolbarColor: Colors.deepPurple,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: Colors.deepPurple,
          aspectRatioPresets: [CropAspectRatioPreset.square],
          cropStyle: CropStyle.circle,
          hideBottomControls: true,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: l.cropPhotoTitle,
          doneButtonTitle: l.done,
          cancelButtonTitle: l.cancel,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPresets: [CropAspectRatioPreset.square],
          cropStyle: CropStyle.circle,
        ),
      ],
    );
    if (cropped == null) return;

    try {
      final userId = _supabase.auth.currentUser!.id;
      final file = File(cropped.path);
      final path = '$userId/avatar.jpg';

      await _supabase.storage.from('avatars').upload(path, file,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));

      final base = _supabase.storage.from('avatars').getPublicUrl(path);
      final url = '$base?v=${DateTime.now().millisecondsSinceEpoch}';
      await _supabase.from('users').update({'avatar_url': url}).eq('id', userId);

      setState(() => _user = {...?_user, 'avatar_url': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).photoUpdated)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).photoUploadFailed}: $e')),
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
    await SharePlus.instance.share(ShareParams(text: text));
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

  Widget _buildActivityList(List<Map<String, dynamic>> activities,
      {String listType = 'created'}) {
    if (activities.isEmpty) {
      return RefreshIndicator(
        onRefresh: _handleRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(child: Text(switch (listType) {
                    'joined' => AppLocalizations.of(context).noActivitiesJoined,
                    'favorite' => AppLocalizations.of(context).noFavorites,
                    _ => AppLocalizations.of(context).noActivitiesCreated,
                  })),
            ),
          ),
        ),
      );
    }
    final sorted = [...activities]
      ..sort((a, b) {
        final aPast = _isPast(a);
        final bPast = _isPast(b);
        if (aPast != bPast) return aPast ? 1 : -1;
        return (b['scheduled_at'] ?? '').compareTo(a['scheduled_at'] ?? '');
      });
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          final a = sorted[index];
          final past = _isPast(a);
          final tile = ListTile(
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
                    child: Text(AppLocalizations.of(context).activityCancelled,
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onErrorContainer)),
                  )
                : past
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(AppLocalizations.of(context).activityPast,
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      )
                    : const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: a)),
              );
              _loadProfile();
            },
            onLongPress: () => _shareActivity(a),
          );

          if (!_isSelf || past || a['status'] == 'inactive') return tile;
          if (listType != 'created' &&
              listType != 'favorite' &&
              listType != 'joined') return tile;

          final activityId = a['id'].toString();
          final l = AppLocalizations.of(context);
          return Dismissible(
            key: ValueKey('$listType-$activityId'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Icon(
                listType == 'favorite'
                    ? Icons.heart_broken
                    : listType == 'joined'
                        ? Icons.exit_to_app
                        : Icons.delete_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            onDismissed: (_) async {
              HapticFeedback.mediumImpact();
              final removed = a;
              final messenger = ScaffoldMessenger.of(this.context);
              final uid = _supabase.auth.currentUser?.id;
              setState(() {
                if (listType == 'favorite') {
                  _favoriteActivities.removeWhere((x) => x['id'].toString() == activityId);
                } else if (listType == 'joined') {
                  _joinedActivities.removeWhere((x) => x['id'].toString() == activityId);
                } else {
                  _createdActivities.removeWhere((x) => x['id'].toString() == activityId);
                }
              });
              try {
                if (listType == 'favorite') {
                  await FavoritesService.toggle(activityId);
                } else if (listType == 'joined') {
                  await _supabase
                      .from('activity_participants')
                      .delete()
                      .eq('activity_id', activityId)
                      .eq('user_id', uid!);
                } else {
                  await _supabase
                      .from('activities')
                      .update({'status': 'inactive'}).eq('id', activityId);
                }
                if (!mounted) return;
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(listType == 'favorite'
                        ? l.removeFromFavorites
                        : listType == 'joined'
                            ? l.leftActivitySnack
                            : l.activityCancelled),
                    duration: const Duration(seconds: 3),
                    action: SnackBarAction(
                      label: l.undo,
                      onPressed: () async {
                        try {
                          if (listType == 'favorite') {
                            await FavoritesService.toggle(activityId);
                            if (mounted) {
                              setState(() => _favoriteActivities.insert(0, removed));
                            }
                          } else if (listType == 'joined') {
                            await _supabase.from('activity_participants').insert({
                              'activity_id': activityId,
                              'user_id': uid,
                              'status': 'approved',
                            });
                            if (mounted) {
                              setState(() => _joinedActivities.insert(0, removed));
                            }
                          } else {
                            await _supabase
                                .from('activities')
                                .update({'status': 'active'}).eq('id', activityId);
                            if (mounted) {
                              setState(() => _createdActivities.insert(0, removed));
                            }
                          }
                        } catch (_) {}
                      },
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  if (listType == 'favorite') {
                    _favoriteActivities.insert(0, removed);
                  } else if (listType == 'joined') {
                    _joinedActivities.insert(0, removed);
                  } else {
                    _createdActivities.insert(0, removed);
                  }
                });
                messenger.showSnackBar(
                  SnackBar(content: Text('${l.error}: $e')),
                );
              }
            },
            child: tile,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelf ? l.profile : (_user?['display_name'] ?? l.profile)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isSelf && !_loading)
            _editMode
                ? TextButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.save, style: const TextStyle(fontWeight: FontWeight.bold)),
                  )
                : IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: l.edit,
                    onPressed: () => setState(() => _editMode = true),
                  ),
          if (_isSelf && !_loading) ...[
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l.settings,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: l.blockedUsers,
              onSelected: (value) {
                if (value == 'blocked') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'blocked', child: Text(l.blockedUsers)),
              ],
            ),
          ],
          if (!_isSelf && !_loading)
            PopupMenuButton<String>(
              onSelected: (value) async {
                final userId = _viewedUserId;
                final name = _user?['display_name']?.toString() ?? AppLocalizations.of(context).unknownUser;
                if (value == 'report') {
                  final ok = await ReportBlockService.showReportDialog(
                    context,
                    targetType: 'user',
                    targetId: userId,
                  );
                  if (ok) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context).reportSubmittedSnack)),
                    );
                  }
                } else if (value == 'block') {
                  final blocked = await ReportBlockService.showBlockConfirmDialog(
                    context,
                    userId: userId,
                    displayName: name,
                  );
                  if (blocked && mounted) {
                    setState(() => _isBlocked = true);
                    final l = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l.userBlockedSnack(name)),
                        duration: const Duration(seconds: 3),
                        action: SnackBarAction(
                          label: l.undo,
                          onPressed: () async {
                            try {
                              await ReportBlockService.unblockUser(userId);
                              if (mounted) setState(() => _isBlocked = false);
                            } catch (_) {}
                          },
                        ),
                      ),
                    );
                  }
                } else if (value == 'unblock') {
                  try {
                    await ReportBlockService.unblockUser(userId);
                    if (mounted) {
                      setState(() => _isBlocked = false);
                      final l = AppLocalizations.of(context);
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$name — ${l.unblockedSuccess}'),
                          duration: const Duration(seconds: 3),
                          action: SnackBarAction(
                            label: l.undo,
                            onPressed: () async {
                              try {
                                await ReportBlockService.blockUser(userId);
                                if (mounted) setState(() => _isBlocked = true);
                              } catch (_) {}
                            },
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${AppLocalizations.of(context).unblockFailed}: $e')),
                      );
                    }
                  }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'report', child: Text(l.report)),
                if (_isBlocked)
                  PopupMenuItem(value: 'unblock', child: Text(l.unblock))
                else
                  PopupMenuItem(value: 'block', child: Text(l.block)),
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
                              '${_avgRating.toStringAsFixed(1)} (${AppLocalizations.of(context).ratingsCount(_ratingCount)})',
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
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context).aboutMeLabel,
                                border: const OutlineInputBorder(),
                              ),
                            )
                          : Builder(builder: (_) {
                              final bio = (_user?['bio'] as String?)?.trim() ?? '';
                              if (bio.isEmpty) {
                                return Text(
                                  _isSelf ? AppLocalizations.of(context).aboutMeEmptySelf : AppLocalizations.of(context).aboutMeEmptyOther,
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
                if (_isSelf && _profileCompletion() < 100) _buildCompletionBanner(),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: [
                    Tab(text: '${l.createdActivities} (${_createdActivities.length})'),
                    Tab(text: '${l.joinedActivities} (${_joinedActivities.length})'),
                    if (_isSelf)
                      Tab(text: '${l.favorites} (${_favoriteActivities.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActivityList(_createdActivities, listType: 'created'),
                      _buildActivityList(_joinedActivities, listType: 'joined'),
                      if (_isSelf) _buildActivityList(_favoriteActivities, listType: 'favorite'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
