// ═══════════════════════════════════════════════════════════════
//  TALAA — FavoriteButton
//  Reactive heart button that listens to FavoritesProvider and
//  performs optimistic toggles with backend sync + haptic feedback.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show favoritesProvider;
import '../utils/auth_guard.dart';

class FavoriteButton extends StatelessWidget {
  final int propertyId;

  /// Size of the heart icon itself (in pixels). The tap target is larger.
  final double size;

  /// Optional background circle — set to null for transparent.
  final Color? background;

  /// Color of the heart when NOT favorited.
  final Color inactiveColor;

  /// Color of the heart when favorited.
  final Color activeColor;

  /// Padding around the icon inside the circle.
  final EdgeInsets padding;

  const FavoriteButton({
    super.key,
    required this.propertyId,
    this.size = 20,
    this.background = Colors.white,
    this.inactiveColor = Colors.grey,
    this.activeColor = Colors.red,
    this.padding = const EdgeInsets.all(7),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: favoritesProvider,
      builder: (_, __) {
        final isFav = favoritesProvider.isFavorite(propertyId);
        return GestureDetector(
          onTap: () => _handleTap(context, isFav),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: padding,
            decoration: background == null
                ? null
                : BoxDecoration(
                    color: background!.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                isFav
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                key: ValueKey(isFav),
                size: size,
                color: isFav ? activeColor : inactiveColor,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleTap(BuildContext context, bool wasFav) async {
    // Guests can't favorite — bounce them through the login prompt
    // before we hit the backend (which would 401 anyway).
    if (!await AuthGuard.require(context, feature: 'تحفظ العقار فى المفضلة')) {
      return;
    }
    if (!context.mounted) return;
    HapticFeedback.selectionClick();
    try {
      await favoritesProvider.toggle(propertyId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasFav ? 'فشل حذف العقار من المفضلة' : 'فشل إضافة العقار للمفضلة',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          backgroundColor: const Color(0xFFEF5350),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
