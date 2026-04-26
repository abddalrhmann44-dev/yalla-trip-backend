// ═══════════════════════════════════════════════════════════════
//  TALAA — VerifiedBadge
//  Small blue check-mark badge shown next to verified users /
//  hosts throughout the app.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// Brand orange — verified badge sits on user names everywhere, so it
// must match the app accent. The old _kBrand was navy blue.
const _kBrand = Color(0xFFFF6B35);

/// A compact icon badge — use inline next to a user name.
class VerifiedBadge extends StatelessWidget {
  final double size;
  final Color color;
  final String? tooltip;

  const VerifiedBadge({
    super.key,
    this.size = 18,
    this.color = _kBrand,
    this.tooltip = 'حساب موثّق',
  });

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.verified_rounded, color: color, size: size);
    if (tooltip == null || tooltip!.isEmpty) return icon;
    return Tooltip(message: tooltip!, child: icon);
  }
}

/// A richer chip form — icon + label. Use in profile headers
/// or in the host card on property details.
class VerifiedChip extends StatelessWidget {
  final String label;
  final double fontSize;
  final EdgeInsets padding;

  const VerifiedChip({
    super.key,
    this.label = 'موثّق',
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _kBrand.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBrand.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.verified_rounded, color: _kBrand, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: _kBrand,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ]),
    );
  }
}
