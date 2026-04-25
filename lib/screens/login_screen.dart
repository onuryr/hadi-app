import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
        const SnackBar(content: Text('Email ve en az 6 karakterli şifre gir')),
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
              const SnackBar(content: Text('Doğrulama kodu tekrar gönderildi')),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Hata: ${e.message}')),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Etkinlik bul, insanlarla tanış',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_awaitingOtp,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              if (!_awaitingOtp)
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    helperText: _isSignup ? 'En az 6 karakter' : null,
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
                  decoration: const InputDecoration(
                    labelText: 'Doğrulama kodu',
                    helperText: 'Email adresine gelen kodu gir',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pin),
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
                        ? 'Doğrula'
                        : (_isSignup ? 'Kayıt Ol' : 'Giriş Yap')),
              ),
              const SizedBox(height: 12),
              if (!_awaitingOtp)
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _isSignup = !_isSignup),
                  child: Text(_isSignup
                      ? 'Hesabın var mı? Giriş yap'
                      : 'Hesabın yok mu? Kayıt ol'),
                ),
              if (_awaitingOtp)
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _awaitingOtp = false;
                            _otpController.clear();
                          }),
                  child: const Text('Geri dön'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
