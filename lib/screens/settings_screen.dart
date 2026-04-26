import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  static const _prefsActivityUpdatesKey = 'settings_activity_updates';
  static const _prefsNewMessagesKey = 'settings_new_messages';
  static const _prefsActivityRemindersKey = 'settings_activity_reminders';

  bool _loadingPrefs = true;
  bool _savingPrefs = false;
  bool _changingPassword = false;
  bool _deletingAccount = false;
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Optimistic (displayed) values
  bool _activityUpdates = true;
  bool _newMessages = true;
  bool _activityReminders = true;

  // Last successfully saved values — used to revert on API error
  bool _savedActivityUpdates = true;
  bool _savedNewMessages = true;
  bool _savedActivityReminders = true;

  Timer? _debounce;

  Future<Map<String, String>> _authHeaders({bool forceRefresh = false}) async {
    final auth = Supabase.instance.client.auth;
    var token = auth.currentSession?.accessToken;
    if (forceRefresh || token == null) {
      try {
        final refreshed = await auth.refreshSession();
        token = refreshed.session?.accessToken ?? auth.currentSession?.accessToken;
      } catch (_) {
        token = auth.currentSession?.accessToken;
      }
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  bool _isEnglish(BuildContext context) {
    final mode = localeNotifier.mode;
    if (mode == AppLocaleMode.en) return true;
    if (mode == AppLocaleMode.tr) return false;
    return Localizations.localeOf(context).languageCode.toLowerCase().startsWith('en');
  }

  String _tr(BuildContext context, String tr, String en) {
    return _isEnglish(context) ? en : tr;
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    await _loadPrefsFromLocal();
    try {
      final resp = await http
          .get(Uri.parse('$_apiBase/api/users/me'), headers: await _authHeaders())
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
          await _savePrefsToLocal(au: au, nm: nm, ar: ar);
        }
      }
    } catch (_) {
      // Fallback to direct Supabase profile read if API route is unavailable.
      await _loadPrefsFromSupabase();
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
            headers: await _authHeaders(),
            body: jsonEncode({
              'activityUpdates': au,
              'newMessages': nm,
              'activityReminders': ar,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 && mounted) {
        await _savePrefsToLocal(au: au, nm: nm, ar: ar);
        setState(() {
          _savedActivityUpdates = au;
          _savedNewMessages = nm;
          _savedActivityReminders = ar;
        });
      } else {
        final fallbackSaved = await _savePrefsToSupabase(au: au, nm: nm, ar: ar);
        if (!fallbackSaved) {
          throw Exception(resp.statusCode);
        }
        await _savePrefsToLocal(au: au, nm: nm, ar: ar);
        if (mounted) {
          setState(() {
            _savedActivityUpdates = au;
            _savedNewMessages = nm;
            _savedActivityReminders = ar;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _activityUpdates = _savedActivityUpdates;
          _newMessages = _savedNewMessages;
          _activityReminders = _savedActivityReminders;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr(context, 'Tercihler kaydedilemedi. Tekrar deneyin.', 'Preferences could not be saved. Please try again.'))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPrefs = false);
    }
  }

  Future<void> _loadPrefsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final au = prefs.getBool(_prefsActivityUpdatesKey);
      final nm = prefs.getBool(_prefsNewMessagesKey);
      final ar = prefs.getBool(_prefsActivityRemindersKey);
      if (!mounted) return;
      setState(() {
        if (au != null) {
          _activityUpdates = au;
          _savedActivityUpdates = au;
        }
        if (nm != null) {
          _newMessages = nm;
          _savedNewMessages = nm;
        }
        if (ar != null) {
          _activityReminders = ar;
          _savedActivityReminders = ar;
        }
      });
    } catch (_) {
      // Ignore local cache failures.
    }
  }

  Future<void> _savePrefsToLocal({
    required bool au,
    required bool nm,
    required bool ar,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsActivityUpdatesKey, au);
      await prefs.setBool(_prefsNewMessagesKey, nm);
      await prefs.setBool(_prefsActivityRemindersKey, ar);
    } catch (_) {
      // Ignore local cache failures.
    }
  }

  Future<void> _loadPrefsFromSupabase() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final row = await Supabase.instance.client
          .from('users')
          .select('notification_prefs')
          .eq('id', userId)
          .maybeSingle();
      final prefs = row?['notification_prefs'];
      if (prefs is! Map) return;
      final prefMap = Map<String, dynamic>.from(prefs);
      final au = _asBool(prefMap, ['activityUpdates', 'ActivityUpdates', 'activity_updates'], true);
      final nm = _asBool(prefMap, ['newMessages', 'NewMessages', 'new_messages'], true);
      final ar = _asBool(prefMap, ['activityReminders', 'ActivityReminders', 'activity_reminders'], true);
      await _savePrefsToLocal(au: au, nm: nm, ar: ar);
      if (!mounted) return;
      setState(() {
        _activityUpdates = au;
        _newMessages = nm;
        _activityReminders = ar;
        _savedActivityUpdates = au;
        _savedNewMessages = nm;
        _savedActivityReminders = ar;
      });
    } catch (_) {
      // Keep defaults if both API and Supabase read fail.
    }
  }

  Future<bool> _savePrefsToSupabase({
    required bool au,
    required bool nm,
    required bool ar,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;
      await Supabase.instance.client.from('users').update({
        'notification_prefs': {
          'activity_updates': au,
          'new_messages': nm,
          'activity_reminders': ar,
        }
      }).eq('id', userId);
      return true;
    } catch (_) {
      return false;
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
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
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
              key: _passwordFormKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: _tr(context, 'Mevcut şifre', 'Current password'),
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? _tr(context, 'Mevcut şifre gerekli', 'Current password is required') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: _tr(context, 'Yeni şifre', 'New password'),
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return _tr(context, 'Yeni şifre gerekli', 'New password is required');
                        if (v.length < 6) return _tr(context, 'En az 6 karakter olmalı', 'Must be at least 6 characters');
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: _tr(context, 'Yeni şifre (tekrar)', 'Confirm new password'),
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return _tr(context, 'Tekrar şifre gerekli', 'Password confirmation is required');
                        if (v != _newPasswordController.text) return _tr(context, 'Şifreler eşleşmiyor', 'Passwords do not match');
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
                child: Text(_tr(context, 'İptal', 'Cancel')),
              ),
              FilledButton(
                onPressed: _changingPassword
                    ? null
                    : () async {
                        if (!_passwordFormKey.currentState!.validate()) return;
                        await _changePassword(
                          currentPassword: _currentPasswordController.text.trim(),
                          newPassword: _newPasswordController.text.trim(),
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
                    : Text(_tr(context, 'Kaydet', 'Save')),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final isEn = _isEnglish(context);
    String t(String tr, String en) => isEn ? en : tr;
    if (mounted) setState(() => _changingPassword = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final email = user?.email;
      if (email == null) {
        throw Exception(t('Oturum bilgisi bulunamadı.', 'Session information not found.'));
      }

      final verifyResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      if (verifyResponse.user == null) {
        throw Exception(t('Mevcut şifre doğrulanamadı.', 'Current password could not be verified.'));
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
        SnackBar(content: Text('${_tr(context, 'Şifre değiştirilemedi', 'Password could not be changed')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr(context, 'Hesabı Sil', 'Delete Account')),
        content: Text(
          _tr(context, 'Bu işlem geri alınamaz. Tüm verileriniz kalıcı olarak silinecek.', 'This action cannot be undone. All your data will be permanently deleted.'),
        ),
        actions: [
          TextButton(
            onPressed: _deletingAccount ? null : () => Navigator.of(context).pop(false),
            child: Text(_tr(context, 'İptal', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _deletingAccount ? null : () => Navigator.of(context).pop(true),
            child: Text(_tr(context, 'Sil', 'Delete')),
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
          .delete(Uri.parse('$_apiBase/api/users/me'), headers: await _authHeaders(forceRefresh: true))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) {
        final retry = await http
            .delete(Uri.parse('$_apiBase/api/users/me'), headers: await _authHeaders(forceRefresh: true))
            .timeout(const Duration(seconds: 15));
        if (retry.statusCode == 204) {
          await Supabase.instance.client.auth.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_tr(context, 'Hesabınız silindi.', 'Your account has been deleted.'))),
          );
          return;
        }
        throw Exception('401 (${retry.body})');
      }
      if (response.statusCode != 204) {
        throw Exception('Silme başarısız (${response.statusCode}) ${response.body}');
      }

      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr(context, 'Hesabınız silindi.', 'Your account has been deleted.'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_tr(context, 'Hesap silinemedi', 'Account could not be deleted')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tr(context, 'Ayarlar', 'Settings'))),
      body: ListenableBuilder(
        listenable: themeNotifier,
        builder: (context, _) => ListView(
          children: [
            _SectionHeader(title: _tr(context, 'Bildirimler', 'Notifications')),
            if (_loadingPrefs)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: Text(_tr(context, 'Aktivite güncellemeleri', 'Activity updates')),
                value: _activityUpdates,
                onChanged: _savingPrefs ? null : (v) => _onToggle('activityUpdates', v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.message_outlined),
                title: Text(_tr(context, 'Yeni mesajlar', 'New messages')),
                value: _newMessages,
                onChanged: _savingPrefs ? null : (v) => _onToggle('newMessages', v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.alarm_outlined),
                title: Text(_tr(context, 'Aktivite hatırlatıcıları', 'Activity reminders')),
                value: _activityReminders,
                onChanged: _savingPrefs ? null : (v) => _onToggle('activityReminders', v),
              ),
              if (_savingPrefs)
                ListTile(
                  leading: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text(_tr(context, 'Bildirim tercihleri kaydediliyor...', 'Saving notification preferences...')),
                ),
            ],
            const Divider(),
            _SectionHeader(title: _tr(context, 'Görünüm', 'Appearance')),
            ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text(_tr(context, 'Tema', 'Theme')),
              subtitle: Text(_tr(context, 'Uygulama görünümünü seç', 'Choose app appearance')),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(_tr(context, 'Sistem', 'System')),
                    icon: Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(_tr(context, 'Açık', 'Light')),
                    icon: Icon(Icons.light_mode),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(_tr(context, 'Koyu', 'Dark')),
                    icon: Icon(Icons.dark_mode),
                  ),
                ],
                selected: {themeNotifier.mode},
                onSelectionChanged: (modes) => themeNotifier.setMode(modes.first),
              ),
            ),
            const Divider(),
            _SectionHeader(title: _tr(context, 'Dil', 'Language')),
            ListenableBuilder(
              listenable: localeNotifier,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SegmentedButton<AppLocaleMode>(
                  segments: [
                    ButtonSegment(
                      value: AppLocaleMode.system,
                      label: Text(_tr(context, 'Sistem', 'System')),
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
            _SectionHeader(title: _tr(context, 'Hesap', 'Account')),
            ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text(_tr(context, 'Şifreyi Değiştir', 'Change Password')),
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
              title: Text(_tr(context, 'Hesabı Sil', 'Delete Account')),
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
