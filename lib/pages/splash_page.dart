// ═══════════════════════════════════════════════════════════════
//  TALAA — Splash Page (Dart-side)
//
//  Shown the moment Flutter takes over from the native launch
//  screen (configured via ``flutter_native_splash`` in pubspec.yaml).
//  Both surfaces use the same ``assets/images/splash.png`` artwork
//  on the same brand-orange background, so the hand-off is visually
//  seamless — there's no white flash or layout jump between the
//  native splash and this widget.
//
//  After ~2.4s (a short hold + a graceful fade) we ``pushReplacement``
//  to the existing ``_AuthGate`` (in ``main.dart``), which decides
//  between Onboarding / Home / etc. based on auth state.  Splash
//  itself never appears in the navigator stack after that — back-press
//  cannot return to it.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/constants.dart';
import '../main.dart' show AuthGate;

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  // Single controller drives both the fade-in (start of splash) and
  // the fade-out (just before we hand off to the auth gate).  Using
  // one controller keeps the timing trivial and avoids the
  // multi-controller synchronisation bugs we hit on the previous
  // splash implementation.
  late final AnimationController _fade;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  static const _kBrand = Color(0xFFFF6B35);
  static const _kHoldMs = 1800; // total time on splash before fade-out
  static const _kFadeMs = 600;  // duration of the cross-fade out

  @override
  void initState() {
    super.initState();
    // Match the native splash background so the cold-start handoff
    // doesn't flicker — even if the user is on a slow device and the
    // first Flutter frame paints before the artwork has decoded.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: _kBrand,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacity = CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.96, end: 1.0)
        .animate(CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic));
    _fade.forward();

    // Hold the splash for a beat, then fade-out + replace.  We schedule
    // the navigation off ``Future.delayed`` (not a Timer) because the
    // navigator API needs an active build context to push routes.
    Future.delayed(const Duration(milliseconds: _kHoldMs), _exit);
  }

  Future<void> _exit() async {
    if (!mounted) return;
    // Reverse the controller to fade *out* the artwork, then swap to
    // the auth gate.  ``await`` so the push lines up with the end of
    // the animation — the user perceives a single smooth transition.
    await _fade.reverse(from: 1.0);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: _kFadeMs),
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Full-bleed brand-orange background + centred artwork.  We use
    // ``BoxFit.contain`` (not cover) so the entire image is visible
    // on every aspect ratio — the splash artwork is composed for the
    // centre of the canvas, and cropping the edges on tall phones
    // would clip the logo.
    return Scaffold(
      backgroundColor: _kBrand,
      body: AnimatedBuilder(
        animation: _fade,
        builder: (_, __) => Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Center(
              child: Image.asset(
                AppAssets.splash,
                fit: BoxFit.contain,
                // ``gaplessPlayback`` keeps the previous frame on
                // screen while the next decodes — avoids a 1-frame
                // black flash on Android during fast hand-off.
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
