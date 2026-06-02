// ═══════════════════════════════════════════════════════════════
//  TALAA — Login Page  (Airbnb-minimal redesign)
//  Wave 31 — Google-only authentication. Opened on-demand from
//  HomePage.  White background, no hero image, no logo — pure
//  typographic UI.
//
//  History: prior to Wave 31 this page also hosted phone-number
//  entry + WhatsApp / Firebase OTP fallbacks.  We removed that path
//  because (a) Egyptian SMS deliverability was unreliable through
//  Firebase Phone Auth and (b) Paymob KYC already verifies phone at
//  the host onboarding step, so the login-side OTP was redundant.
//  The OtpPage and PhoneVerificationPage widgets remain in the repo
//  for owner-side phone verification (still optional from profile).
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';
import '../utils/app_strings.dart';
import '../widgets/constants.dart';
import '../main.dart' show appSettings;
import 'home_page.dart';
import 'register_page.dart';

// ── Design tokens ────────────────────────────────────────────
class _T {
  static const primary = Color(0xFFFF6B35); // sunset orange
  static const navy = Color(0xFF0A1F44);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const error = Color(0xFFDC2626);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;

  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  // ══════════════════════════════════════════════════════════════
  //  ACTIONS
  // ══════════════════════════════════════════════════════════════
  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      final user = await googleSignIn.signIn();
      if (user == null) {
        setState(() => _loading = false);
        return;
      }
      final ga = await user.authentication;
      debugPrint('[GoogleSignIn] hasIdToken=${ga.idToken != null} '
          'hasAccessToken=${ga.accessToken != null} email=${user.email}');
      final cred = GoogleAuthProvider.credential(
          accessToken: ga.accessToken, idToken: ga.idToken);
      final result = await _auth.signInWithCredential(cred);
      await _afterAuth(result);
    } catch (e, st) {
      debugPrint('[GoogleSignIn] FAILED: $e\n$st');
      if (!mounted) return;
      _showError(kDebugMode
          ? 'Google: $e'
          : 'حدث خطأ في تسجيل الدخول بـ Google');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Unified post-auth handling for Google / auto-verify:
  /// sync backend JWT then route based on whether this is a new user.
  Future<void> _afterAuth(UserCredential result) async {
    final fbUser = result.user;
    if (fbUser != null) {
      final idToken = await fbUser.getIdToken();
      if (idToken != null) {
        await AuthService.exchangeFirebaseToken(idToken);
      }
    }
    if (!mounted) return;
    final isNew = result.additionalUserInfo?.isNewUser ?? false;
    if (isNew) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RegisterPage()),
        (_) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    }
  }

  Future<void> _toggleLang() async {
    await appSettings.setLanguage(!appSettings.arabic);
    if (mounted) setState(() {});
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, height: 1.4),
              ),
            ),
          ],
        ),
        backgroundColor: _T.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isAr = appSettings.arabic;
    return Scaffold(
      backgroundColor: context.kSand,
      body: SafeArea(
        child: Column(children: [
          // ── Top bar: language chip + close ──────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              _TopBtn(
                icon: Icons.language_rounded,
                label: isAr ? 'AR' : 'EN',
                onTap: _toggleLang,
              ),
              const Spacer(),
              _IconBtn(
                icon: Icons.close_rounded,
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomePage()),
                      (_) => false,
                    );
                  }
                },
              ),
            ]),
          ),

          // ── Form body ───────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  // Title block (centered, Airbnb-like)
                  Text(
                    S.loginTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: _T.navy,
                      height: 1.25,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    S.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _T.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Primary CTA — Continue with Google.
                  // Branded white card per Google's identity
                  // guidelines (multi-coloured G + neutral chrome).
                  _GooglePrimaryBtn(
                    label: S.continueWithGoogle,
                    loading: _loading,
                    onTap: _googleSignIn,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    S.loginTermsHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _T.muted,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  COMPONENTS
// ══════════════════════════════════════════════════════════════

/// Subtle pill button shown in the top bar (language toggle).
class _TopBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _TopBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _T.border, width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: _T.navy),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _T.navy,
                    letterSpacing: 0.5)),
          ]),
        ),
      );
}

/// Circular icon button used for the close ("×") control.
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: _T.navy),
        ),
      );
}

/// Primary CTA — full-width white button with the Google G icon
/// and "Continue with Google" label.  Follows Google's brand
/// guidelines (white surface, neutral border, multi-coloured G).
class _GooglePrimaryBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _GooglePrimaryBtn({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _T.border, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: _T.navy.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: _T.primary, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _GoogleG(size: 22),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _T.navy,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );
}

/// Minimal multi-coloured Google 'G' — no dependency on images.
class _GoogleG extends StatelessWidget {
  final double size;
  const _GoogleG({required this.size});

  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          colors: [
            Color(0xFF4285F4), // blue
            Color(0xFFEA4335), // red
            Color(0xFFFBBC05), // yellow
            Color(0xFF34A853), // green
          ],
          stops: [0.0, 0.4, 0.7, 1.0],
        ).createShader(r),
        child: Text(
          'G',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1,
          ),
        ),
      );
}
