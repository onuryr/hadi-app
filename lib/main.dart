import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await Supabase.initialize(
    url: 'https://eaejuirdybwolstvuhgg.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVhZWp1aXJkeWJ3b2xzdHZ1aGdnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NjQ3MDUsImV4cCI6MjA5MjU0MDcwNX0.zhQtpM4chP_KbgiLdXaqUWFtqcpHZfcLUbSsDzZZnbY',
  );

  await NotificationService.init();
  // Mevcut oturum varsa token'ı senkron et
  if (Supabase.instance.client.auth.currentUser != null) {
    await NotificationService.syncTokenForCurrentUser();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: 'Hadi',
      navigatorKey: NotificationService.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: session != null ? const HomeScreen() : const LoginScreen(),
    );
  }
}
