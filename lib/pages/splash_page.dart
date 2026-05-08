// ═══════════════════════════════════════════════════════════════
//  TALAA — Splash Page
//
//  Plays the Lottie splash (assets/animations/splash screen.json)
//  on a brand-orange background, then hands off to the AuthGate.
//
//  Design ethos:
//    • Single-purpose: brand reveal → root.  No fetches, no spinners.
//    • Total wall-time capped at ~2.4s so we never block a user from
//      reaching the home screen if the Lottie controller stalls.
//    • Status bar styled to match the orange gradient so the system
//      chrome doesn't fight the splash visually.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../widgets/constants.dart';

/// Minimum time the splash stays on screen even if the Lottie
/// finishes faster — gives the brand reveal room to breathe.
const Duration _kMinDisplay = Duration(milliseconds: 1800);

/// Hard cap so a stalled Lottie controller can't trap the user on
/// the splash forever.
const Duration _kMaxDisplay = Duration(milliseconds: 2600);

class SplashPage extends StatefulWidget {
  /// Route to push once the splash finishes.  Defaults to ``/`` so
  /// the existing ``home: AuthGate()`` is reached via the navigator.
  final String nextRoute;

  const SplashPage({super.key, this.nextRoute = '/'});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Timer? _maxTimer;
  bool _navigated = false;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _ctrl = AnimationController(vsync: this);
    // Hard cap — even if Lottie's status callback never fires we
    // still hand off to the root after this many ms.
    _maxTimer = Timer(_kMaxDisplay, _goNext);
  }

  @override
  void dispose() {
    _maxTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_navigated || !mounted) return;
    // Honour the minimum on-screen time so the brand reveal isn't
    // a flash even on fast hardware.
    final elapsed = DateTime.now().difference(_startedAt!);
    if (elapsed < _kMinDisplay) {
      await Future.delayed(_kMinDisplay - elapsed);
    }
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(widget.nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            // Brand-orange diagonal gradient — the white "Talaa" in
            // the Lottie pops against this without competing with it.
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                AppColors.primaryLight, // #FF8A3D
                AppColors.primary,      // #FF6B35
                AppColors.primaryDark,  // #E85A24
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            child: Stack(children: [
              // ── Lottie ──────────────────────────────────────
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Lottie.asset(
                    'assets/animations/splash screen.json',
                    controller: _ctrl,
                    fit: BoxFit.contain,
                    repeat: false,
                    onLoaded: (composition) {
                      _ctrl
                        ..duration = composition.duration
                        ..forward().whenComplete(_goNext);
                    },
                  ),
                ),
              ),
              // ── Tagline ─────────────────────────────────────
              // Sits below the logo so the moment the Lottie
              // completes its fade-in the user reads the value
              // proposition for free.
              Positioned(
                left: 0,
                right: 0,
                bottom: 48,
                child: Column(children: [
                  Text(
                    'يلا نسافر',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your beach escape, simplified.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
