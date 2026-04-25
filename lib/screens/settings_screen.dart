import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _apiBase = 'https://hadi-production-e4f3.up.railway.app';

  bool _loadingPrefs = true;

  // Optimistic (displayed) values
  bool _activityUpdates = true;
  bool _newMessages = true;
  bool _activityReminders = true;

  // Last successfully saved values — used to revert on API error
  bool _savedActivityUpdates = true;
  bool _savedNewMessages = true;
  bool _savedActivityReminders = true;

  Timer? _debounce;

  Map<String, String> get _authHeaders {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    try {
      final resp = await http
          .get(Uri.parse('$_apiBase/api/users/me'), headers: _authHeaders)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final prefs = data['notificationPrefs'] as Map<String, dynamic>?;
        if (prefs != null) {
          final au = prefs['activityUpdates'] as bool? ?? true;
          final nm = prefs['newMessages'] as bool? ?? true;
          final ar = prefs['activityReminders'] as bool? ?? true;
          setState(() {
            _activityUpdates = au;
            _newMessages = nm;
            _activityReminders = ar;
            _savedActivityUpdates = au;
            _savedNewMessages = nm;
            _savedActivityReminders = ar;
          });
        }
      }
    } catch (_) {
      // Keep defaults on load failure
    } finally {
      if (mounted) setState(() => _loadingPrefs = false);
    }
  }

  void _onToggle(String field, bool value) {
    setState(() {
      switch (field) {
        case 'activityUpdates':
          _activityUpdates = value;
        case 'newMessages':
          _newMessages = value;
        case 'activityReminders':
          _activityReminders = value;
      }
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _patchPrefs);
  }

  Future<void> _patchPrefs() async {
    final au = _activityUpdates;
    final nm = _newMessages;
    final ar = _activityReminders;
    try {
      final resp = await http
          .patch(
            Uri.parse('$_apiBase/api/users/me/notification-prefs'),
            headers: _authHeaders,
            body: jsonEncode({
              'activityUpdates': au,
              'newMessages': nm,
              'activityReminders': ar,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 && mounted) {
        _savedActivityUpdates = au;
        _savedNewMessages = nm;
        _savedActivityReminders = ar;
      } else {
        throw Exception(resp.statusCode);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _activityUpdates = _savedActivityUpdates;
          _newMessages = _savedNewMessages;
          _activityReminders = _savedActivityReminders;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tercihler kaydedilemedi. Tekrar deneyin.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListenableBuilder(
        listenable: themeNotifier,
        builder: (context, _) => ListView(
          children: [
            _SectionHeader(title: 'Bildirimler'),
            if (_loadingPrefs)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('Aktivite güncellemeleri'),
                value: _activityUpdates,
                onChanged: (v) => _onToggle('activityUpdates', v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.message_outlined),
                title: const Text('Yeni mesajlar'),
                value: _newMessages,
                onChanged: (v) => _onToggle('newMessages', v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.alarm_outlined),
                title: const Text('Aktivite hatırlatıcıları'),
                value: _activityReminders,
                onChanged: (v) => _onToggle('activityReminders', v),
              ),
            ],
            const Divider(),
            _SectionHeader(title: 'Görünüm'),
            const ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text('Tema'),
              subtitle: Text('Uygulama görünümünü seç'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Sistem'),
                    icon: Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Açık'),
                    icon: Icon(Icons.light_mode),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Koyu'),
                    icon: Icon(Icons.dark_mode),
                  ),
                ],
                selected: {themeNotifier.mode},
                onSelectionChanged: (modes) => themeNotifier.setMode(modes.first),
              ),
            ),
            const Divider(),
            _SectionHeader(title: 'Dil'),
            const ListTile(
              leading: Icon(Icons.language_outlined),
              title: Text('Uygulama Dili'),
              trailing: Icon(Icons.chevron_right),
            ),
            const Divider(),
            _SectionHeader(title: 'Hesap'),
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Şifreyi Değiştir'),
              trailing: Icon(Icons.chevron_right),
            ),
            const ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('Hesabı Sil'),
              trailing: Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
