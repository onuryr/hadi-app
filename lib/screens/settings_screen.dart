import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListenableBuilder(
        listenable: themeNotifier,
        builder: (context, _) => ListView(
          children: [
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
          ],
        ),
      ),
    );
  }
}
