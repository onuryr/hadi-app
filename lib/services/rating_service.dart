import 'package:supabase_flutter/supabase_flutter.dart';

class RatingService {
  static final _supabase = Supabase.instance.client;

  static Future<void> rate({
    required String activityId,
    required String ratedUserId,
    required int rating,
    String? comment,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('activity_ratings').upsert({
      'activity_id': activityId,
      'rater_id': userId,
      'rated_id': ratedUserId,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    }, onConflict: 'activity_id,rater_id,rated_id');
  }

  /// Map of rated_user_id -> rating (1-5) that current user gave for this activity
  static Future<Map<String, int>> getMyRatingsForActivity(String activityId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};
    try {
      final data = await _supabase
          .from('activity_ratings')
          .select('rated_id, rating')
          .eq('activity_id', activityId)
          .eq('rater_id', userId);
      return {for (final r in data) r['rated_id'].toString(): r['rating'] as int};
    } catch (_) {
      return {};
    }
  }

  /// Returns (average, count) for a user
  static Future<({double avg, int count})> getUserAverage(String userId) async {
    try {
      final data = await _supabase
          .from('activity_ratings')
          .select('rating')
          .eq('rated_id', userId);
      if (data.isEmpty) return (avg: 0.0, count: 0);
      final total = data.fold<int>(0, (sum, r) => sum + (r['rating'] as int));
      return (avg: total / data.length, count: data.length);
    } catch (_) {
      return (avg: 0.0, count: 0);
    }
  }
}
