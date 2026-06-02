// ═══════════════════════════════════════════════════════════════
//  TALAA — Login Page  (Airbnb-minimal redesign)
//  Wave 32 — Phone+password primary auth + Google fallback.
//  Two modes: login (phone+pass) and register (name/phone/pass×2/terms).
//  No OTP required — Firebase email-as-phone auth pattern.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';
import '../utils/app_strings.dart';
import '../widgets/constants.dart';
import '../main.dart' show appSettings, userProvider;
import 'home_page.dart';
import 'register_page.dart';
import 'terms_page.dart';
import 'terms_acceptance_page.dart';

// ── Design tokens ────────────────────────────────────────────
class _T {
  static const primary = Color(0xFFFF6B35);
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

enum _Mode { login, register }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  _Mode _mode = _Mode.login;
  bool _loading = false;

  final _auth = FirebaseAuth.instance;

  // ── Login form state ─────────────────────────────────────
  final _loginFormKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;

  // ── Register form state ──────────────────────────────────
  final _registerFormKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regPass2Ctrl = TextEditingController();
  bool _showRegPass = false;
  bool _showRegPass2 = false;
  bool _agreed = false;

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
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regPassCtrl.dispose();
    _regPass2Ctrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  //  ACTIONS
  // ══════════════════════════════════════════════════════════════

  // Convert phone digits to a stable fake-email so we can use
  // Firebase email/password auth without OTP.
  String _toFakeEmail(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return '$digits@talaa.app';
  }

  Future<void> _phoneSignIn() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: _toFakeEmail(_phoneCtrl.text.trim()),
        password: _passCtrl.text,
      );
      await _afterAuth(result);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(_authErrorMsg(e.code));
    } catch (e) {
      if (!mounted) return;
      _showError(kDebugMode ? '$e' : _authErrorMsg('unknown'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _phoneRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    if (!_agreed) {
      _showError(appSettings.arabic
          ? 'لازم توافق على الشروط أولاً'
          : 'You must accept the Terms first');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: _toFakeEmail(_regPhoneCtrl.text.trim()),
        password: _regPassCtrl.text,
      );
      final name = _nameCtrl.text.trim();
      await result.user?.updateDisplayName(name);

      // Exchange Firebase token for backend JWT
      final idToken = await result.user?.getIdToken();
      if (idToken != null) await AuthService.exchangeFirebaseToken(idToken);

      // Mark terms accepted
      await TermsAcceptancePage.markAccepted();

      // Sync profile to backend (best-effort)
      try {
        await userProvider.updateProfile({
          'name': name,
          'phone': _regPhoneCtrl.text.trim(),
        });
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(_authErrorMsg(e.code));
    } catch (e) {
      if (!mounted) return;
      _showError(kDebugMode ? '$e' : _authErrorMsg('unknown'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  Future<void> _afterAuth(UserCredential result) async {
    final fbUser = result.user;
    if (fbUser != null) {
      final idToken = await fbUser.getIdToken();
      if (idToken != null) await AuthService.exchangeFirebaseToken(idToken);
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

  String _authErrorMsg(String code) {
    final ar = appSettings.arabic;
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential':
        return ar
            ? 'الرقم أو كلمة المرور غلط — حاول تاني'
            : 'Incorrect phone or password';
      case 'wrong-password':
        return ar ? 'كلمة المرور غلط، حاول تاني' : 'Wrong password, try again';
      case 'invalid-email':
        return ar ? 'رقم الهاتف غير صحيح' : 'Invalid phone number';
      case 'user-disabled':
        return ar ? 'الحساب موقف مؤقتاً' : 'Account is disabled';
      case 'email-already-in-use':
        return ar
            ? 'الرقم ده مسجل بالفعل — سجّل دخولك من فوق'
            : 'Phone already registered — sign in instead';
      case 'weak-password':
        return ar
            ? 'كلمة المرور ضعيفة (6 أحرف على الأقل)'
            : 'Password too short (min 6 chars)';
      case 'too-many-requests':
        return ar
            ? 'كتير أوي — استنى شوية وحاول تاني'
            : 'Too many attempts — wait and try again';
      case 'network-request-failed':
        return ar ? 'مفيش إنترنت — تأكد من الاتصال' : 'No internet connection';
      default:
        return ar ? 'حدث خطأ، حاول تاني' : 'Something went wrong, try again';
    }
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
              child: Text(msg,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, height: 1.4)),
            ),
          ],
        ),
        backgroundColor: _T.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: _mode == _Mode.login
                    ? _buildLoginForm(isAr)
                    : _buildRegisterForm(isAr),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Login form ──────────────────────────────────────────
  Widget _buildLoginForm(bool isAr) {
    return Form(
      key: _loginFormKey,
      child: Column(
        key: const ValueKey('login'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
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
                fontSize: 14, color: _T.muted, height: 1.4),
          ),
          const SizedBox(height: 32),

          // ── Phone ────────────────────────────────────
          _Label(isAr ? 'رقم الهاتف' : 'Phone Number'),
          const SizedBox(height: 8),
          _Field(
            ctrl: _phoneCtrl,
            hint: isAr ? 'مثال: 01012345678' : 'e.g. 01012345678',
            keyType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return isAr ? 'أدخل رقم الهاتف' : 'Enter phone number';
              }
              if (v.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
                return isAr
                    ? 'رقم هاتف غير صحيح'
                    : 'Invalid phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // ── Password ─────────────────────────────────
          _Label(isAr ? 'كلمة المرور' : 'Password'),
          const SizedBox(height: 8),
          _Field(
            ctrl: _passCtrl,
            hint: '••••••••',
            obscure: !_showPass,
            suffix: GestureDetector(
              onTap: () => setState(() => _showPass = !_showPass),
              child: Icon(
                _showPass
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
                color: _T.soft,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return isAr ? 'أدخل كلمة المرور' : 'Enter password';
              }
              if (v.length < 6) {
                return isAr
                    ? 'كلمة المرور (6 أحرف على الأقل)'
                    : 'Min 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // ── Sign in button ────────────────────────────
          _PrimaryBtn(
            label: isAr ? 'تسجيل الدخول' : 'Sign In',
            loading: _loading,
            onTap: _phoneSignIn,
          ),

          const SizedBox(height: 20),
          const _OrDivider(),
          const SizedBox(height: 20),

          // ── Google ────────────────────────────────────
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
                fontSize: 12, color: _T.muted, height: 1.5),
          ),
          const SizedBox(height: 24),

          // ── Switch to register ────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isAr ? 'مش عندك حساب؟ ' : "Don't have an account? ",
                style: const TextStyle(fontSize: 14, color: _T.muted),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _mode = _Mode.register;
                  // Pre-fill phone if already typed
                  if (_regPhoneCtrl.text.isEmpty &&
                      _phoneCtrl.text.isNotEmpty) {
                    _regPhoneCtrl.text = _phoneCtrl.text;
                  }
                }),
                child: Text(
                  isAr ? 'سجّل لأول مرة' : 'Register now',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _T.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: _T.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Register form ───────────────────────────────────────
  Widget _buildRegisterForm(bool isAr) {
    return Form(
      key: _registerFormKey,
      child: Column(
        key: const ValueKey('register'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            isAr ? 'إنشاء حساب جديد' : 'Create Account',
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
            isAr ? 'بيانات بسيطة وتبدأ على طول' : "Quick details and you're in",
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, color: _T.muted, height: 1.4),
          ),
          const SizedBox(height: 32),

          // ── Name ─────────────────────────────────────
          _Label(isAr ? 'الاسم الكامل' : 'Full Name'),
          const SizedBox(height: 8),
          _Field(
            ctrl: _nameCtrl,
            hint: isAr ? 'مثال: أحمد محمد' : 'e.g. Ahmed Mohamed',
            keyType: TextInputType.name,
            validator: (v) => (v == null || v.trim().length < 3)
                ? (isAr
                    ? 'أدخل اسمك الكامل (3 أحرف على الأقل)'
                    : 'Full name (3+ chars)')
                : null,
          ),
          const SizedBox(height: 14),

          // ── Phone ─────────────────────────────────────
          _Label(isAr ? 'رقم الهاتف' : 'Phone Number'),
          const SizedBox(height: 8),
          _Field(
            ctrl: _regPhoneCtrl,
            hint: isAr ? 'مثال: 01012345678' : 'e.g. 01012345678',
            keyType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return isAr ? 'أدخل رقم الهاتف' : 'Enter phone number';
              }
              if (v.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
                return isAr
                    ? 'رقم هاتف غير صحيح'
                    : 'Invalid phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // ── Password ──────────────────────────────────
          _Label(isAr ? 'كلمة المرور' : 'Password'),
          const SizedBox(height: 8),
          _Field(
            ctrl: _regPassCtrl,
            hint: '••••••••',
            obscure: !_showRegPass,
            suffix: GestureDetector(
              onTap: () => setState(() => _showRegPass = !_showRegPass),
              child: Icon(
                _showRegPass
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
                color: _T.soft,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return isAr ? 'أدخل كلمة المرور' : 'Enter password';
              }
              if (v.length < 6) {
                return isAr
                    ? 'كلمة المرور (6 أحرف على الأقل)'
                    : 'Min 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // ── Confirm password ──────────────────────────
          _Label(isAr ? 'تأكيد كلمة المرور' : 'Confirm Password'),
          const SizedBox(height: 8),
          _Field(
            ctrl: _regPass2Ctrl,
            hint: '••••••••',
            obscure: !_showRegPass2,
            suffix: GestureDetector(
              onTap: () => setState(() => _showRegPass2 = !_showRegPass2),
              child: Icon(
                _showRegPass2
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
                color: _T.soft,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return isAr ? 'أكد كلمة المرور' : 'Confirm your password';
              }
              if (v != _regPassCtrl.text) {
                return isAr
                    ? 'كلمتا المرور غير متطابقتين'
                    : 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // ── Terms ─────────────────────────────────────
          _TermsCheckbox(
            checked: _agreed,
            onChanged: (v) => setState(() => _agreed = v),
            onOpenTerms: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TermsPage()),
            ),
          ),
          const SizedBox(height: 16),

          // ── Create account button ─────────────────────
          _PrimaryBtn(
            label: isAr ? 'إنشاء الحساب' : 'Create Account',
            loading: _loading,
            enabled: _agreed,
            onTap: _phoneRegister,
          ),

          const SizedBox(height: 12),

          // ── Switch to login ───────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isAr ? 'عندك حساب بالفعل؟ ' : 'Already have an account? ',
                style: const TextStyle(fontSize: 14, color: _T.muted),
              ),
              GestureDetector(
                onTap: () => setState(() => _mode = _Mode.login),
                child: Text(
                  isAr ? 'سجّل دخولك' : 'Sign In',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _T.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: _T.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  COMPONENTS
// ══════════════════════════════════════════════════════════════

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _T.navy,
          letterSpacing: -0.1,
        ),
      );
}

class _Field extends StatefulWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType? keyType;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;
  const _Field({
    required this.ctrl,
    required this.hint,
    this.keyType,
    this.obscure = false,
    this.suffix,
    this.validator,
  });
  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  final _focus = FocusNode();
  bool _f = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _f = _focus.hasFocus));
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
            color: _f ? _T.navy : _T.border,
            width: _f ? 1.6 : 1,
          ),
        ),
        child: TextFormField(
          controller: widget.ctrl,
          focusNode: _focus,
          keyboardType: widget.keyType,
          obscureText: widget.obscure,
          validator: widget.validator,
          cursorColor: _T.primary,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: _T.navy),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(
                color: _T.soft, fontSize: 14, fontWeight: FontWeight.w500),
            border: InputBorder.none,
            errorStyle: const TextStyle(
                fontSize: 12, color: _T.error, fontWeight: FontWeight.w600),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            suffixIcon: widget.suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: widget.suffix,
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minHeight: 48,
              minWidth: 48,
            ),
          ),
        ),
      );
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;
  const _PrimaryBtn({
    required this.label,
    required this.loading,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = !enabled || loading;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 56,
        decoration: BoxDecoration(
          gradient: enabled && !loading ? _T.ctaGradient : null,
          color: !enabled
              ? _T.border
              : (loading ? _T.primary.withValues(alpha: 0.6) : null),
          borderRadius: BorderRadius.circular(14),
          boxShadow: disabled
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: enabled ? Colors.white : _T.soft,
                    letterSpacing: -0.3,
                  ),
                ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(child: Divider(color: _T.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            appSettings.arabic ? 'أو' : 'OR',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _T.muted,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Expanded(child: Divider(color: _T.border, thickness: 1)),
      ]);
}

class _TermsCheckbox extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;
  const _TermsCheckbox({
    required this.checked,
    required this.onChanged,
    required this.onOpenTerms,
  });

  @override
  Widget build(BuildContext context) {
    final ar = appSettings.arabic;
    const linkStyle = TextStyle(
      fontSize: 13,
      height: 1.55,
      fontWeight: FontWeight.w700,
      color: _T.navy,
      decoration: TextDecoration.underline,
      decorationColor: _T.soft,
    );
    const bodyStyle = TextStyle(
      fontSize: 13,
      height: 1.55,
      color: _T.muted,
      fontWeight: FontWeight.w500,
    );
    final tap = TapGestureRecognizer()..onTap = onOpenTerms;
    final richText = ar
        ? RichText(
            text: TextSpan(style: bodyStyle, children: [
              const TextSpan(text: 'قرأت ووافقت على '),
              TextSpan(
                  text: 'شروط الخدمة وسياسة الخصوصية',
                  style: linkStyle,
                  recognizer: tap),
              const TextSpan(
                  text: '، وأقرّ بأن عمري 18 عاماً أو أكثر.'),
            ]),
          )
        : RichText(
            text: TextSpan(style: bodyStyle, children: [
              const TextSpan(text: 'I have read and agree to the '),
              TextSpan(
                  text: 'Terms of Service and Privacy Policy',
                  style: linkStyle,
                  recognizer: tap),
              const TextSpan(
                  text: ', and confirm I am 18 years or older.'),
            ]),
          );

    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: checked ? _T.navy : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked ? _T.navy : _T.border,
                  width: 1.5,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: richText),
          ],
        ),
      ),
    );
  }
}

// ── Existing top-bar / icon components (unchanged) ───────────

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
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Icon(icon, size: 22, color: _T.navy),
        ),
      );
}

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

class _GoogleG extends StatelessWidget {
  final double size;
  const _GoogleG({required this.size});

  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          colors: [
            Color(0xFF4285F4),
            Color(0xFFEA4335),
            Color(0xFFFBBC05),
            Color(0xFF34A853),
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
