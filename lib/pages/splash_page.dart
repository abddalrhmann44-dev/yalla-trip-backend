// ═══════════════════════════════════════════════════════════════
//  TALAA — Splash Page
//
//  A typographic splash: a single hero "talaa" word centred on the
//  brand-orange gradient, faded + scaled in, then handed off to the
//  AuthGate.  Replaces the earlier Lottie-based splash because the
//  bundled animation wasn't reliably rendering the wordmark on
//  every device.
//
//  Design ethos:
//    • Single-purpose: brand reveal → root.  No fetches, no spinners.
//    • Pure Flutter text + animation — no asset dependency, so we
//      can't be ambushed by a broken Lottie / missing font fallback.
//    • Status bar styled to match the orange gradient so the system
//      chrome doesn't fight the splash visually.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _maxTimer;
  bool _navigated = false;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
    // Hard cap — guarantees we leave the splash even if something
    // upstream (e.g. Navigator) blocks the scheduled hand-off.
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
            // Brand-orange diagonal gradient — the white wordmark
            // pops against this without competing with it.
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
            child: Center(
              // Animated wordmark — fades + scales in once on entry.
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: const Text(
                    'talaa',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2.5,
                      height: 1,
                      shadows: [
                        Shadow(
                          color: Color(0x33000000),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
