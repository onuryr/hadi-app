import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  static final _supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchMessages(String activityId) async {
    final data = await _supabase
        .from('messages')
        .select('id, activity_id, sender_id, content, created_at, users!sender_id(display_name, avatar_url)')
        .eq('activity_id', activityId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> send(String activityId, String content) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('messages').insert({
      'activity_id': activityId,
      'sender_id': userId,
      'content': content,
    });
  }

  static Future<void> markRead(String activityId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('activity_participants')
          .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', userId)
          .eq('activity_id', activityId);
    } catch (_) {}
  }

  /// Returns list of inbox items with unread counts.
  /// Each item has: activity, latest_message, unread_count
  static Future<List<Map<String, dynamic>>> fetchInbox() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final participations = await _supabase
        .from('activity_participants')
        .select('activity_id, last_read_at, activities(id, title, image_url, category_id, scheduled_at, location_name, description, max_participants, location, creator_id)')
        .eq('user_id', userId)
        .eq('status', 'approved');

    final items = <Map<String, dynamic>>[];
    for (final p in participations) {
      final activity = p['activities'] as Map<String, dynamic>?;
      if (activity == null) continue;
      final activityId = activity['id'].toString();
      final lastRead = p['last_read_at']?.toString() ?? '1970-01-01T00:00:00Z';

      final messages = await _supabase
          .from('messages')
          .select('content, created_at, sender_id')
          .eq('activity_id', activityId)
          .order('created_at', ascending: false)
          .limit(1);

      if (messages.isEmpty) continue;
      final latest = messages.first;

      final unread = await _supabase
          .from('messages')
          .count(CountOption.exact)
          .eq('activity_id', activityId)
          .neq('sender_id', userId)
          .gt('created_at', lastRead);

      items.add({
        'activity': activity,
        'latest_message': latest,
        'unread_count': unread,
      });
    }

    items.sort((a, b) {
      final aTime = a['latest_message']['created_at'] ?? '';
      final bTime = b['latest_message']['created_at'] ?? '';
      return bTime.toString().compareTo(aTime.toString());
    });
    return items;
  }

  /// Number of activities with at least one unread message
  static Future<int> unreadActivityCount() async {
    final items = await fetchInbox();
    return items.where((item) => (item['unread_count'] as int? ?? 0) > 0).length;
  }

  static RealtimeChannel subscribeToActivity(
    String activityId,
    void Function(Map<String, dynamic>) onInsert,
  ) {
    final channel = _supabase.channel('messages:$activityId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'activity_id',
            value: activityId,
          ),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
    return channel;
  }
}
