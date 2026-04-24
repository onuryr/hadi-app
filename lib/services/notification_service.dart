import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/activity_detail_screen.dart';

class NotificationService {
  static const _apiBase = 'https://hadi-production-e4f3.up.railway.app';
  static const _channelId = 'hadi_default';
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotif = FlutterLocalNotificationsPlugin();
  static final navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> _post(String path, Map<String, dynamic> body) async {
    try {
      await http.post(
        Uri.parse('$_apiBase$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  static Future<void> notifyActivityUpdated(String activityId, String title, {String? changes}) =>
      _post('/api/activities/$activityId/notify-updated', {'title': title, 'changes': changes});

  static Future<void> notifyActivityJoined(String activityId, String userName) =>
      _post('/api/activities/$activityId/notify-joined', {'userName': userName});

  static Future<void> notifyActivityLeft(String activityId, String userName) =>
      _post('/api/activities/$activityId/notify-left', {'userName': userName});

  static Future<void> notifyActivityDeleted(String activityId, String title) =>
      _post('/api/activities/$activityId/notify-deleted', {'title': title});

  static Future<void> init() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      await _localNotif.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null) {
            _navigateToActivity(response.payload!);
          }
        },
      );

      await _localNotif
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            'Hadi Bildirimleri',
            description: 'Aktivite güncellemeleri ve bildirimler',
            importance: Importance.high,
          ));

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);

      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationTap(initialMessage);
        });
      }
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotif.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Hadi Bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: message.data['activityId'],
    );
  }

  static Future<void> _navigateToActivity(String activityId) async {
    try {
      final data = await Supabase.instance.client
          .from('activities')
          .select('id, title, location_name, scheduled_at, max_participants, description, image_url, category_id')
          .eq('id', activityId)
          .maybeSingle();
      if (data == null) return;
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.push(MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: data)));
    } catch (e) {
      debugPrint('Notification navigation error: $e');
    }
  }

  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    final activityId = message.data['activityId'];
    if (activityId == null) return;
    await _navigateToActivity(activityId);
  }

  static Future<void> syncTokenForCurrentUser() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final token = await _messaging.getToken();
      if (token == null) return;
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': token})
          .eq('id', user.id);
      debugPrint('FCM token synced: ${token.substring(0, 20)}...');

      _messaging.onTokenRefresh.listen((newToken) async {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser == null) return;
        await Supabase.instance.client
            .from('users')
            .update({'fcm_token': newToken})
            .eq('id', currentUser.id);
      });
    } catch (e) {
      debugPrint('FCM token sync error: $e');
    }
  }
}
