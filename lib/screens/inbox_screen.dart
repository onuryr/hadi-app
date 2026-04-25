import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/chat_service.dart';
import '../services/deep_link_service.dart';
import '../utils/category_defaults.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await ChatService.fetchInbox();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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

  String _formatTime(String createdAt) {
    final dt = DateTime.parse(createdAt).toLocal();
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return 'Dün';
    }
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesajlar'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Henüz mesaj yok', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final activity = item['activity'] as Map<String, dynamic>;
                      final msg = item['latest_message'] as Map<String, dynamic>;
                      final unread = item['unread_count'] as int;
                      final imageUrl = activityImageUrl(
                        imageUrl: activity['image_url'],
                        categoryId: activity['category_id'],
                      );
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(width: 48, height: 48, color: Colors.grey.shade200),
                            errorWidget: (_, __, ___) => Container(width: 48, height: 48, color: Colors.grey.shade200),
                          ),
                        ),
                        title: Text(
                          activity['title'] ?? '',
                          style: TextStyle(
                            fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          msg['content'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unread > 0 ? Colors.black87 : Colors.grey,
                            fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_formatTime(msg['created_at']), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            if (unread > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                activityId: activity['id'].toString(),
                                activityTitle: activity['title'] ?? '',
                              ),
                            ),
                          );
                          _load();
                        },
                        onLongPress: () => _shareActivity(activity),
                      );
                    },
                  ),
                ),
    );
  }
}
