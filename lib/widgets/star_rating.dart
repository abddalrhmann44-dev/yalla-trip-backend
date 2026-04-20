// ═══════════════════════════════════════════════════════════════
//  TALAA — Star Rating Widget
//  • Interactive tap-to-rate when [onChanged] is provided.
//  • Read-only display when [onChanged] is null.
//  • Supports half-stars when rendering a fractional value.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _kAmber = Color(0xFFF59E0B);

class StarRating extends StatelessWidget {
  final double value;
  final int max;
  final double size;
  final Color color;
  final ValueChanged<double>? onChanged;

  const StarRating({
    super.key,
    required this.value,
    this.max = 5,
    this.size = 24,
    this.color = _kAmber,
    this.onChanged,
  });

  bool get _interactive => onChanged != null;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final filled = value - i;
        IconData icon;
        if (filled >= 1) {
          icon = Icons.star_rounded;
        } else if (filled >= 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        final star = Icon(icon, size: size, color: color);
        if (!_interactive) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.05),
            child: star,
          );
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged!((i + 1).toDouble());
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.1),
            child: star,
          ),
        );
      }),
    );
  }
}
