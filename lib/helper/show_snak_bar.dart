import 'package:flutter/material.dart';
import '../widgets/constants.dart';

enum SnackBarType { success, error, warning, info }

void showSnackBar(
  BuildContext context,
  String message, {
  SnackBarType type = SnackBarType.info,
  Duration duration = const Duration(seconds: 3),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  // Clear any existing snack bars
  ScaffoldMessenger.of(context).hideCurrentSnackBar();

  final config = _getConfig(type);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(config.icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: config.color,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      action: actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction ?? () {},
            )
          : null,
    ),
  );
}

// ── Convenience helpers ───────────────────────────────────

void showSuccessSnackBar(BuildContext context, String message) =>
    showSnackBar(context, message, type: SnackBarType.success);

void showErrorSnackBar(BuildContext context, String message) =>
    showSnackBar(context, message, type: SnackBarType.error);

void showWarningSnackBar(BuildContext context, String message) =>
    showSnackBar(context, message, type: SnackBarType.warning);

void showInfoSnackBar(BuildContext context, String message) =>
    showSnackBar(context, message, type: SnackBarType.info);

// ── Config ────────────────────────────────────────────────

class _SnackConfig {
  final Color color;
  final IconData icon;
  const _SnackConfig({required this.color, required this.icon});
}

_SnackConfig _getConfig(SnackBarType type) {
  switch (type) {
    case SnackBarType.success:
      return const _SnackConfig(
          color: AppColors.success, icon: Icons.check_circle_outline_rounded);
    case SnackBarType.error:
      return const _SnackConfig(
          color: AppColors.error, icon: Icons.error_outline_rounded);
    case SnackBarType.warning:
      return const _SnackConfig(
          color: AppColors.warning, icon: Icons.warning_amber_rounded);
    case SnackBarType.info:
      return const _SnackConfig(
          color: AppColors.primary, icon: Icons.info_outline_rounded);
  }
}
