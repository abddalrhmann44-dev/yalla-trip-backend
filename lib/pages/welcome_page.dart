// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Welcome Page  (Premium Dark Design)
// ═══════════════════════════════════════════════════════════════
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {

  late AnimationController _bgCtrl;
  late AnimationController _contentCtrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);

    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))..forward();

    _fade  = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
      body: Stack(fit: StackFit.expand, children: [

        // ── Animated abstract background ───────────────
        AnimatedBuilder(
          animation: _bgCtrl,
          builder: (_, __) => CustomPaint(
            painter: _WelcomeBgPainter(_bgCtrl.value),
            size: size,
          ),
        ),

        // ── Content ────────────────────────────────────
        SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const SizedBox(height: 32),

                  // ── Logo + name ───────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Row(children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.5),
                            blurRadius: 16, offset: const Offset(0, 6),
                          )],
                        ),
                        child: const Icon(Icons.flight_takeoff_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text('Yalla Trip',
                          style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900,
                            color: Colors.white, letterSpacing: -0.5,
                          )),
                    ]),
                  ),

                  const Spacer(flex: 2),

                  // ── Hero text ─────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pill badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6D00).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFFFF6D00).withValues(alpha: 0.4)),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded,
                                  color: Color(0xFFFF6D00), size: 12),
                              SizedBox(width: 5),
                              Text('أفضل وجهات مصر',
                                  style: TextStyle(
                                    color: Color(0xFFFF6D00), fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'رحلتك\nتبدأ من هنا',
                          style: TextStyle(
                            fontSize: 52, fontWeight: FontWeight.w900,
                            color: Colors.white, height: 1.0,
                            letterSpacing: -2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'شاليهات وفيلات على الساحل الشمالي،\nعين السخنة، الجونة وشرم الشيخ',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.6),
                            height: 1.65,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Stats row
                        Row(children: [
                          _stat('٤٠٠+', 'وجهة'),
                          _vDivider(),
                          _stat('٩٨٪', 'رضا'),
                          _vDivider(),
                          _stat('٢٤/٧', 'دعم'),
                        ]),
                      ],
                    ),
                  ),

                  const Spacer(flex: 3),

                  // ── Buttons ───────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(children: [

                      // Login
                      _PremiumButton(
                        label: 'تسجيل الدخول',
                        icon: Icons.arrow_forward_rounded,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                        ),
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const LoginPage())),
                      ),

                      const SizedBox(height: 12),

                      // Register — glass style
                      _GlassButton(
                        label: 'إنشاء حساب جديد',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const RegisterPage())),
                      ),

                      const SizedBox(height: 18),

                      // Guest
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const LoginPage())),
                        child: Text('تصفح كزائر  →',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.35),
                            )),
                      ),

                      const SizedBox(height: 36),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _stat(String val, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(val, style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
      Text(label, style: TextStyle(
          fontSize: 11, color: Colors.white.withValues(alpha: 0.45),
          fontWeight: FontWeight.w600)),
    ],
  );

  Widget _vDivider() => Container(
    width: 1, height: 32,
    margin: const EdgeInsets.symmetric(horizontal: 20),
    color: Colors.white.withValues(alpha: 0.12),
  );
}

// ── Premium gradient button ─────────────────────────────────────
class _PremiumButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _PremiumButton({required this.label, required this.icon,
      required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 58,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: const Color(0xFF1565C0).withValues(alpha: 0.45),
          blurRadius: 20, offset: const Offset(0, 8),
        )],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(width: 8),
        Icon(icon, color: Colors.white, size: 18),
      ]),
    ),
  );
}

// ── Glass button ───────────────────────────────────────────────
class _GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GlassButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Center(child: Text(label, style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
    ),
  );
}

// ── Animated background painter ────────────────────────────────
class _WelcomeBgPainter extends CustomPainter {
  final double t;
  _WelcomeBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size s) {
    // Base
    canvas.drawRect(Offset.zero & s,
        Paint()..color = const Color(0xFF060D1A));

    final p = Paint()..style = PaintingStyle.fill;

    // Blue orb — top right
    p.shader = RadialGradient(colors: [
      const Color(0xFF1565C0).withValues(alpha: 0.55),
      const Color(0xFF1565C0).withValues(alpha: 0),
    ]).createShader(Rect.fromCircle(
      center: Offset(s.width * (0.85 + 0.08 * math.sin(t * math.pi)),
                     s.height * (0.18 + 0.06 * math.cos(t * math.pi))),
      radius: s.width * 0.65,
    ));
    canvas.drawCircle(
      Offset(s.width * (0.85 + 0.08 * math.sin(t * math.pi)),
             s.height * (0.18 + 0.06 * math.cos(t * math.pi))),
      s.width * 0.65, p,
    );

    // Orange orb — bottom left
    p.shader = RadialGradient(colors: [
      const Color(0xFFFF6D00).withValues(alpha: 0.30),
      const Color(0xFFFF6D00).withValues(alpha: 0),
    ]).createShader(Rect.fromCircle(
      center: Offset(s.width * (0.10 + 0.06 * math.cos(t * math.pi)),
                     s.height * (0.82 + 0.05 * math.sin(t * math.pi))),
      radius: s.width * 0.55,
    ));
    canvas.drawCircle(
      Offset(s.width * (0.10 + 0.06 * math.cos(t * math.pi)),
             s.height * (0.82 + 0.05 * math.sin(t * math.pi))),
      s.width * 0.55, p,
    );

    // Teal accent — mid left
    p.shader = RadialGradient(colors: [
      const Color(0xFF00838F).withValues(alpha: 0.20),
      const Color(0xFF00838F).withValues(alpha: 0),
    ]).createShader(Rect.fromCircle(
      center: Offset(s.width * 0.05, s.height * 0.45),
      radius: s.width * 0.4,
    ));
    canvas.drawCircle(
      Offset(s.width * 0.05, s.height * 0.45),
      s.width * 0.4, p,
    );

    // Noise dots grid (subtle texture)
    final dotP = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..style = PaintingStyle.fill;
    for (int row = 0; row < 20; row++) {
      for (int col = 0; col < 10; col++) {
        if ((row + col) % 3 == 0) {
          canvas.drawCircle(
            Offset(col * s.width / 9, row * s.height / 19),
            1.2, dotP,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_WelcomeBgPainter o) => o.t != t;
}
