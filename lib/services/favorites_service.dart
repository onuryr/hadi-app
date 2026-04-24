import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritesService {
  static final _supabase = Supabase.instance.client;

  static Future<Set<String>> getFavoriteIds() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};
    try {
      final data = await _supabase
          .from('activity_favorites')
          .select('activity_id')
          .eq('user_id', userId);
      return data.map((r) => r['activity_id'].toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<bool> isFavorite(String activityId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final row = await _supabase
          .from('activity_favorites')
          .select()
          .eq('user_id', userId)
          .eq('activity_id', activityId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> add(String activityId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase.from('activity_favorites').insert({
      'user_id': userId,
      'activity_id': activityId,
    });
  }

  static Future<void> remove(String activityId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase
        .from('activity_favorites')
        .delete()
        .eq('user_id', userId)
        .eq('activity_id', activityId);
  }

  static Future<bool> toggle(String activityId) async {
    final favorited = await isFavorite(activityId);
    if (favorited) {
      await remove(activityId);
      return false;
    } else {
      await add(activityId);
      return true;
    }
  }
}
