// ═══════════════════════════════════════════════════════════════
//  TALAA — Guests Animation Counter (Reusable)
//  Lottie animation that shows 1→10 guests with +/- controls.
//
//  Animation file: assets/animations/Adding Guests Interaction.json
//  Markers inside the Lottie file (from After Effects):
//    Idle  → frame   0, dur  8
//    1     → frame  10, dur 23   (1 guest)
//    2     → frame  60, dur 25   (2 guests)
//    3     → frame 120, dur 27   (3 guests)
//    4     → frame 180, dur 25   (4 guests)
//    5     → frame 240, dur 26   (5 guests)
//    6     → frame 300, dur 26   (6 guests)
//    7     → frame 360, dur 28   (7 guests)
//    8     → frame 420, dur 26   (8 guests)
//    9     → frame 480, dur 24   (9 guests)
//    10    → frame 540, dur 25   (10 guests)
//  Total frames: 600 @ 60 fps → 10 seconds
//
//  Logic:
//    • guestCount 1–10  → play that marker
//    • guestCount > 10  → lock on marker "10" (frame 540)
//    • min = 1, max = property.maxGuests (from backend)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'constants.dart';

const _kOcean = Color(0xFF1565C0);

/// Total frame count of the Lottie file.
const _totalFrames = 600.0;

/// Start frames for each guest marker (1-indexed by guest count).
/// Index 0 = idle (unused for guest mapping).
const _markerStartFrames = <int>[
  0,   // idle   (not used)
  10,  // 1 guest
  60,  // 2 guests
  120, // 3 guests
  180, // 4 guests
  240, // 5 guests
  300, // 6 guests
  360, // 7 guests
  420, // 8 guests
  480, // 9 guests
  540, // 10 guests
];

/// Duration (in frames) for each marker.
const _markerDurations = <int>[
  8,  // idle
  23, // 1
  25, // 2
  27, // 3
  25, // 4
  26, // 5
  26, // 6
  28, // 7
  26, // 8
  24, // 9
  25, // 10
];

class GuestsAnimationCounter extends StatefulWidget {
  /// Current guest count.
  final int guestCount;

  /// Maximum guests allowed (from backend property.maxGuests).
  final int maxGuests;

  /// Called when the user changes the guest count.
  final ValueChanged<int> onChanged;

  const GuestsAnimationCounter({
    super.key,
    required this.guestCount,
    required this.maxGuests,
    required this.onChanged,
  });

  @override
  State<GuestsAnimationCounter> createState() =>
      _GuestsAnimationCounterState();
}

class _GuestsAnimationCounterState extends State<GuestsAnimationCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    // Jump to the initial guest frame without animating.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToGuest(widget.guestCount);
    });
  }

  @override
  void didUpdateWidget(covariant GuestsAnimationCounter old) {
    super.didUpdateWidget(old);
    if (old.guestCount != widget.guestCount) {
      _animateToGuest(widget.guestCount);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Frame mapping ──────────────────────────────────────────
  /// Returns (startProgress, endProgress) for the given guest count.
  (double, double) _markerRange(int guests) {
    // Clamp to 1–10 for the animation; >10 stays on marker 10.
    final clamped = guests.clamp(1, 10);
    final start = _markerStartFrames[clamped];
    final dur = _markerDurations[clamped];
    return (start / _totalFrames, (start + dur) / _totalFrames);
  }

  /// Jump (no transition) to the last frame of the marker.
  void _jumpToGuest(int guests) {
    final (_, end) = _markerRange(guests);
    _ctrl.value = end;
  }

  /// Animate from the current position to the new guest marker.
  void _animateToGuest(int guests) {
    final (start, end) = _markerRange(guests);
    // Play the marker segment once.
    _ctrl.value = start;
    _ctrl.animateTo(end,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut);
  }

  // ── UI ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final canDecrease = widget.guestCount > 1;
    final canIncrease = widget.guestCount < widget.maxGuests;

    return Column(children: [
      // Lottie animation
      SizedBox(
        height: 160,
        child: Lottie.asset(
          'assets/animations/Adding Guests Interaction.json',
          controller: _ctrl,
          fit: BoxFit.contain,
          // Render at lower resolution for low-end devices.
          frameRate: FrameRate.max,
        ),
      ),
      const SizedBox(height: 8),

      // Counter row
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.kBorder),
        ),
        child: Row(children: [
          Icon(Icons.people_rounded, color: _kOcean, size: 22),
          const SizedBox(width: 12),
          Text('ضيوف',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.kText)),
          const Spacer(),

          // (-) button
          _counterBtn(
            icon: Icons.remove_rounded,
            onTap: canDecrease
                ? () {
                    HapticFeedback.lightImpact();
                    widget.onChanged(widget.guestCount - 1);
                  }
                : null,
          ),

          // Count display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('${widget.guestCount}',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: context.kText)),
          ),

          // (+) button
          _counterBtn(
            icon: Icons.add_rounded,
            onTap: canIncrease
                ? () {
                    HapticFeedback.lightImpact();
                    widget.onChanged(widget.guestCount + 1);
                  }
                : null,
          ),
        ]),
      ),

      // Max guests hint
      if (widget.guestCount >= widget.maxGuests)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'الحد الأقصى ${widget.maxGuests} ضيوف لهذا العقار',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700),
          ),
        ),
    ]);
  }

  Widget _counterBtn({
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null
              ? _kOcean.withValues(alpha: 0.08)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: onTap != null
                  ? _kOcean.withValues(alpha: 0.2)
                  : Colors.grey.shade200),
        ),
        child: Icon(icon,
            size: 18,
            color: onTap != null ? _kOcean : Colors.grey.shade400),
      ),
    );
  }
}
