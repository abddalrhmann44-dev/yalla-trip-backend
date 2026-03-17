// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Welcome Page  (Clean Minimal White — Airbnb style)
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'login_page.dart';
import 'home_page.dart';
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
    // Rebuild page when language changes
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
  void dispose() {
    _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
        Positioned.fill(
          child: Image.asset(
            'assets/images/welcome_bg.jpg',
            fit: BoxFit.cover,
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.55, 1.0],
                colors: [
                  Color(0x33000000),
                  Color(0x55000000),
                  Color(0xCC000000),
                ],
              ),
            ),
          ),
        ),

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

                  // App name
                  const Text(
                    'Yalla Trip',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
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
                      color: Colors.white.withValues(alpha: 0.75),
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 40),

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
                      color: Colors.white,
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
                    onTap: () async {
                      try {
                        await FirebaseAuth.instance.signInAnonymously();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const HomePage()),
                            (_) => false,
                          );
                        }
                      } catch (_) {}
                    },
                    child: Text(
                      'تصفح كزائر',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.6),
                        decoration: TextDecoration.underline,
                        decorationColor:
                            Colors.white.withValues(alpha: 0.3),
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
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Center(child: Text(label,
          style: const TextStyle(fontSize: 16,
              fontWeight: FontWeight.w800, color: Colors.white))),
    ),
  );
}
