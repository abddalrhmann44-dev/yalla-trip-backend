// ═══════════════════════════════════════════════════════════════
//  TALAA — AuthGuard
//  Centralised "require login" gate.  Any tap that needs an
//  authenticated user goes through `AuthGuard.require(context)`,
//  which transparently lets logged-in users through and prompts
//  guests with a friendly bottom-sheet → LoginPage.
// ═══════════════════════════════════════════════════════════════

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/login_page.dart';
import '../widgets/constants.dart';

const Color _kOrange = Color(0xFFFF6D00);

class AuthGuard {
  AuthGuard._();

  /// True when a Firebase user session exists (regardless of role).
  /// Anonymous Firebase users are treated as "not logged in" so they
  /// also get prompted, matching the product copy "سجّل دخولك أولاً".
  static bool get isLoggedIn {
    final u = FirebaseAuth.instance.currentUser;
    return u != null && !u.isAnonymous;
  }

  /// Returns `true` if the user is already logged in.
  ///
  /// If they are a guest, shows a bottom-sheet asking them to log in.
  /// Tapping the primary button pushes [LoginPage] and the future
  /// resolves to `false` so the caller aborts the gated action — the
  /// user can re-tap it after returning logged in.
  ///
  /// [feature] is an optional Arabic verb phrase that gets injected
  /// into the default sentence ("لازم تسجل دخول علشان تقدر …").
  /// Pass [message] to fully override the body text.
  static Future<bool> require(
    BuildContext context, {
    String? feature,
    String? message,
  }) async {
    if (isLoggedIn) return true;

    final body = message ??
        (feature != null
            ? 'لازم تسجل دخول علشان تقدر $feature'
            : 'يرجى تسجيل الدخول للمتابعة');

    final shouldLogin = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LoginPromptSheet(message: body),
    );

    if (shouldLogin == true && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      // After returning from LoginPage, the user *might* now be logged
      // in.  Re-check so callers that await this future can proceed
      // without a second tap when the login was successful and the
      // login page popped (i.e. didn't fully replace the stack).
      if (isLoggedIn) return true;
    }
    return false;
  }

  /// Convenience wrapper for `onTap`/`onPressed` callbacks that fires
  /// [action] only when the user is logged in.  Saves the boilerplate
  /// of writing `() async { if (await AuthGuard.require(ctx)) action(); }`
  /// at every call-site.
  static VoidCallback gate(
    BuildContext context,
    VoidCallback action, {
    String? feature,
  }) {
    return () async {
      if (await AuthGuard.require(context, feature: feature)) {
        action();
      }
    };
  }

  /// Page-level guard.  Call from `initState`/`didChangeDependencies`
  /// of any screen that should not be reachable by a guest (e.g. via
  /// a deep link, a push notification tap, or one of the named routes
  /// in `main.dart`).
  ///
  /// Behaviour for guests:
  /// 1. Pops the current route (so the page is removed from the stack).
  /// 2. Shows the login bottom-sheet → optional push to LoginPage.
  ///
  /// Logged-in users see no UI from this method — it's a no-op.
  static void requireOrPop(BuildContext context, {String? feature}) {
    if (isLoggedIn) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (!context.mounted) return;
      await AuthGuard.require(context, feature: feature);
    });
  }
}

class _LoginPromptSheet extends StatelessWidget {
  final String message;
  const _LoginPromptSheet({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.kSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, MediaQuery.of(context).padding.bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
              color: context.kBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Lock icon in branded orange tint
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _kOrange.withValues(alpha: 0.18),
                  _kOrange.withValues(alpha: 0.08),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline_rounded,
                color: _kOrange, size: 36),
          ),
          const SizedBox(height: 18),
          Text(
            'سجّل دخولك أولاً 🔐',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: context.kText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.55,
              color: context.kSub,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.login_rounded,
                  size: 19, color: Colors.white),
              label: const Text(
                'تسجيل الدخول',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kOrange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'مش دلوقتى',
              style: TextStyle(
                color: context.kSub,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
