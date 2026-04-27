// ═══════════════════════════════════════════════════════════════
//  TALAA — Splash Page (Dart-side)
//
//  This is the first Dart widget the user ever sees.  It paints the
//  same brand-orange backdrop as the native splash (configured by
//  ``flutter_native_splash`` in pubspec.yaml) and full-bleeds the
//  Talaa artwork on top, so the cold-start handoff
//
//      [native orange] → [SplashPage] → [home]
//
//  is perceived as one continuous surface — no flash, no layout jump.
//
//  Crucially, this widget DOES NOT navigate.  Pushing routes from
//  the splash means a stray ``Navigator.popUntil((r) => r.isFirst)``
//  somewhere else in the app could send the user back to the splash.
//  Instead, ``onComplete`` is invoked once and the parent widget
//  (``_RootSwitcher`` in main.dart) swaps the entire tree via an
//  ``AnimatedSwitcher`` — no route stack pollution.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../widgets/constants.dart';

/// A short, GPU-friendly cold-start splash.
///
/// Total visible time ≈ **1.5 s** (300 ms fade-in + 900 ms hold +
/// 300 ms fade-out).  The fade-out runs in parallel with the
/// ``AnimatedSwitcher`` cross-fade in ``_RootSwitcher``, so the
/// perceived transition into the auth gate is a single smooth blend.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onComplete});

  /// Fired exactly once when the splash hold expires.  The parent
  /// is responsible for swapping this widget out of the tree —
  /// SplashPage never touches Navigator.
  final VoidCallback onComplete;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  // ── Timing constants (single source of truth) ──────────────
  // Keep these tight: every ms on the splash is engagement loss.
  // Industry rule of thumb is ≤ 1.8 s for branded splashes.
  static const _kFadeIn  = Duration(milliseconds: 300);
  static const _kHold    = Duration(milliseconds: 900);

  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  Timer? _holdTimer;
  bool _imagePrecached = false;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(vsync: this, duration: _kFadeIn);

    // FadeTransition + ScaleTransition both consume the controller's
    // listenable directly (no per-frame builder), so we avoid the
    // ``saveLayer()`` cost of plain ``Opacity`` and the rebuild cost
    // of putting an ``Image.asset`` inside an ``AnimatedBuilder``.
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    _ctrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Pre-decode the artwork on the very first dependency resolve
    // so the first frame already has the bitmap ready in the image
    // cache.  Without this, ``Image.asset`` decodes async and the
    // user can briefly see the orange background alone.
    if (!_imagePrecached) {
      _imagePrecached = true;
      precacheImage(const AssetImage(AppAssets.splash), context).then((_) {
        if (!mounted) return;
        // Now that the bitmap is cached, the very next frame is
        // guaranteed to contain it — safe to release the native
        // splash and start the hold timer.
        FlutterNativeSplash.remove();
        _holdTimer = Timer(_kHold, _handleExit);
      });
    }
  }

  void _handleExit() {
    if (!mounted) return;
    // Hand control back to the parent.  The parent's AnimatedSwitcher
    // will cross-fade SplashPage out and the next page in — we don't
    // need to fade-out manually here, which keeps the timing
    // deterministic regardless of how slow the auth gate's first
    // frame is.
    widget.onComplete();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Cap the decoded bitmap at the physical screen width.  The
    // source artwork is a high-res square (≥1024 px); without
    // ``cacheWidth`` Flutter would allocate the full bitmap in
    // memory regardless of the device's actual resolution.
    final cacheWidth =
        (mq.size.width * mq.devicePixelRatio).round().clamp(512, 2048);

    return ColoredBox(
      // Match the native splash colour exactly — see
      // ``AppColors.primary`` and ``flutter_native_splash.color`` in
      // pubspec.yaml.  Both must stay in sync (#FF6B35).
      color: AppColors.primary,
      child: RepaintBoundary(
        // Isolate the animated subtree so the rest of the frame
        // (status bar, system UI overlays) doesn't get re-rastered
        // every tick of the fade.
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: SizedBox.expand(
              child: Image.asset(
                AppAssets.splash,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                // ``gaplessPlayback`` keeps the previous frame on
                // screen while the next decodes — defence-in-depth
                // even though we precacheImage() above.
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
