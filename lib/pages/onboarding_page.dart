// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Onboarding Page  (photo-based)
//  3 pages with real background images + role selector
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';

const String kOnboardingSeenKey = 'onboarding_seen_v1';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {

  final PageController _pageCtrl = PageController();
  int      _page     = 0;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  // ── Pages data ─────────────────────────────────────────────
  static const _pages = [
    _PageData(
      imagePath: 'assets/images/onboarding/onboard_1.jpg',
      tag:       'اكتشف',
      title:     'أهلاً بيك في\nYalla Trip',
      subtitle:  'اكتشف أجمل المنتجعات والشاليهات\nعلى الساحل المصري',
      accentColor: Color(0xFFFF6B35),
    ),
    _PageData(
      imagePath: 'assets/images/onboarding/onboard_2.jpg',
      tag:       'احجز',
      title:     'ساحل، جونة،\nشرم وأكتر',
      subtitle:  'أكثر من ٤٠٠ وجهة بأسعار تنافسية\nوعروض يومية حصرية',
      accentColor: Color(0xFFFF8C42),
    ),
    _PageData(
      imagePath: 'assets/images/onboarding/onboard_3.jpg',
      tag:       'استمتع',
      title:     'ابدأ\nرحلتك!',
      subtitle:  'سجّل دخولك دلوقتي وابدأ رحلتك\nمع أجمل المنتجعات والشاليهات',
      accentColor: Color(0xFFFF6B35),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _skipToLast() {
    _pageCtrl.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _goToApp() async {
    // Persist that the user has seen the onboarding so it doesn't show again.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kOnboardingSeenKey, true);
    } catch (_) {/* best-effort */}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fade,
        child: PageView.builder(
          controller: _pageCtrl,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (i) => setState(() => _page = i),
          itemCount: _pages.length,
          itemBuilder: (_, i) => _buildPage(i),
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    final data   = _pages[index];
    final isLast = index == _pages.length - 1;

    return Stack(fit: StackFit.expand, children: [

      // ── Background image ──────────────────────────────────
      // صور الـ onboarding:
      // assets/images/onboarding/onboard_1.jpg
      // assets/images/onboarding/onboard_2.jpg
      // assets/images/onboarding/onboard_3.jpg
      // حطها في مجلد assets وأضفها في pubspec.yaml
      _BackgroundImage(imagePath: data.imagePath),

      // ── Dark gradient overlay ─────────────────────────────
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x00000000),
              Color(0x55000000),
              Color(0xCC000000),
              Color(0xF0000000),
            ],
            stops: [0.0, 0.35, 0.65, 1.0],
          ),
        ),
      ),

      // ── Content ───────────────────────────────────────────
      SafeArea(
        child: Column(children: [

          // ── Top bar: skip + dots ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 8),
            child: Row(children: [
              // Tag pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: data.accentColor.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(data.tag,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    )),
              ),

              const Spacer(),

              // Skip button (first 2 pages)
              if (!isLast)
                GestureDetector(
                  onTap: _skipToLast,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1),
                    ),
                    child: const Text('تخطي',
                        style: TextStyle(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
            ]),
          ),

          const Spacer(),

          // ── Dots ─────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              final sel = _page == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: sel ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: sel
                      ? data.accentColor
                      : Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          const SizedBox(height: 24),

          // ── Title + subtitle ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title,
                    style: const TextStyle(
                      fontSize: 34, fontWeight: FontWeight.w900,
                      color: Colors.white, height: 1.15,
                      letterSpacing: -0.8,
                    )),
                const SizedBox(height: 12),
                Text(data.subtitle,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.75),
                      height: 1.6,
                    )),
              ],
            ),
          ),

          const SizedBox(height: 28),



          // ── Button ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 58,
              child: isLast
                  ? ElevatedButton(
                      onPressed: _goToApp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: data.accentColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              data.accentColor.withValues(alpha: 0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('ابدأ رحلتك',
                                style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w900,
                                )),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                    )
                  : ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: data.accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('التالي',
                              style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w900,
                              )),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 32),
        ]),
      ),
    ]);
  }

}

// ═══════════════════════════════════════════════════════════════
//  BACKGROUND IMAGE WIDGET
//  Shows real photo with graceful fallback gradient
// ═══════════════════════════════════════════════════════════════
class _BackgroundImage extends StatelessWidget {
  final String imagePath;
  const _BackgroundImage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A1F1A), Color(0xFFFF6B35)],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PAGE DATA MODEL
// ═══════════════════════════════════════════════════════════════
class _PageData {
  final String imagePath;
  final String tag;
  final String title;
  final String subtitle;
  final Color  accentColor;

  const _PageData({
    required this.imagePath,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });
}
