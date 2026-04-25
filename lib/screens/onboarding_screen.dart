import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_seen_onboarding') ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = [
    const _OnboardingPage(
      icon: Icons.explore,
      title: 'Yakınındaki Aktiviteleri Keşfet',
      description: 'Sana yakın yürüyüş, koşu, konser ve daha fazlasını mesafeye göre sıralı gör.',
      color: Colors.deepPurple,
    ),
    const _OnboardingPage(
      icon: Icons.group_add,
      title: 'Aktivitelere Katıl',
      description: 'Beğendiğin aktiviteye tek dokunuşla katıl, katılımcılarla tanış.',
      color: Colors.indigo,
    ),
    const _OnboardingPage(
      icon: Icons.add_circle_outline,
      title: 'Kendi Aktiviteni Oluştur',
      description: 'Birkaç dakikada bir aktivite oluştur, harita ile konum seç, resim ekle.',
      color: Colors.teal,
    ),
    const _OnboardingPage(
      icon: Icons.chat_bubble_outline,
      title: 'İnsanlarla Tanış, Sohbet Et',
      description: 'Katıldığın aktivitelerde grup sohbetine katıl, katılımcılarla tanış.',
      color: Colors.orange,
    ),
    const _OnboardingPage(
      icon: Icons.privacy_tip_outlined,
      title: 'Konum ve Bildirim İzinleri',
      description:
          'Yakınındaki aktiviteleri göstermek için konumuna, etkinlik güncellemeleri için bildirim iznine ihtiyacımız var. Bir sonraki adımda sorulacak.',
      color: Colors.blue,
    ),
  ];

  Future<void> _finish() async {
    await OnboardingScreen.markSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Atla'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) => _pages[index],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i ? Colors.deepPurple : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (isLast) {
                      _finish();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isLast ? 'Başla' : 'İleri'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 96, color: color),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
