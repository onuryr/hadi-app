import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';

class ReportBlockService {
  static const _apiBase = 'https://hadi-production-e4f3.up.railway.app';

  static Map<String, String> _authHeaders() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<void> createReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? description,
  }) async {
    final resp = await http
        .post(
          Uri.parse('$_apiBase/api/reports'),
          headers: _authHeaders(),
          body: jsonEncode({
            'targetType': targetType,
            'targetId': targetId,
            'reason': reason,
            if (description != null && description.isNotEmpty) 'description': description,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200 && resp.statusCode != 201 && resp.statusCode != 204) {
      throw Exception('HTTP ${resp.statusCode}');
    }
  }

  static Future<void> blockUser(String userId) async {
    final resp = await http
        .post(
          Uri.parse('$_apiBase/api/users/$userId/block'),
          headers: _authHeaders(),
          body: '{}',
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200 && resp.statusCode != 201 && resp.statusCode != 204) {
      throw Exception('HTTP ${resp.statusCode}');
    }
  }

  static Future<void> unblockUser(String userId) async {
    final resp = await http
        .delete(
          Uri.parse('$_apiBase/api/users/$userId/block'),
          headers: _authHeaders(),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('HTTP ${resp.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> getMyBlocks() async {
    final resp = await http
        .get(
          Uri.parse('$_apiBase/api/users/me/blocks'),
          headers: _authHeaders(),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final list = jsonDecode(resp.body) as List;
    return list.cast<Map<String, dynamic>>();
  }

  // --- Dialog helpers ---

  static List<String> _localizedReasons(AppLocalizations l) => [
        l.reasonSpam,
        l.reasonInappropriate,
        l.reasonHarassment,
        l.reasonMisleading,
        l.reasonOther,
      ];

  /// Shows the report dialog and submits the report if user confirms.
  /// [targetType] is 'user' or 'activity'. Returns true if submitted.
  static Future<bool> showReportDialog(
    BuildContext context, {
    required String targetType,
    required String targetId,
  }) async {
    final l = AppLocalizations.of(context);
    final reasons = _localizedReasons(l);
    String? selectedReason = reasons.first;
    final descController = TextEditingController();
    bool submitting = false;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(l.reportTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.whyReport),
                const SizedBox(height: 8),
                ...reasons.map(
                  (r) => RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(r),
                    value: r,
                    groupValue: selectedReason,
                    onChanged: (v) => setStateDialog(() => selectedReason = v),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l.descriptionOptional,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(false),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (selectedReason == null) return;
                      setStateDialog(() => submitting = true);
                      try {
                        await createReport(
                          targetType: targetType,
                          targetId: targetId,
                          reason: selectedReason!,
                          description: descController.text.trim(),
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop(true);
                      } catch (e) {
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop(false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('${l.reportFailed}: $e')),
                          );
                        }
                      }
                    },
              child: Text(l.send),
            ),
          ],
        ),
      ),
    );

    descController.dispose();
    return submitted == true;
  }

  /// Shows a block confirmation dialog and blocks the user if confirmed.
  /// Returns true if block was applied.
  static Future<bool> showBlockConfirmDialog(
    BuildContext context, {
    required String userId,
    required String displayName,
  }) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.blockUserDialogTitle),
        content: Text(l.blockUserDialogContent(displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.block, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    try {
      await blockUser(userId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.userBlockedSnack(displayName))),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.blockFailed}: $e')),
        );
      }
      return false;
    }
  }
}
