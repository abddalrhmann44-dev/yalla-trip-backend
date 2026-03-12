// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Welcome Page  (Clean Minimal White — Airbnb style)
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_page.dart';
import 'register_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [

        // ══════════════════════════════════════════════
        //  🖼️  خلفية WELCOME — لإضافة صورتك:
        //  1. حط الصورة في:
        //       assets/images/welcome_bg.jpg
        //  2. في pubspec.yaml تحت flutter › assets أضف:
        //       - assets/images/welcome_bg.jpg
        //  3. شيل الـ SizedBox اللي جوا الـ Positioned
        //     وحط بدله:
        //       Image.asset(
        //         'assets/images/welcome_bg.jpg',
        //         fit: BoxFit.cover,
        //         width: double.infinity,
        //         height: double.infinity,
        //       ),
        //  4. لو الصورة فاتحة — أضف overlay أبيض:
        //       Positioned.fill(child: Container(
        //         color: Colors.white.withValues(alpha: 0.82),
        //       )),
        // ══════════════════════════════════════════════
        Positioned.fill(child: Container(color: Colors.white)),
        // ── لما تضيف صورة شيل السطر فوق وفك تعليق الكود ──

        FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  const SizedBox(height: 48),

                  // ══════════════════════════════════════
                  //  LOGO — هادي وبسيط
                  // ══════════════════════════════════════
                  _Logo(),

                  const SizedBox(height: 20),

                  // App name
                  const Text(
                    'Yalla Trip',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0D1B2A),
                      letterSpacing: -1.2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Tagline
                  Text(
                    'اكتشف • احجز • استمتع',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D1B2A).withValues(alpha: 0.4),
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ══════════════════════════════════════
                  //  ILLUSTRATION — abstract map dots
                  // ══════════════════════════════════════
                  _MapIllustration(size: size),

                  const Spacer(),

                  // ══════════════════════════════════════
                  //  TAGLINE BLOCK
                  // ══════════════════════════════════════
                  Text(
                    'أجمل الشاليهات والفيلات\nعلى الساحل المصري',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D1B2A).withValues(alpha: 0.85),
                      height: 1.5,
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ══════════════════════════════════════
                  //  BUTTONS
                  // ══════════════════════════════════════

                  // Login
                  _PrimaryBtn(
                    label: 'تسجيل الدخول',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LoginPage())),
                  ),

                  const SizedBox(height: 12),

                  // Register
                  _OutlineBtn(
                    label: 'إنشاء حساب جديد',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RegisterPage())),
                  ),

                  const SizedBox(height: 20),

                  // Guest
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LoginPage())),
                    child: Text(
                      'تصفح كزائر',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D1B2A).withValues(alpha: 0.35),
                        decoration: TextDecoration.underline,
                        decorationColor:
                            const Color(0xFF0D1B2A).withValues(alpha: 0.2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  LOGO WIDGET — هادي وبسيط
// ══════════════════════════════════════════════════════════════
class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flight_takeoff_rounded,
                color: Colors.white, size: 28),
            const SizedBox(height: 2),
            Container(
              width: 24, height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6D00),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  MAP ILLUSTRATION — abstract Egypt coastline dots
// ══════════════════════════════════════════════════════════════
class _MapIllustration extends StatelessWidget {
  final Size size;
  const _MapIllustration({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: size.height * 0.28,
      child: CustomPaint(painter: _MapPainter()),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    // Light background card
    final bgPaint = Paint()
      ..color = const Color(0xFFF5F7FF)
      ..style = PaintingStyle.fill;
    final bgRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s.width, s.height),
        const Radius.circular(28));
    canvas.drawRRect(bgRRect, bgPaint);

    // Grid lines (subtle)
    final gridPaint = Paint()
      ..color = const Color(0xFF1565C0).withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (int i = 1; i < 6; i++) {
      canvas.drawLine(Offset(s.width * i / 6, 0),
          Offset(s.width * i / 6, s.height), gridPaint);
      canvas.drawLine(Offset(0, s.height * i / 5),
          Offset(s.width, s.height * i / 5), gridPaint);
    }

    // Dotted coast path
    final pathPaint = Paint()
      ..color = const Color(0xFF1565C0).withValues(alpha: 0.15)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(s.width * 0.15, s.height * 0.35)
      ..quadraticBezierTo(s.width * 0.3, s.height * 0.25,
          s.width * 0.45, s.height * 0.38)
      ..quadraticBezierTo(s.width * 0.58, s.height * 0.50,
          s.width * 0.65, s.height * 0.45)
      ..quadraticBezierTo(s.width * 0.75, s.height * 0.40,
          s.width * 0.85, s.height * 0.55);
    canvas.drawPath(path, pathPaint);

    // Location pins
    final locations = [
      _Loc(s.width * 0.18, s.height * 0.38, 'عين السخنة',
          const Color(0xFF1565C0), true),
      _Loc(s.width * 0.38, s.height * 0.28, 'الساحل الشمالي',
          const Color(0xFF0288D1), false),
      _Loc(s.width * 0.60, s.height * 0.44, 'الجونة',
          const Color(0xFFFF6D00), true),
      _Loc(s.width * 0.72, s.height * 0.38, 'الغردقة',
          const Color(0xFF1565C0), false),
      _Loc(s.width * 0.84, s.height * 0.52, 'شرم الشيخ',
          const Color(0xFF00838F), true),
    ];

    for (final loc in locations) {
      _drawPin(canvas, loc);
    }
  }

  void _drawPin(Canvas canvas, _Loc loc) {
    // Pulse ring (for featured)
    if (loc.featured) {
      final ringPaint = Paint()
        ..color = loc.color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(loc.x, loc.y), 18, ringPaint);
    }

    // Pin dot
    final dotPaint = Paint()
      ..color = loc.color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(loc.x, loc.y), loc.featured ? 8 : 6, dotPaint);

    // White center
    canvas.drawCircle(Offset(loc.x, loc.y), loc.featured ? 3 : 2,
        Paint()..color = Colors.white);

    // Label
    final tp = TextPainter(
      text: TextSpan(
        text: loc.label,
        style: TextStyle(
          fontSize: loc.featured ? 9.5 : 8.5,
          fontWeight: FontWeight.w700,
          color: loc.color,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas,
        Offset(loc.x - tp.width / 2, loc.y + (loc.featured ? 12 : 10)));
  }

  @override
  bool shouldRepaint(_MapPainter o) => false;
}

class _Loc {
  final double x, y;
  final String label;
  final Color color;
  final bool featured;
  const _Loc(this.x, this.y, this.label, this.color, this.featured);
}

// ══════════════════════════════════════════════════════════════
//  BUTTONS
// ══════════════════════════════════════════════════════════════
class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: const Color(0xFF1565C0).withValues(alpha: 0.30),
          blurRadius: 16, offset: const Offset(0, 6),
        )],
      ),
      child: Center(child: Text(label,
          style: const TextStyle(fontSize: 16,
              fontWeight: FontWeight.w900, color: Colors.white))),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF0D1B2A).withValues(alpha: 0.15), width: 1.5),
      ),
      child: Center(child: Text(label,
          style: const TextStyle(fontSize: 16,
              fontWeight: FontWeight.w800, color: Color(0xFF0D1B2A)))),
    ),
  );
}
