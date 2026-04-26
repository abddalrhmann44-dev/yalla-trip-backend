// ═══════════════════════════════════════════════════════════════
//  TALAA — Unified SnackBar Helper
//  Replaces ad-hoc `Colors.red` SnackBars across the app with
//  a consistent, compact, labelled toast that has an icon, a
//  short title and a longer message instead of one big red bar.
//
//  Usage:
//    AppSnack.error(context, code: 'AUTH_REJECTED',
//        message: 'البيانات غير صحيحة');
//    AppSnack.success(context, message: 'تم حفظ التغييرات');
//    AppSnack.warning(context, message: 'الحجز قارب على الانتهاء');
//    AppSnack.info(context, message: 'تم إرسال رمز التحقق');
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _SnackKind { error, success, warning, info }

class AppSnack {
  AppSnack._();

  /// Shows a friendly error toast.  ALWAYS supply a short [code]
  /// (e.g. `'NETWORK'`, `'AUTH_REJECTED'`, `'UPLOAD_FAILED'`) plus
  /// a one-line Arabic [message].  The [code] is shown in a small
  /// chip so the user (and support) can reference the exact failure
  /// without seeing a wall of red.
  static void error(
    BuildContext context, {
    required String message,
    String? code,
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) =>
      _show(
        context,
        kind: _SnackKind.error,
        title: title ?? 'حدث خطأ',
        message: message,
        code: code,
        duration: duration,
      );

  static void success(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) =>
      _show(
        context,
        kind: _SnackKind.success,
        title: title ?? 'تم بنجاح',
        message: message,
        duration: duration,
      );

  static void warning(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) =>
      _show(
        context,
        kind: _SnackKind.warning,
        title: title ?? 'تنبيه',
        message: message,
        duration: duration,
      );

  static void info(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) =>
      _show(
        context,
        kind: _SnackKind.info,
        title: title ?? 'معلومة',
        message: message,
        duration: duration,
      );

  // ── Internal ─────────────────────────────────────────────
  static void _show(
    BuildContext context, {
    required _SnackKind kind,
    required String title,
    required String message,
    String? code,
    required Duration duration,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    // Haptic feedback matching the severity — gentle for info /
    // success, sharp for error.  Subtle but improves the feel.
    switch (kind) {
      case _SnackKind.error:
        HapticFeedback.heavyImpact();
        break;
      case _SnackKind.warning:
        HapticFeedback.mediumImpact();
        break;
      case _SnackKind.success:
      case _SnackKind.info:
        HapticFeedback.lightImpact();
        break;
    }

    final accent = _accentFor(kind);
    final icon = _iconFor(kind);

    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        elevation: 0,
        // The container does its own painting; we want SnackBar to
        // be transparent so we don't get a giant red rectangle.
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        content: _SnackBody(
          accent: accent,
          icon: icon,
          title: title,
          message: message,
          code: code,
          onDismiss: () => messenger.hideCurrentSnackBar(),
        ),
      ),
    );
  }

  static Color _accentFor(_SnackKind k) {
    switch (k) {
      // Tomato — softer than Material red but still unmistakably an error.
      case _SnackKind.error:   return const Color(0xFFE53935);
      case _SnackKind.success: return const Color(0xFF22C55E);
      case _SnackKind.warning: return const Color(0xFFF59E0B);
      // Brand orange — info uses the app accent so it feels native.
      case _SnackKind.info:    return const Color(0xFFFF6B35);
    }
  }

  static IconData _iconFor(_SnackKind k) {
    switch (k) {
      case _SnackKind.error:   return Icons.error_outline_rounded;
      case _SnackKind.success: return Icons.check_circle_rounded;
      case _SnackKind.warning: return Icons.warning_amber_rounded;
      case _SnackKind.info:    return Icons.info_outline_rounded;
    }
  }
}

class _SnackBody extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String title;
  final String message;
  final String? code;
  final VoidCallback onDismiss;

  const _SnackBody({
    required this.accent,
    required this.icon,
    required this.title,
    required this.message,
    required this.code,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accent strip / icon.
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: accent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (code != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              code!,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: accent,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Color(0xFF2A1F1A),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'إغلاق',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(Icons.close_rounded,
                    size: 18, color: Colors.black.withValues(alpha: 0.45)),
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
