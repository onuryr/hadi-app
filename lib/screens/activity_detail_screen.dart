import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../services/deep_link_service.dart';
import '../services/favorites_service.dart';
import '../services/notification_service.dart';
import '../services/rating_service.dart';
import '../services/participant_service.dart';
import '../services/report_block_service.dart';
import '../utils/category_defaults.dart';
import '../widgets/activity_detail_skeleton.dart';
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
  bool _skeletonMinPassed = false;
  bool _joining = false;
  bool _leaving = false;
  bool _deleting = false;
  bool _cancelling = false;
  bool _isFavorite = false;
  Map<String, int> _myRatings = {};
  String _processingUserId = '';
  ({double avg, int count})? _creatorRating;

  bool get _isPast {
    final sa = _fullActivity['scheduled_at'];
    if (sa == null) return false;
    // "exactly now" is treated as past per spec (now >= startTime → past)
    return !DateTime.now().isBefore(DateTime.parse(sa).toLocal());
  }

  bool get _isCancelled => _fullActivity['status'] == 'inactive';

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
    await SharePlus.instance.share(ShareParams(text: text));
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

  Future<({bool confirmed, String? reason})> _confirmWithReason({
    required String title,
    required String content,
    required String confirmLabel,
    required String cancelLabel,
  }) async {
    final reasonController = TextEditingController();
    final l = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: l.reasonOptional,
                helperText: l.reasonHelpCancel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel, style: const TextStyle(color: Color(0xFFB3261E))),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    return (confirmed: result == true, reason: reason.isEmpty ? null : reason);
  }

  Future<void> _cancelActivity() async {
    HapticFeedback.heavyImpact();
    final l = AppLocalizations.of(context);
    final res = await _confirmWithReason(
      title: l.cancelDialogTitle,
      content: l.cancelDialogContent,
      confirmLabel: l.cancelIt,
      cancelLabel: l.giveUp,
    );
    if (!res.confirmed) return;

    setState(() => _cancelling = true);
    try {
      final activityId = widget.activity['id'];
      final title = _fullActivity['title'] ?? '';
      await NotificationService.notifyActivityCancelled(
          activityId.toString(), title, reason: res.reason);
      await _supabase
          .from('activities')
          .update({'status': 'inactive'}).eq('id', activityId);
      if (mounted) {
        final l = AppLocalizations.of(context);
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(true);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(l.activityCancelled),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: l.undo,
              onPressed: () async {
                try {
                  await _supabase
                      .from('activities')
                      .update({'status': 'active'}).eq('id', activityId);
                } catch (_) {}
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).cancelError}: $e')),
        );
      }
    }
  }

  Future<void> _deleteActivity() async {
    HapticFeedback.heavyImpact();
    final l = AppLocalizations.of(context);
    final res = await _confirmWithReason(
      title: l.deleteDialogTitle,
      content: l.deleteDialogContent,
      confirmLabel: l.delete,
      cancelLabel: l.cancel,
    );
    if (!res.confirmed) return;

    setState(() => _deleting = true);
    try {
      final activityId = widget.activity['id'];
      final title = _fullActivity['title'] ?? '';
      await NotificationService.notifyActivityDeleted(
          activityId.toString(), title, reason: res.reason);
      await _supabase
          .from('activity_participants')
          .delete()
          .eq('activity_id', activityId);
      await _supabase.from('activities').delete().eq('id', activityId);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final text = AppLocalizations.of(context).activityDeleted;
        Navigator.of(context).pop(true);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).deleteError}: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fullActivity = Map.from(widget.activity);
    _loadData();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _skeletonMinPassed = true);
    });
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadFullActivity(),
      _loadParticipants(),
      _loadFavoriteStatus(),
      _loadMyRatings(),
      _loadCreatorRating(),
    ]);
  }

  Future<void> _loadCreatorRating() async {
    final creatorId = _fullActivity['creator_id']?.toString();
    if (creatorId == null) return;
    final r = await RatingService.getUserAverage(creatorId);
    if (mounted) setState(() => _creatorRating = r);
  }

  Future<void> _loadMyRatings() async {
    final ratings = await RatingService.getMyRatingsForActivity(
        widget.activity['id'].toString());
    if (mounted) setState(() => _myRatings = ratings);
  }

  Future<void> _rateUser(String ratedUserId, int rating) async {
    final prev = _myRatings[ratedUserId];
    setState(() => _myRatings[ratedUserId] = rating);
    try {
      await RatingService.rate(
        activityId: widget.activity['id'].toString(),
        ratedUserId: ratedUserId,
        rating: rating,
      );
    } catch (e) {
      debugPrint('Rating save failed: $e');
      if (mounted) {
        setState(() {
          if (prev == null) {
            _myRatings.remove(ratedUserId);
          } else {
            _myRatings[ratedUserId] = prev;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).ratingSaveFailed}: $e')),
        );
      }
    }
  }

  Future<void> _loadFavoriteStatus() async {
    final fav =
        await FavoritesService.isFavorite(widget.activity['id'].toString());
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.selectionClick();
    final newState =
        await FavoritesService.toggle(widget.activity['id'].toString());
    if (mounted) setState(() => _isFavorite = newState);
  }

  Future<void> _loadFullActivity() async {
    try {
      final data = await _supabase
          .from('activities')
          .select(
              'id, title, description, location_name, scheduled_at, max_participants, location, creator_id, image_url, category_id, status')
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
    HapticFeedback.mediumImpact();
    final max = _fullActivity['max_participants'] as int?;
    if (max != null && _approvedParticipants.length >= max) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).joinFull)),
      );
      return;
    }

    setState(() => _joining = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('activity_participants').insert({
        'activity_id': widget.activity['id'],
        'user_id': userId,
        'status': 'pending',
      });
      final joinUserData = await _supabase
          .from('users')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();
      final joinUserName = joinUserData?['display_name'] as String? ?? '';
      NotificationService.notifyActivityJoined(
          widget.activity['id'].toString(), joinUserName);
      await _loadParticipants();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).joinRequestSent)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
        );
      }
    } finally {
      setState(() => _joining = false);
    }
  }

  Future<void> _leaveActivity() async {
    HapticFeedback.lightImpact();
    setState(() => _leaving = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final leaveUserData = await _supabase
          .from('users')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();
      final leaveUserName = leaveUserData?['display_name'] as String? ?? '';
      await _supabase
          .from('activity_participants')
          .delete()
          .eq('activity_id', widget.activity['id'])
          .eq('user_id', userId);
      NotificationService.notifyActivityLeft(
          widget.activity['id'].toString(), leaveUserName);
      await _loadParticipants();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).leftActivitySnack)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
        );
      }
    } finally {
      setState(() => _leaving = false);
    }
  }

  Future<void> _approveParticipant(String userId) async {
    HapticFeedback.lightImpact();
    setState(() => _processingUserId = userId);
    try {
      await ParticipantService.updateStatus(
        activityId: widget.activity['id'].toString(),
        userId: userId,
        status: 'approved',
      );
      await _loadParticipants();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).joinApproved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingUserId = '');
    }
  }

  Future<void> _rejectParticipant(String userId) async {
    HapticFeedback.lightImpact();
    setState(() => _processingUserId = userId);
    try {
      await ParticipantService.updateStatus(
        activityId: widget.activity['id'].toString(),
        userId: userId,
        status: 'rejected',
      );
      await _loadParticipants();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).joinRejected)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingUserId = '');
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
          final clean =
              location.replaceAll('POINT(', '').replaceAll(')', '');
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
      List.generate(hex.length ~/ 2,
          (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)),
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

  bool get _isApprovedParticipant {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    return _participants
        .any((p) => p['user_id'] == userId && p['status'] == 'approved');
  }

  bool get _isParticipant {
    final userId = _supabase.auth.currentUser?.id;
    return _participants.any((p) => p['user_id'] == userId);
  }

  List<Map<String, dynamic>> get _approvedParticipants {
    final creatorId = _fullActivity['creator_id'];
    final list = _participants.where((p) => p['status'] == 'approved').toList();
    list.sort((a, b) {
      final aCreator = a['user_id'] == creatorId;
      final bCreator = b['user_id'] == creatorId;
      if (aCreator && !bCreator) return -1;
      if (!aCreator && bCreator) return 1;
      return 0;
    });
    return list;
  }

  List<Map<String, dynamic>> get _pendingParticipants =>
      _participants.where((p) => p['status'] == 'pending').toList();

  List<Widget> _buildRatingSection() {
    final currentUserId = _supabase.auth.currentUser?.id;
    final others = _participants
        .where(
            (p) => p['status'] == 'approved' && p['user_id'] != currentUserId)
        .toList();
    if (others.isEmpty) return [];
    return [
      const SizedBox(height: 16),
      const Divider(),
      const Text(
        'Puan Ver',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      ...others.map((p) {
        final userId = p['user_id'].toString();
        final name = p['users']?['display_name'] ?? AppLocalizations.of(context).unknownUser;
        final avatarUrl = p['users']?['avatar_url'] as String?;
        final myRating = _myRatings[userId] ?? 0;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundImage:
                avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                : null,
          ),
          title: Text(name),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: StarRating(
              value: myRating,
              size: 24,
              onChanged: (r) => _rateUser(userId, r),
            ),
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
          ),
        );
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final activity = _fullActivity;
    final scheduledAt = activity['scheduled_at'] != null
        ? DateTime.parse(activity['scheduled_at']).toLocal()
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(activity['title'] ?? ''),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_wasMember)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: AppLocalizations.of(context).chatLabel,
              onPressed: _openChat,
            ),
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : null,
            ),
            tooltip: AppLocalizations.of(context).favorites,
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: AppLocalizations.of(context).share,
            onPressed: _shareActivity,
          ),
          if (_isCreator && !_loading)
            PopupMenuButton<String>(
              enabled: !_deleting && !_cancelling,
              onSelected: (value) {
                if (value == 'edit') _openEdit();
                if (value == 'cancel') _cancelActivity();
                if (value == 'delete') _deleteActivity();
              },
              itemBuilder: (_) => [
                if (!_isPast)
                  PopupMenuItem(
                      value: 'edit', child: Text(AppLocalizations.of(context).edit)),
                if (!_isPast && !_isCancelled)
                  PopupMenuItem(
                    value: 'cancel',
                    child: Text(AppLocalizations.of(context).cancelActivity),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(AppLocalizations.of(context).delete, style: const TextStyle(color: Color(0xFFB3261E))),
                ),
              ],
            ),
          if (!_isCreator && !_loading)
            PopupMenuButton<String>(
              onSelected: (value) async {
                final activityId = widget.activity['id']?.toString() ?? '';
                final creatorId =
                    _fullActivity['creator_id']?.toString() ?? '';
                if (value == 'report') {
                  final ok = await ReportBlockService.showReportDialog(
                    context,
                    targetType: 'activity',
                    targetId: activityId,
                  );
                  if (ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context).reportSubmittedSnack)),
                    );
                  }
                } else if (value == 'block') {
                  final creatorName = _participants
                          .firstWhere(
                            (p) =>
                                p['user_id']?.toString() == creatorId,
                            orElse: () => <String, dynamic>{},
                          )['users']?['display_name']
                          ?.toString() ??
                      AppLocalizations.of(context).unknownUser;
                  final blocked =
                      await ReportBlockService.showBlockConfirmDialog(
                    context,
                    userId: creatorId,
                    displayName: creatorName,
                  );
                  if (blocked && mounted) Navigator.of(context).pop();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'report', child: Text(AppLocalizations.of(context).report)),
                PopupMenuItem(value: 'block', child: Text(AppLocalizations.of(context).block)),
              ],
            ),
        ],
      ),
      body: (_loading || !_skeletonMinPassed)
          ? const ActivityDetailSkeleton()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
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
                    placeholder: (_, __) =>
                        Container(color: Colors.grey.shade200),
                    errorWidget: (_, __, ___) =>
                        Container(color: Colors.grey.shade200),
                  ),
                ),
                if (_isCancelled)
                  Container(
                    width: double.infinity,
                    color: Colors.red.shade50,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.cancel_outlined,
                            color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context).cancelledLabel,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
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
                          '${_approvedParticipants.length} / ${activity['max_participants'] ?? '?'} katılımcı',
                        ),
                      ),
                      if (_isCreator && _pendingParticipants.isNotEmpty) ...[
                        const Divider(),
                        Text(
                          AppLocalizations.of(context).pendingRequests,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ..._pendingParticipants.map((p) {
                          final pUserId = p['user_id']?.toString() ?? '';
                          final pName =
                              p['users']?['display_name'] ?? AppLocalizations.of(context).unknownUser;
                          final pAvatarUrl =
                              p['users']?['avatar_url'] as String?;
                          final isThisProcessing =
                              _processingUserId == pUserId;
                          final anyProcessing = _processingUserId.isNotEmpty;
                          final max =
                              _fullActivity['max_participants'] as int?;
                          final isFull = max != null &&
                              _approvedParticipants.length >= max;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundImage: pAvatarUrl != null
                                  ? CachedNetworkImageProvider(pAvatarUrl)
                                  : null,
                              child: pAvatarUrl == null
                                  ? Text(pName.isNotEmpty
                                      ? pName[0].toUpperCase()
                                      : '?')
                                  : null,
                            ),
                            title: Text(pName),
                            onTap: pUserId.isEmpty
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => ProfileScreen(
                                              userId: pUserId)),
                                    ),
                            trailing: isThisProcessing
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Tooltip(
                                        message: isFull
                                            ? AppLocalizations.of(context).capacityFull
                                            : AppLocalizations.of(context).approve,
                                        child: IconButton.filled(
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          onPressed: (isFull || anyProcessing)
                                              ? null
                                              : () => _approveParticipant(pUserId),
                                          icon: const Icon(Icons.check, size: 18),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Tooltip(
                                        message: AppLocalizations.of(context).reject,
                                        child: IconButton.outlined(
                                          style: IconButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(color: Colors.red),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          onPressed: anyProcessing
                                              ? null
                                              : () => _rejectParticipant(pUserId),
                                          icon: const Icon(Icons.close, size: 18),
                                        ),
                                      ),
                                    ],
                                  ),
                          );
                        }),
                      ],
                      const Divider(),
                      Text(
                        AppLocalizations.of(context).participantsHeader,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._approvedParticipants.map((p) {
                        final userId = p['user_id']?.toString();
                        final name =
                            p['users']?['display_name'] ?? AppLocalizations.of(context).unknownUser;
                        final avatarUrl =
                            p['users']?['avatar_url'] as String?;
                        final isCreator =
                            p['user_id'] == _fullActivity['creator_id'];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundImage: avatarUrl != null
                                ? CachedNetworkImageProvider(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? Text(name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?')
                                : null,
                          ),
                          title: Text(name),
                          subtitle: isCreator &&
                                  _creatorRating != null &&
                                  _creatorRating!.count > 0
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star,
                                        size: 14, color: Color(0xFFFFA726)),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${_creatorRating!.avg.toStringAsFixed(1)} · ${_creatorRating!.count}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                )
                              : null,
                          trailing: isCreator
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        AppLocalizations.of(context).organizerLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                          onTap: userId == null
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            ProfileScreen(userId: userId)),
                                  ),
                        );
                      }),
                      if (_isPast && _isApprovedParticipant)
                        ..._buildRatingSection(),
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
                                  initialCameraPosition: CameraPosition(
                                      target: latLng, zoom: 15),
                                  markers: {
                                    Marker(
                                        markerId:
                                            const MarkerId('activity'),
                                        position: latLng),
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
                                if (await canLaunchUrl(url)) {
                                  launchUrl(url,
                                      mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.directions),
                              label: Text(AppLocalizations.of(context).getDirections),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 56),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 16),
                                alignment: Alignment.centerLeft,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
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
            ),
      bottomNavigationBar: _isCreator || _isPast
          ? null
          : Padding(
              padding: const EdgeInsets.all(16),
              child: _isCancelled
                  ? ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(AppLocalizations.of(context).activityCancelledButton),
                    )
                  : _isParticipant
                      ? ElevatedButton(
                          onPressed: _leaving ? null : _leaveActivity,
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.red.shade100,
                            foregroundColor: Colors.red.shade800,
                          ),
                          child: _leaving
                              ? const CircularProgressIndicator()
                              : Text(AppLocalizations.of(context).leaveButton),
                        )
                      : ElevatedButton(
                          onPressed: _joining ? null : _joinActivity,
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _joining
                              ? const CircularProgressIndicator()
                              : Text(AppLocalizations.of(context).joinButton),
                        ),
            ),
    );
  }
}
