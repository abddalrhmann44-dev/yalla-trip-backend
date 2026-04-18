// ═══════════════════════════════════════════════════════════════
//  TALAA — Splash Screen
//  Lottie building animation → fade into destination
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'host_dashboard_page.dart';

class SplashScreen extends StatefulWidget {
  /// Optional async work to run when animation ends (e.g. role change).
  final Future<void> Function()? onComplete;

  /// Where to go after the animation. Defaults to [HostDashboardPage].
  final Widget? destination;

  const SplashScreen({super.key, this.onComplete, this.destination});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _navigated = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onAnimationLoaded(LottieComposition composition) {
    if (_navigated) return;
    Future.delayed(composition.duration, () async {
      if (!mounted || _navigated) return;
      _navigated = true;

      // Run callback (e.g. save role) before navigating
      if (widget.onComplete != null) {
        await widget.onComplete!();
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              widget.destination ?? const HostDashboardPage(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1B4D5C),
              Color(0xFF0D2B36),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // ── App logo ──────────────────────────────
                Image.asset(
                  'assets/images/splash.png',
                  width: 70,
                  height: 70,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                const Text(
                  'TALAA TRIP',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB8A05A),
                    letterSpacing: 3,
                    fontFamily: 'Outfit',
                  ),
                ),

                const Spacer(flex: 1),

                // ── Lottie animation (constrained) ────────
                SizedBox(
                  width: w * 0.65,
                  height: w * 0.65,
                  child: Lottie.asset(
                    'assets/animations/Free Isometric Building Bundle.json',
                    repeat: false,
                    fit: BoxFit.contain,
                    onLoaded: _onAnimationLoaded,
                  ),
                ),

                const Spacer(flex: 1),

                // ── Status text ───────────────────────────
                const Text(
                  'جاري تجهيز حسابك كمالك عقار...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'لحظات وهتقدر تضيف عقاراتك',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Loading dots ──────────────────────────
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFFB8A05A),
                  ),
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
