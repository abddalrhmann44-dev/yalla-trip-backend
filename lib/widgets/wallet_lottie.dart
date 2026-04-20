// ═══════════════════════════════════════════════════════════════
//  Wallet Lottie widget (Wave 20+)
//
//  Single source for the wallet animation used across the app:
//    - `WalletLottie.static(...)`  → frozen first frame, ideal for
//      compact tiles (e.g. profile wallet card).
//    - `WalletLottie.animated(...)` → looping animation, shown on
//      the full Wallet page to add life to the header.
//
//  The asset is `assets/animations/Wallet.json` (already registered
//  in pubspec under `assets/animations/`).
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class WalletLottie extends StatefulWidget {
  final double size;
  final bool animate;
  final bool repeat;

  /// Paused first frame – use inside small tiles.
  const WalletLottie.static_({super.key, this.size = 40})
      : animate = false,
        repeat = false;

  /// Playing + looping – use on the Wallet page.
  const WalletLottie.animated({super.key, this.size = 100})
      : animate = true,
        repeat = true;

  @override
  State<WalletLottie> createState() => _WalletLottieState();
}

class _WalletLottieState extends State<WalletLottie>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Lottie.asset(
        'assets/animations/Wallet.json',
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        repeat: widget.repeat,
        animate: widget.animate,
        onLoaded: (composition) {
          // When static, ensure the controller stops at the first
          // frame so we show a clean, well-composed icon pose.
          if (!widget.animate && _controller == null) {
            _controller = AnimationController(
              vsync: this,
              duration: composition.duration,
            )..value = 0.0;
          }
        },
        controller: widget.animate ? null : _controller,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
