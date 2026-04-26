import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/locale_service.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _apiBase = 'https://hadi-production-e4f3.up.railway.app';

  bool _loadingPrefs = true;
  bool _savingPrefs = false;
  bool _changingPassword = false;
  bool _deletingAccount = false;

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
          final au = _asBool(prefs, ['activityUpdates', 'ActivityUpdates', 'activity_updates'], true);
          final nm = _asBool(prefs, ['newMessages', 'NewMessages', 'new_messages'], true);
          final ar = _asBool(prefs, ['activityReminders', 'ActivityReminders', 'activity_reminders'], true);
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
    if (_savingPrefs) return;
    final au = _activityUpdates;
    final nm = _newMessages;
    final ar = _activityReminders;
    if (mounted) setState(() => _savingPrefs = true);
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
        setState(() {
          _savedActivityUpdates = au;
          _savedNewMessages = nm;
          _savedActivityReminders = ar;
        });
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
    } finally {
      if (mounted) setState(() => _savingPrefs = false);
    }
  }

  bool _asBool(Map<String, dynamic> source, List<String> keys, bool fallback) {
    for (final key in keys) {
      final value = source[key];
      if (value is bool) return value;
    }
    return fallback;
  }

  Future<void> _showChangePasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Şifreyi Değiştir'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Mevcut şifre',
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Mevcut şifre gerekli' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Yeni şifre',
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Yeni şifre gerekli';
                        if (v.length < 6) return 'En az 6 karakter olmalı';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Yeni şifre (tekrar)',
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Tekrar şifre gerekli';
                        if (v != newController.text) return 'Şifreler eşleşmiyor';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: _changingPassword ? null : () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: _changingPassword
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        await _changePassword(
                          currentPassword: currentController.text.trim(),
                          newPassword: newController.text.trim(),
                        );
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                child: _changingPassword
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Kaydet'),
              ),
            ],
          ),
        );
      },
    );

    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
  }

  Future<void> _changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (mounted) setState(() => _changingPassword = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final email = user?.email;
      if (email == null) {
        throw Exception('Oturum bilgisi bulunamadı.');
      }

      final verifyResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      if (verifyResponse.user == null) {
        throw Exception('Mevcut şifre doğrulanamadı.');
      }

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifreniz güncellendi.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Şifre değiştirilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text(
          'Bu işlem geri alınamaz. Tüm verileriniz kalıcı olarak silinecek.',
        ),
        actions: [
          TextButton(
            onPressed: _deletingAccount ? null : () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _deletingAccount ? null : () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    if (mounted) setState(() => _deletingAccount = true);
    try {
      final response = await http
          .delete(Uri.parse('$_apiBase/api/users/me'), headers: _authHeaders)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 204) {
        throw Exception('Silme başarısız (${response.statusCode})');
      }

      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hesabınız silindi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hesap silinemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
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
                onChanged: _savingPrefs ? null : (v) => _onToggle('activityUpdates', v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.message_outlined),
                title: const Text('Yeni mesajlar'),
                value: _newMessages,
                onChanged: _savingPrefs ? null : (v) => _onToggle('newMessages', v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.alarm_outlined),
                title: const Text('Aktivite hatırlatıcıları'),
                value: _activityReminders,
                onChanged: _savingPrefs ? null : (v) => _onToggle('activityReminders', v),
              ),
              if (_savingPrefs)
                const ListTile(
                  leading: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text('Bildirim tercihleri kaydediliyor...'),
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
            ListenableBuilder(
              listenable: localeNotifier,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SegmentedButton<AppLocaleMode>(
                  segments: const [
                    ButtonSegment(
                      value: AppLocaleMode.system,
                      label: Text('Sistem'),
                      icon: Icon(Icons.smartphone),
                    ),
                    ButtonSegment(
                      value: AppLocaleMode.tr,
                      label: Text('Türkçe'),
                      icon: Icon(Icons.language),
                    ),
                    ButtonSegment(
                      value: AppLocaleMode.en,
                      label: Text('English'),
                      icon: Icon(Icons.translate),
                    ),
                  ],
                  selected: {localeNotifier.mode},
                  onSelectionChanged: (selection) {
                    localeNotifier.setMode(selection.first);
                  },
                ),
              ),
            ),
            const Divider(),
            _SectionHeader(title: 'Hesap'),
            ListTile(
              leading: Icon(Icons.lock_outline),
              title: const Text('Şifreyi Değiştir'),
              trailing: _changingPassword
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _changingPassword ? null : _showChangePasswordDialog,
            ),
            ListTile(
              leading: Icon(Icons.delete_outline),
              title: const Text('Hesabı Sil'),
              trailing: _deletingAccount
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              textColor: Theme.of(context).colorScheme.error,
              iconColor: Theme.of(context).colorScheme.error,
              onTap: _deletingAccount ? null : _confirmDeleteAccount,
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
