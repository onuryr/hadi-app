import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/activity_detail_screen.dart';
import 'notification_service.dart';

class DeepLinkService {
  static final _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;

  static Future<void> init() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _handle(initial));
      }
      _sub = _appLinks.uriLinkStream.listen(_handle);
    } catch (e) {
      debugPrint('DeepLinkService init error: $e');
    }
  }

  static String activityUrl(String activityId) => 'hadi://activity/$activityId';

  static Future<void> _handle(Uri uri) async {
    if (uri.scheme != 'hadi' || uri.host != 'activity') return;
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;
    final activityId = segments.first;
    try {
      final data = await Supabase.instance.client
          .from('activities')
          .select('id, title, location_name, scheduled_at, max_participants, description, image_url, category_id')
          .eq('id', activityId)
          .maybeSingle();
      if (data == null) return;
      final nav = NotificationService.navigatorKey.currentState;
      if (nav == null) return;
      nav.push(MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: data)));
    } catch (e) {
      debugPrint('Deep link navigation error: $e');
    }
  }

  static void dispose() {
    _sub?.cancel();
  }
}
