// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Onboarding Page
//  آخر خطوة: اختيار الـ role → لو مالك يروح owner_add_property
//  مع صفحة إضافة العقار مع كل التفاصيل والصور
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'home_page.dart';
import 'owner_add_property_page.dart';
import '../services/user_role_service.dart';

enum UserType { none, owner, guest }

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _page = 0;
  UserType _userType = UserType.none;
  bool _saving = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  static const _pages = [
    _PageData(
      imagePath: 'assets/images/onboarding/onboard_1.jpg',
      tag: 'اكتشف',
      title: 'أهلاً بيك في\nYalla Trip',
      subtitle: 'اكتشف أجمل المنتجعات والشاليهات\nعلى الساحل المصري',
      accentColor: Color(0xFF1565C0),
    ),
    _PageData(
      imagePath: 'assets/images/onboarding/onboard_2.jpg',
      tag: 'احجز',
      title: 'ساحل، جونة،\nشرم وأكتر',
      subtitle: 'أكثر من ٤٠٠ وجهة بأسعار تنافسية\nوعروض يومية حصرية',
      accentColor: Color(0xFF0288D1),
    ),
    _PageData(
      imagePath: 'assets/images/onboarding/onboard_3.jpg',
      tag: 'ابدأ',
      title: 'إنت مين؟',
      subtitle: 'اختر نوع حسابك عشان\ننظم لك التجربة المناسبة',
      accentColor: Color(0xFF1565C0),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
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
    if (_userType == UserType.none || _saving) return;
    setState(() => _saving = true);

    final role = _userType == UserType.owner ? UserRole.owner : UserRole.guest;
    await UserRoleService.instance.saveRole(role);

    if (!mounted) return;

    if (_userType == UserType.owner) {
      // المالك → صفحة إضافة العقار
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OwnerAddPropertyPage()),
        (_) => false,
      );
    } else {
      // الزائر → الصفحة الرئيسية
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    }
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
    final data = _pages[index];
    final isLast = index == _pages.length - 1;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        _BackgroundImage(imagePath: data.imagePath),

        // Gradient overlay
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x00000000),
                Color(0x44000000),
                Color(0xBB000000),
                Color(0xF2000000),
              ],
              stops: [0.0, 0.35, 0.65, 1.0],
            ),
          ),
        ),

        // Content
        SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // Tag pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: data.accentColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        data.tag,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!isLast)
                      GestureDetector(
                        onTap: _skipToLast,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            'تخطي',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const Spacer(),

              // Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
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

              // Title + subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.15,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data.subtitle,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.75),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Role selector (last page)
              if (isLast) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _roleCard(
                        type: UserType.guest,
                        icon: Icons.beach_access_rounded,
                        title: 'مسافر / زائر',
                        sub: 'ابحث واحجز أفضل الشاليهات والمنتجعات',
                        color: data.accentColor,
                      ),
                      const SizedBox(height: 12),
                      _roleCard(
                        type: UserType.owner,
                        icon: Icons.villa_rounded,
                        title: 'مالك عقار',
                        sub: 'أضف شاليهك أو فيلتك وابدأ التأجير',
                        color: const Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: isLast
                      ? AnimatedOpacity(
                          opacity: _userType != UserType.none ? 1.0 : 0.45,
                          duration: const Duration(milliseconds: 200),
                          child: ElevatedButton(
                            onPressed: (_userType != UserType.none && !_saving)
                                ? _goToApp
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: data.accentColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: data.accentColor
                                  .withValues(alpha: 0.5),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _userType == UserType.owner
                                            ? 'ابدأ وأضف عقارك'
                                            : 'ابدأ رحلتك',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: data.accentColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'التالي',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roleCard({
    required UserType type,
    required IconData icon,
    required String title,
    required String sub,
    required Color color,
  }) {
    final sel = _userType == type;
    return GestureDetector(
      onTap: () => setState(() => _userType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: sel
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? color : Colors.white.withValues(alpha: 0.2),
            width: sel ? 2 : 1.5,
          ),
          boxShadow: sel
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: sel
                    ? color.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 26,
                color: sel ? color : Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: sel ? color : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sel ? color : Colors.transparent,
                border: Border.all(
                  color: sel ? color : Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: sel
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Background Image ───────────────────────────────────────────
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
            colors: [Color(0xFF0D1B2A), Color(0xFF1565C0)],
          ),
        ),
      ),
    );
  }
}

// ── Page Data ──────────────────────────────────────────────────
class _PageData {
  final String imagePath, tag, title, subtitle;
  final Color accentColor;
  const _PageData({
    required this.imagePath,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });
}
