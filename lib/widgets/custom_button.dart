import 'package:flutter/material.dart';
import '../widgets/constants.dart';

enum ButtonVariant { primary, secondary, outline, ghost, danger }
enum ButtonSize    { small, medium, large }

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool isLoading;
  final bool fullWidth;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final Widget? customChild;
  final double? borderRadius;

  const CustomButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.variant     = ButtonVariant.primary,
    this.size        = ButtonSize.large,
    this.isLoading   = false,
    this.fullWidth   = true,
    this.prefixIcon,
    this.suffixIcon,
    this.customChild,
    this.borderRadius,
  }) : super(key: key);

  // ── Size config ──────────────────────────────────────────
  double get _height {
    switch (size) {
      case ButtonSize.small:  return 40;
      case ButtonSize.medium: return 48;
      case ButtonSize.large:  return 56;
    }
  }

  double get _fontSize {
    switch (size) {
      case ButtonSize.small:  return 13;
      case ButtonSize.medium: return 14;
      case ButtonSize.large:  return 16;
    }
  }

  double get _iconSize {
    switch (size) {
      case ButtonSize.small:  return 16;
      case ButtonSize.medium: return 18;
      case ButtonSize.large:  return 20;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case ButtonSize.small:  return const EdgeInsets.symmetric(horizontal: 16);
      case ButtonSize.medium: return const EdgeInsets.symmetric(horizontal: 20);
      case ButtonSize.large:  return const EdgeInsets.symmetric(horizontal: 24);
    }
  }

  // ── Variant config ───────────────────────────────────────
  Color get _backgroundColor {
    switch (variant) {
      case ButtonVariant.primary:   return AppColors.primary;
      case ButtonVariant.secondary: return AppColors.accent;
      case ButtonVariant.outline:   return Colors.transparent;
      case ButtonVariant.ghost:     return Colors.transparent;
      case ButtonVariant.danger:    return AppColors.error;
    }
  }

  Color get _foregroundColor {
    switch (variant) {
      case ButtonVariant.primary:   return AppColors.white;
      case ButtonVariant.secondary: return AppColors.primary;
      case ButtonVariant.outline:   return AppColors.primary;
      case ButtonVariant.ghost:     return AppColors.primary;
      case ButtonVariant.danger:    return AppColors.white;
    }
  }

  BorderSide get _borderSide {
    switch (variant) {
      case ButtonVariant.outline:
        return const BorderSide(color: AppColors.border, width: 1.5);
      default:
        return BorderSide.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.lg;

    Widget child = customChild ?? _buildContent();

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: _height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _backgroundColor,
          foregroundColor: _foregroundColor,
          disabledBackgroundColor: _backgroundColor.withOpacity(0.6),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: _padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: _borderSide,
          ),
        ),
        child: isLoading ? _buildLoader() : child,
      ),
    );
  }

  Widget _buildContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (prefixIcon != null) ...[
          Icon(prefixIcon, size: _iconSize, color: _foregroundColor),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: _foregroundColor,
          ),
        ),
        if (suffixIcon != null) ...[
          const SizedBox(width: 8),
          Icon(suffixIcon, size: _iconSize, color: _foregroundColor),
        ],
      ],
    );
  }

  Widget _buildLoader() {
    return SizedBox(
      width: _iconSize + 4,
      height: _iconSize + 4,
      child: CircularProgressIndicator(
        color: _foregroundColor,
        strokeWidth: 2.2,
      ),
    );
  }
}
