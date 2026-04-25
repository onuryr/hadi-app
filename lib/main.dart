import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/deep_link_service.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await Supabase.initialize(
    url: 'https://eaejuirdybwolstvuhgg.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVhZWp1aXJkeWJ3b2xzdHZ1aGdnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NjQ3MDUsImV4cCI6MjA5MjU0MDcwNX0.zhQtpM4chP_KbgiLdXaqUWFtqcpHZfcLUbSsDzZZnbY',
  );

  await NotificationService.init();
  await DeepLinkService.init();
  // Mevcut oturum varsa token'ı senkron et
  if (Supabase.instance.client.auth.currentUser != null) {
    await NotificationService.syncTokenForCurrentUser();
  }

  themeNotifier = await ThemeNotifier.load();

  final seenOnboarding = await OnboardingScreen.hasSeenOnboarding();
  runApp(MyApp(seenOnboarding: seenOnboarding));
}

class MyApp extends StatefulWidget {
  final bool seenOnboarding;

  const MyApp({super.key, required this.seenOnboarding});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    Widget home;
    if (session != null) {
      home = widget.seenOnboarding ? const HomeScreen() : const OnboardingScreen();
    } else {
      home = const LoginScreen();
    }

    return MaterialApp(
      title: 'Hadi',
      navigatorKey: NotificationService.navigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeNotifier.mode,
      home: home,
    );
  }
}
