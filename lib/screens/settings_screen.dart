import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
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

  Future<Map<String, String>> _authHeaders({
    bool forceRefresh = false,
    bool requireAuth = true,
  }) async {
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
    if (requireAuth && (token == null || token.isEmpty)) {
      // ignore: use_build_context_synchronously
      final msg = mounted ? AppLocalizations.of(context).sessionError : 'Session expired';
      throw Exception(msg);
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String _extractErrorMessage(http.Response response) {
    final raw = response.body.trim();
    if (raw.isEmpty) return response.reasonPhrase ?? 'No response body';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error']?.toString();
        final message = decoded['message']?.toString();
        final detail = decoded['detail']?.toString();
        final combined = [error, message, detail]
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (combined.isNotEmpty) return combined.join(' | ');
      }
    } catch (_) {
      // Body is not JSON, return raw text.
    }
    return raw;
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
          SnackBar(content: Text(AppLocalizations.of(context).preferencesSaveFailed)),
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
      builder: (ctx) => StatefulBuilder(
          builder: (ctx2, setDialogState) {
            final l2 = AppLocalizations.of(ctx2);
            return AlertDialog(
            title: Text(l2.changePassword),
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
                        labelText: l2.currentPassword,
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? l2.currentPasswordRequired : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: l2.newPassword,
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return l2.newPasswordRequired;
                        if (v.length < 6) return l2.passwordMinLength;
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: l2.confirmNewPassword,
                        suffixIcon: IconButton(
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return l2.confirmPasswordRequired;
                        if (v != _newPasswordController.text) return l2.passwordMismatch;
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: _changingPassword ? null : () => Navigator.of(ctx2).pop(),
                child: Text(l2.cancel),
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
                        if (!ctx2.mounted) return;
                        Navigator.of(ctx2).pop();
                      },
                child: _changingPassword
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l2.save),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (mounted) setState(() => _changingPassword = true);
    try {
      final l = AppLocalizations.of(context);
      final user = Supabase.instance.client.auth.currentUser;
      final email = user?.email;
      if (email == null) throw Exception(l.sessionNotFound);

      final verifyResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      if (verifyResponse.user == null) throw Exception(l.currentPasswordInvalid);

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).passwordUpdated)),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).passwordChangeFailed}: $e')),
      );
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l.deleteAccount),
          content: Text(l.deleteAccountConfirm),
          actions: [
            TextButton(
              onPressed: _deletingAccount ? null : () => Navigator.of(ctx).pop(false),
              child: Text(l.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _deletingAccount ? null : () => Navigator.of(ctx).pop(true),
              child: Text(l.delete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    if (mounted) setState(() => _deletingAccount = true);
    try {
      final headers = await _authHeaders(forceRefresh: true, requireAuth: true);
      final response = await http
          .post(Uri.parse('$_apiBase/api/users/me/delete'), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 204) {
        final hasAuthHeader = headers['Authorization']?.isNotEmpty == true;
        final error = _extractErrorMessage(response);
        throw Exception(
          'HTTP ${response.statusCode} (authHeader: $hasAuthHeader) - $error',
        );
      }

      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).accountDeleted)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).accountDeleteFailed}: $e')),
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListenableBuilder(
        listenable: themeNotifier,
        builder: (context, _) {
          final l2 = AppLocalizations.of(context);
          return ListView(
            children: [
              _SectionHeader(title: l2.notifications),
              if (_loadingPrefs)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: Text(l2.activityUpdates),
                  value: _activityUpdates,
                  onChanged: _savingPrefs ? null : (v) => _onToggle('activityUpdates', v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.message_outlined),
                  title: Text(l2.newMessages),
                  value: _newMessages,
                  onChanged: _savingPrefs ? null : (v) => _onToggle('newMessages', v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.alarm_outlined),
                  title: Text(l2.activityReminders),
                  value: _activityReminders,
                  onChanged: _savingPrefs ? null : (v) => _onToggle('activityReminders', v),
                ),
                if (_savingPrefs)
                  ListTile(
                    leading: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: Text(l2.savingPreferences),
                  ),
              ],
              const Divider(),
              _SectionHeader(title: l2.appearance),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(l2.theme),
                subtitle: Text(l2.themeSubtitle),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(l2.systemTheme),
                      icon: const Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(l2.lightTheme),
                      icon: const Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(l2.darkTheme),
                      icon: const Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: {themeNotifier.mode},
                  onSelectionChanged: (modes) => themeNotifier.setMode(modes.first),
                ),
              ),
              const Divider(),
              _SectionHeader(title: l2.language),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SegmentedButton<AppLocaleMode>(
                  segments: [
                    ButtonSegment(
                      value: AppLocaleMode.system,
                      label: Text(l2.systemTheme),
                      icon: const Icon(Icons.smartphone),
                    ),
                    const ButtonSegment(
                      value: AppLocaleMode.tr,
                      label: Text('Türkçe'),
                      icon: Icon(Icons.language),
                    ),
                    const ButtonSegment(
                      value: AppLocaleMode.en,
                      label: Text('English'),
                      icon: Icon(Icons.translate),
                    ),
                  ],
                  selected: {localeNotifier.mode},
                  onSelectionChanged: (selection) => localeNotifier.setMode(selection.first),
                ),
              ),
              const Divider(),
              _SectionHeader(title: l2.account),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(l2.changePassword),
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
                leading: const Icon(Icons.delete_outline),
                title: Text(l2.deleteAccount),
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
          );
        },
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
