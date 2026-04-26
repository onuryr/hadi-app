import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../services/report_block_service.dart';

class ChatScreen extends StatefulWidget {
  final String activityId;
  final String activityTitle;

  const ChatScreen({
    super.key,
    required this.activityId,
    required this.activityTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _isAtBottom = true;
  int _newMessageCount = 0;
  RealtimeChannel? _channel;
  final Map<String, Map<String, dynamic>> _userCache = {};
  Set<String> _blockedUserIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadBlockedUsers();
    _loadMessages();
    _channel = ChatService.subscribeToActivity(widget.activityId, _onNewMessage);
    ChatService.markRead(widget.activityId);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 60;
    if (atBottom && _newMessageCount > 0) {
      setState(() => _newMessageCount = 0);
    }
    if (atBottom != _isAtBottom) {
      setState(() => _isAtBottom = atBottom);
    }
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final list = await ReportBlockService.getMyBlocks();
      if (mounted) {
        setState(() {
          _blockedUserIds = list
              .map((e) => e['userId']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    ChatService.markRead(widget.activityId);
    _controller.dispose();
    _scrollController.dispose();
    if (_channel != null) _supabase.removeChannel(_channel!);
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await ChatService.fetchMessages(widget.activityId);
      for (final m in data) {
        final user = m['users'];
        if (user is Map) _userCache[m['sender_id'].toString()] = Map<String, dynamic>.from(user);
      }
      setState(() {
        _messages = data;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).messagesLoadFailed}: $e')),
        );
      }
    }
  }

  Future<void> _onNewMessage(Map<String, dynamic> raw) async {
    final senderId = raw['sender_id']?.toString();
    if (senderId != null && !_userCache.containsKey(senderId)) {
      try {
        final user = await _supabase
            .from('users')
            .select('display_name, avatar_url')
            .eq('id', senderId)
            .maybeSingle();
        if (user != null) _userCache[senderId] = user;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _messages.add({
        ...raw,
        'users': _userCache[senderId ?? ''],
      });
    });
    if (_isAtBottom) {
      _scrollToBottom();
    } else {
      setState(() => _newMessageCount++);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Optimistic insert — visible immediately, removed on success (realtime will supply real record)
    final optimisticId = 'opt_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = {
      'id': optimisticId,
      'activity_id': widget.activityId,
      'sender_id': userId,
      'content': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'users': _userCache[userId],
      '_optimistic': true,
    };

    _controller.clear();
    setState(() {
      _messages.add(optimisticMsg);
      _sending = true;
    });
    _scrollToBottom();

    try {
      await ChatService.send(widget.activityId, text);
      // Realtime will deliver the real record; drop the placeholder.
      if (mounted) setState(() => _messages.removeWhere((m) => m['id'] == optimisticId));

      String senderName = _userCache[userId]?['display_name'] ?? '';
      if (senderName.isEmpty) {
        try {
          final row = await _supabase.from('users').select('display_name').eq('id', userId).single();
          senderName = row['display_name'] ?? '';
          _userCache[userId] = {'display_name': senderName, 'avatar_url': null};
        } catch (_) {}
      }
      NotificationService.notifyNewMessage(
        activityId: widget.activityId,
        senderId: userId,
        senderName: senderName,
        activityTitle: widget.activityTitle,
        content: text,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m['id'] == optimisticId));
        final msg = e.toString().toLowerCase();
        final isOffline = msg.contains('socketexception') ||
            msg.contains('network') ||
            msg.contains('failed host lookup') ||
            msg.contains('connection refused') ||
            msg.contains('no address associated');
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isOffline ? l.noInternetConnection : '${l.sendFailed}: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTime(String? createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.parse(createdAt).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    final l = AppLocalizations.of(context);
    if (_sameDay(dt, now)) return l.today;
    final yesterday = now.subtract(const Duration(days: 1));
    if (_sameDay(dt, yesterday)) return l.yesterday;
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildMessageList(String? currentUserId) {
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final m = _messages[index];
            final isMe = m['sender_id']?.toString() == currentUserId;
            final createdAt = m['created_at']?.toString();
            final dt = createdAt != null ? DateTime.parse(createdAt).toLocal() : DateTime.now();

            Widget? dayHeader;
            if (index == 0 ||
                !_sameDay(
                  dt,
                  DateTime.parse(_messages[index - 1]['created_at']).toLocal(),
                )) {
              dayHeader = Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_dayLabel(context, dt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                ),
              );
            }

            final senderId = m['sender_id']?.toString() ?? '';
            final isBlocked = !isMe && _blockedUserIds.contains(senderId);
            final user = m['users'];
            final name = user?['display_name'] ?? 'Bilinmiyor';
            final avatarUrl = user?['avatar_url'] as String?;
            final isOptimistic = m['_optimistic'] == true;

            if (isBlocked) {
              return Column(
                children: [
                  ?dayHeader,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.grey.shade300,
                        child: const Icon(Icons.block, size: 14, color: Colors.grey),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(4),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context).userBlocked,
                          style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            final bubble = Opacity(
              opacity: isOptimistic ? 0.6 : 1.0,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    Text(
                      m['content'] ?? '',
                      style: TextStyle(
                        color: isMe
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.75)
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (isOptimistic) ...[
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: isMe
                                  ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.75)
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );

            return Column(
              children: [
                ?dayHeader,
                Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMe) ...[
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: avatarUrl != null
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 12))
                            : null,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: bubble,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        if (_newMessageCount > 0)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  setState(() => _newMessageCount = 0);
                  _scrollToBottom();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Text(
                    '$_newMessageCount yeni mesaj ↓',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.activityTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(AppLocalizations.of(context).noChatYet, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : _buildMessageList(currentUserId),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).typeMessage,
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: _sending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
