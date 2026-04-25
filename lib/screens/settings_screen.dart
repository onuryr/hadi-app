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
            _SectionHeader(title: 'Bildirimler'),
            // TODO(HAD-52): Bildirim tercihleri toggle UI ve API entegrasyonu
            const ListTile(
              leading: Icon(Icons.notifications_outlined),
              title: Text('Bildirim Tercihleri'),
              trailing: Icon(Icons.chevron_right),
            ),
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
            // TODO: Dil seçimi — uygulama dilini değiştir
            const ListTile(
              leading: Icon(Icons.language_outlined),
              title: Text('Uygulama Dili'),
              trailing: Icon(Icons.chevron_right),
            ),
            const Divider(),
            _SectionHeader(title: 'Hesap'),
            // TODO: Şifre değiştirme akışı
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Şifreyi Değiştir'),
              trailing: Icon(Icons.chevron_right),
            ),
            // TODO: Hesap silme akışı (HAD-44 kapsamı)
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
