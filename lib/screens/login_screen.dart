import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.emailPasswordRequired)),
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
              SnackBar(content: Text(l.verificationCodeResent)),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.genericError)),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.genericError)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.genericError)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final l = AppLocalizations.of(context)!;
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
          SnackBar(content: Text(l.invalidCodeError)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Hadi',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l.loginSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF616161)),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_awaitingOtp,
                decoration: InputDecoration(
                  labelText: l.emailLabel,
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
                    labelText: l.passwordLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    helperText: _isSignup ? l.passwordHelperText : null,
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
                    child: const Text('Şifremi Unuttum'),
                  ),
                ),
              if (_awaitingOtp)
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  decoration: InputDecoration(
                    labelText: l.verificationCodeLabel,
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
                    : Text(_awaitingOtp
                        ? l.verifyButton
                        : (_isSignup ? l.registerButton : l.loginButton)),
              ),
              const SizedBox(height: 12),
              if (!_awaitingOtp)
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _isSignup = !_isSignup),
                  child: Text(_isSignup
                      ? l.haveAccountPrompt
                      : l.noAccountPrompt),
                ),
              if (_awaitingOtp)
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _awaitingOtp = false;
                            _otpController.clear();
                          }),
                  child: Text(l.backButton),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
