// ═══════════════════════════════════════════════════════════════
//  TALAA — Login Page  (Airbnb-minimal redesign)
//  Phone-first authentication. Opened on-demand from HomePage.
//  White background, no hero image, no logo — pure typographic UI.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';
import '../utils/app_strings.dart';
import '../main.dart' show appSettings;
import 'home_page.dart';
import 'otp_page.dart';
import 'register_page.dart';

// ── Design tokens ────────────────────────────────────────────
class _T {
  static const primary = Color(0xFFFF6B35); // sunset orange
  static const navy = Color(0xFF0A1F44);
  static const muted = Color(0xFF64748B);
  static const soft = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const error = Color(0xFFDC2626);

  static const ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFF6B35), Color(0xFFFF8A3D)],
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  String _countryCode = '+20';
  String _countryFlag = '🇪🇬';
  String _countryName = 'Egypt';

  final _auth = FirebaseAuth.instance;

  static const _countries = [
    {'flag': '🇪🇬', 'name': 'Egypt', 'code': '+20'},
    {'flag': '🇸🇦', 'name': 'Saudi Arabia', 'code': '+966'},
    {'flag': '🇦🇪', 'name': 'UAE', 'code': '+971'},
    {'flag': '🇰🇼', 'name': 'Kuwait', 'code': '+965'},
    {'flag': '🇶🇦', 'name': 'Qatar', 'code': '+974'},
    {'flag': '🇯🇴', 'name': 'Jordan', 'code': '+962'},
    {'flag': '🇱🇧', 'name': 'Lebanon', 'code': '+961'},
    {'flag': '🇬🇧', 'name': 'UK', 'code': '+44'},
    {'flag': '🇺🇸', 'name': 'USA', 'code': '+1'},
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  //  ACTIONS
  // ══════════════════════════════════════════════════════════════
  Future<void> _continue() async {
    final raw = _phoneCtrl.text.trim();
    if (raw.length < 6) {
      _showError('أدخل رقم هاتف صحيح');
      return;
    }
    setState(() => _loading = true);
    final local = raw.startsWith('0') ? raw.substring(1) : raw;
    final full = '$_countryCode$local';

    debugPrint('[OTP] verifyPhoneNumber → $full');
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: full,
        timeout: const Duration(seconds: 60),
        codeSent: (verId, token) {
          debugPrint('[OTP] codeSent — verificationId=$verId');
          if (!mounted) return;
          setState(() => _loading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpPage(
                phoneNumber: full,
                verificationId: verId,
                resendToken: token,
              ),
            ),
          );
        },
        verificationCompleted: (cred) async {
          debugPrint('[OTP] verificationCompleted (auto-verified)');
          final result = await _auth.signInWithCredential(cred);
          await _afterAuth(result);
        },
        verificationFailed: (e) {
          debugPrint('[OTP] verificationFailed: '
              'code=${e.code}  message=${e.message}');
          if (!mounted) return;
          setState(() => _loading = false);
          _showError(_phoneAuthErrorMsg(e));
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e, st) {
      debugPrint('[OTP] verifyPhoneNumber threw: $e\n$st');
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(kDebugMode ? 'خطأ: $e' : 'حدث خطأ، حاول مرة أخرى');
    }
  }

  /// Human-friendly Arabic message for every Firebase phone-auth error
  /// code we expect to see. In debug we append the raw code so you can
  /// copy it from the SnackBar straight into search / bug reports.
  String _phoneAuthErrorMsg(FirebaseAuthException e) {
    // Firebase sometimes returns `unknown` / `internal-error` with the real
    // reason buried in the message. Surface known Android-specific cases.
    final rawMsg = e.message ?? '';
    if (rawMsg.contains('BILLING_NOT_ENABLED')) {
      return 'Firebase يطلب تفعيل Blaze plan لإرسال OTP.\n'
          'للتجربة: Firebase Console → Authentication → '
          'Phone → Phone numbers for testing';
    }
    if (rawMsg.contains('PLAY_INTEGRITY')) {
      return 'فشل التحقق من Play Integrity — جرّب على جهاز حقيقي أو '
          'أضف SHA-256 في Firebase';
    }

    String base;
    switch (e.code) {
      case 'invalid-phone-number':
        base = 'رقم الهاتف غير صحيح';
        break;
      case 'too-many-requests':
      case 'quota-exceeded':
        base = 'تم تجاوز عدد الرسائل المسموح بها اليوم، جرّب بكرة';
        break;
      case 'billing-not-enabled':
        base = 'Firebase يطلب تفعيل Blaze plan لإرسال OTP. '
            'للتجربة استخدم رقم اختبار من Firebase Console';
        break;
      case 'app-not-authorized':
      case 'missing-client-identifier':
        base = 'التطبيق غير مصرح له — تأكد من SHA-1/SHA-256 في Firebase';
        break;
      case 'captcha-check-failed':
      case 'web-context-cancelled':
      case 'web-context-already-presented':
        base = 'فشل التحقق من reCAPTCHA، حاول مرة أخرى';
        break;
      case 'network-request-failed':
        base = 'لا يوجد اتصال بالإنترنت';
        break;
      case 'operation-not-allowed':
        base = 'تسجيل الدخول بالهاتف غير مفعّل في Firebase Console';
        break;
      default:
        base = 'حدث خطأ، حاول مرة أخرى';
    }
    if (kDebugMode) {
      return '$base\n[${e.code}] ${e.message ?? ''}';
    }
    return base;
  }

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

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('اختر الدولة',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _T.navy)),
          ),
          Expanded(
              child: ListView.builder(
            itemCount: _countries.length,
            itemBuilder: (ctx, i) {
              final c = _countries[i];
              final sel = c['code'] == _countryCode;
              return ListTile(
                leading: Text(c['flag']!, style: const TextStyle(fontSize: 24)),
                title: Text('${c['name']} (${c['code']})',
                    style: TextStyle(
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                        color: sel ? _T.primary : _T.navy)),
                trailing: sel
                    ? const Icon(Icons.check_circle_rounded,
                        color: _T.primary)
                    : null,
                onTap: () {
                  setState(() {
                    _countryCode = c['code']!;
                    _countryFlag = c['flag']!;
                    _countryName = c['name']!;
                  });
                  Navigator.pop(context);
                },
              );
            },
          )),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isAr = appSettings.arabic;
    return Scaffold(
      backgroundColor: Colors.white,
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
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 28),

                  // Phone input with country selector
                  _PhoneInput(
                    flag: _countryFlag,
                    code: _countryCode,
                    name: _countryName,
                    ctrl: _phoneCtrl,
                    onPickCountry: _showCountryPicker,
                  ),

                  const SizedBox(height: 16),

                  // Primary Continue button (orange gradient)
                  _PrimaryBtn(
                    label: S.continueBtn,
                    loading: _loading,
                    onTap: _continue,
                  ),

                  const SizedBox(height: 12),

                  Text(
                    S.smsHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _T.muted,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 28),

                  _OrDivider(label: S.orWith),

                  const SizedBox(height: 20),

                  // Social row — small square buttons (like Airbnb)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialSquare(
                        onTap: _loading ? null : _googleSignIn,
                        child: const _GoogleG(size: 22),
                      ),
                    ],
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

/// Phone number input with attached country picker (Airbnb-style rounded
/// rectangle split into two cells).
class _PhoneInput extends StatefulWidget {
  final String flag;
  final String code;
  final String name;
  final TextEditingController ctrl;
  final VoidCallback onPickCountry;
  const _PhoneInput({
    required this.flag,
    required this.code,
    required this.name,
    required this.ctrl,
    required this.onPickCountry,
  });

  @override
  State<_PhoneInput> createState() => _PhoneInputState();
}

class _PhoneInputState extends State<_PhoneInput> {
  final _focus = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _isFocused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isFocused ? _T.navy : _T.border,
            width: _isFocused ? 1.6 : 1,
          ),
        ),
        child: Row(children: [
          // Country cell
          InkWell(
            onTap: widget.onPickCountry,
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12)),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(widget.flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(widget.code,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _T.navy)),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: _T.muted),
              ]),
            ),
          ),
          // Vertical separator
          Container(width: 1, height: 30, color: _T.border),
          // Number cell
          Expanded(
            child: TextField(
              controller: widget.ctrl,
              focusNode: _focus,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              cursorColor: _T.primary,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _T.navy),
              decoration: const InputDecoration(
                hintText: 'رقم الهاتف',
                hintStyle: TextStyle(
                    color: _T.soft,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              ),
            ),
          ),
        ]),
      );
}

/// Primary full-width button with orange gradient & soft shadow.
class _PrimaryBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _PrimaryBtn(
      {required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 56,
          decoration: BoxDecoration(
            gradient: loading ? null : _T.ctaGradient,
            color: loading ? _T.primary.withValues(alpha: 0.6) : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: loading
                ? []
                : [
                    BoxShadow(
                      color: _T.primary.withValues(alpha: 0.32),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3),
                  ),
          ),
        ),
      );
}

/// Horizontal line divider with a centred "OR" label.
class _OrDivider extends StatelessWidget {
  final String label;
  const _OrDivider({required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(child: Divider(color: _T.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: _T.soft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
        ),
        const Expanded(child: Divider(color: _T.border, thickness: 1)),
      ]);
}

/// Small square social button (Google, Apple style).
class _SocialSquare extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _SocialSquare({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: onTap == null ? 0.5 : 1,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _T.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: _T.navy.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: child,
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
