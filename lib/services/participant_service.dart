import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ParticipantService {
  static const _apiBase = 'https://hadi-production-e4f3.up.railway.app';

  static Map<String, String> _authHeaders() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<void> updateStatus({
    required String activityId,
    required String userId,
    required String status,
  }) async {
    final resp = await http
        .patch(
          Uri.parse('$_apiBase/api/activities/$activityId/participants/$userId'),
          headers: _authHeaders(),
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('HTTP ${resp.statusCode}');
    }
  }
}
