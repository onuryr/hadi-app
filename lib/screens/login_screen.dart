import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../services/locale_service.dart';
import '../services/notification_service.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _supabase = Supabase.instance.client;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _isSignup = false;
  bool _obscurePassword = true;
  bool _awaitingOtp = false;
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _completeLogin(String userId, String email) async {
    await _supabase.from('users').upsert({
      'id': userId,
      'display_name': email.split('@').first,
    }, onConflict: 'id');
    await NotificationService.syncTokenForCurrentUser();
    final seenOnboarding = await OnboardingScreen.hasSeenOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => seenOnboarding ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).emailAndPasswordRequired)),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      AuthResponse response;
      if (_isSignup) {
        response = await _supabase.auth.signUp(email: email, password: password);
        if (response.user != null && response.user!.emailConfirmedAt == null) {
          setState(() => _awaitingOtp = true);
          return;
        }
      } else {
        response = await _supabase.auth.signInWithPassword(email: email, password: password);
      }

      if (response.user != null && mounted) {
        await _completeLogin(response.user!.id, email);
      }
    } on AuthException catch (e) {
      if (e.code == 'email_not_confirmed' || e.message.toLowerCase().contains('email not confirmed')) {
        try {
          await _supabase.auth.resend(type: OtpType.signup, email: email);
          if (mounted) {
            setState(() => _awaitingOtp = true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).codeSentAgain)),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_friendlyAuthMessage(e))),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyAuthMessage(e))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bir sorun oluştu, biraz sonra tekrar dener misin?')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthMessage(AuthException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();
    if (code == 'invalid_credentials' || msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
      return 'Email veya şifre hatalı. Tekrar dener misin?';
    }
    if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
      return 'Email adresini henüz doğrulamadın. Gelen koda bak.';
    }
    if (code == 'user_already_exists' || code == 'email_exists' || msg.contains('already registered') || msg.contains('user already')) {
      return 'Bu email zaten kayıtlı. Giriş yapmayı dener misin?';
    }
    if (code == 'weak_password' || msg.contains('password should be') || msg.contains('weak password')) {
      return 'Şifre çok zayıf. En az 6 karakter, harf ve rakam karışık dene.';
    }
    if (code == 'over_request_rate_limit' || msg.contains('rate limit') || msg.contains('too many')) {
      return 'Çok fazla deneme yaptın, biraz bekle ve tekrar dene.';
    }
    if (code == 'signup_disabled' || msg.contains('signup is disabled')) {
      return 'Şu an yeni kayıt alınmıyor.';
    }
    if (msg.contains('network') || msg.contains('connection') || msg.contains('timeout')) {
      return 'İnternet bağlantısı yok gibi. Bağlantını kontrol et.';
    }
    return 'Bir sorun oluştu, biraz sonra tekrar dener misin?';
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.isEmpty) return;

    setState(() => _loading = true);
    try {
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.signup,
      );
      if (response.user != null && mounted) {
        await _completeLogin(response.user!.id, email);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kod hatalı: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _localeLabel(AppLocaleMode mode) => switch (mode) {
        AppLocaleMode.tr => 'Türkçe',
        AppLocaleMode.en => 'English',
      };

  String _localeFlag(AppLocaleMode mode) => switch (mode) {
        AppLocaleMode.tr => '🇹🇷',
        AppLocaleMode.en => '🇬🇧',
      };

  Future<void> _openLanguageSheet() async {
    final picked = await showModalBottomSheet<AppLocaleMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇹🇷', style: TextStyle(fontSize: 24)),
              title: const Text('Türkçe'),
              trailing: localeNotifier.mode == AppLocaleMode.tr
                  ? const Icon(Icons.check, color: Colors.deepPurple)
                  : null,
              onTap: () => Navigator.of(ctx).pop(AppLocaleMode.tr),
            ),
            ListTile(
              leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
              title: const Text('English'),
              trailing: localeNotifier.mode == AppLocaleMode.en
                  ? const Icon(Icons.check, color: Colors.deepPurple)
                  : null,
              onTap: () => Navigator.of(ctx).pop(AppLocaleMode.en),
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await localeNotifier.setMode(picked);
    }
  }

  Widget _buildLanguagePill() {
    return ListenableBuilder(
      listenable: localeNotifier,
      builder: (context, _) {
        return Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 1,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _openLanguageSheet,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_localeFlag(localeNotifier.mode), style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    _localeLabel(localeNotifier.mode),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 96),
              Center(
                child: Image.asset(
                  'assets/icon/wordmark_clean.png',
                  width: 120,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.appSlogan,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF616161), fontSize: 14),
              ),
              const SizedBox(height: 36),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_awaitingOtp,
                decoration: InputDecoration(
                  labelText: l.email,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              if (!_awaitingOtp)
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l.password,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    helperText: _isSignup ? l.passwordMinChars : null,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
              if (!_awaitingOtp && !_isSignup)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                    child: Text(l.forgotPassword),
                  ),
                ),
              if (_awaitingOtp)
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  decoration: InputDecoration(
                    labelText: l.verificationCode,
                    helperText: l.verificationCodeHelper,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.pin),
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : (_awaitingOtp ? _verifyOtp : _submit),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const CircularProgressIndicator()
                    : Text(_awaitingOtp ? l.verify : (_isSignup ? l.signUp : l.logIn)),
              ),
              const SizedBox(height: 12),
              if (!_awaitingOtp)
                TextButton(
                  onPressed: _loading ? null : () => setState(() => _isSignup = !_isSignup),
                  child: Text(_isSignup ? l.alreadyHaveAccount : l.dontHaveAccount),
                ),
              if (_awaitingOtp)
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _awaitingOtp = false;
                            _otpController.clear();
                          }),
                  child: Text(l.back),
                ),
            ],
          ),
        ),
            Positioned(
              top: 8,
              right: 8,
              child: _buildLanguagePill(),
            ),
          ],
        ),
      ),
    );
  }
}
