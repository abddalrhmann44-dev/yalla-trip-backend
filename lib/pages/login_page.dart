// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Login Page  (Professional redesign)
//  • Logo asset support (assets/images/logo.png)
//  • No "accept policy" checkbox
//  • Phone → OTP direct (no role ask)
//  • Delete account button ABOVE logout (Apple policy)
// ═══════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../widgets/constants.dart';
import 'home_page.dart';
import 'otp_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {

  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _formKey    = GlobalKey<FormState>();

  bool   _obscurePass = true;
  bool   _isLoading   = false;
  int    _tabIndex    = 0;   // 0=phone  1=email
  String _countryCode = '+20';
  String _countryName = 'Egypt';
  String _countryFlag = '🇪🇬';

  final _auth = FirebaseAuth.instance;

  static const _countries = [
    {'flag': '🇪🇬', 'name': 'Egypt',        'code': '+20'},
    {'flag': '🇸🇦', 'name': 'Saudi Arabia', 'code': '+966'},
    {'flag': '🇦🇪', 'name': 'UAE',          'code': '+971'},
    {'flag': '🇰🇼', 'name': 'Kuwait',       'code': '+965'},
    {'flag': '🇶🇦', 'name': 'Qatar',        'code': '+974'},
    {'flag': '🇯🇴', 'name': 'Jordan',       'code': '+962'},
    {'flag': '🇱🇧', 'name': 'Lebanon',      'code': '+961'},
    {'flag': '🇲🇦', 'name': 'Morocco',      'code': '+212'},
    {'flag': '🇬🇧', 'name': 'UK',           'code': '+44'},
    {'flag': '🇺🇸', 'name': 'USA',          'code': '+1'},
  ];

  late final AnimationController _waveCtrl = AnimationController(
    vsync: this, duration: const Duration(seconds: 7),
  )..repeat(reverse: true);

  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _fade =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  @override
  void dispose() {
    _waveCtrl.dispose(); _fadeCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════

  void _goHome() => Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomePage()), (_) => false);

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.w700))),
      ]),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tabIndex == 0) {
      await _phoneOtp();
    } else {
      await _emailLogin();
    }
  }

  // Phone → OTP بدون سؤال role (بيتسأل في البروفايل)
  Future<void> _phoneOtp() async {
    setState(() => _isLoading = true);
    final fullPhone = '$_countryCode${_phoneCtrl.text.trim()}';
    await _auth.verifyPhoneNumber(
      phoneNumber: fullPhone,
      timeout: const Duration(seconds: 60),
      codeSent: (verId, token) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => OtpPage(
            phoneNumber: fullPhone,
            verificationId: verId,
            resendToken: token,
          ),
        ));
      },
      verificationCompleted: (cred) async {
        await _auth.signInWithCredential(cred);
        if (mounted) _goHome();
      },
      verificationFailed: (e) {
        setState(() => _isLoading = false);
        _showError(e.code == 'invalid-phone-number'
            ? 'رقم الهاتف غير صحيح'
            : e.code == 'too-many-requests'
                ? 'محاولات كثيرة، انتظر قليلاً'
                : 'حدث خطأ، حاول مرة أخرى');
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> _emailLogin() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      if (mounted) _goHome();
    } on FirebaseAuthException catch (e) {
      String msg = 'حدث خطأ، حاول مرة أخرى';
      if (e.code == 'user-not-found')  msg = 'البريد الإلكتروني غير مسجل';
      if (e.code == 'wrong-password')  msg = 'كلمة المرور غير صحيحة';
      if (e.code == 'invalid-email')   msg = 'البريد الإلكتروني غير صحيح';
      if (e.code == 'user-disabled')   msg = 'تم تعطيل هذا الحساب';
      _showError(msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await GoogleSignIn().signIn();
      if (user == null) { setState(() => _isLoading = false); return; }
      final ga   = await user.authentication;
      final cred = GoogleAuthProvider.credential(
          accessToken: ga.accessToken, idToken: ga.idToken);
      await _auth.signInWithCredential(cred);
      if (mounted) _goHome();
    } catch (e) {
      _showError('حدث خطأ في تسجيل الدخول بـ Google');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _appleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final apC = await SignInWithApple.getAppleIDCredential(scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ]);
      final cred = OAuthProvider('apple.com').credential(
          idToken: apC.identityToken,
          accessToken: apC.authorizationCode);
      await _auth.signInWithCredential(cred);
      if (mounted) _goHome();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        _showError('Apple Sign In فشل');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guestLogin() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInAnonymously();
      if (mounted) _goHome();
    } catch (_) {
      _showError('حدث خطأ، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('اختر الدولة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          Expanded(child: ListView.builder(
            itemCount: _countries.length,
            itemBuilder: (ctx, i) {
              final c   = _countries[i];
              final sel = c['code'] == _countryCode;
              return ListTile(
                leading: Text(c['flag']!,
                    style: const TextStyle(fontSize: 24)),
                title: Text('${c['name']} (${c['code']})',
                    style: TextStyle(
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                        color: sel ? AppColors.primary : AppColors.textPrimary)),
                trailing: sel
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() {
                    _countryCode = c['code']!;
                    _countryName = c['name']!;
                    _countryFlag = c['flag']!;
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

  // ═══════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EE),
      body: Stack(children: [

        // Animated wave background
        Positioned.fill(child: AnimatedBuilder(
          animation: _waveCtrl,
          builder: (_, __) => CustomPaint(
            painter: _LoginWavePainter(_waveCtrl.value),
          ),
        )),

        SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const SizedBox(height: 32),

                    // ── Logo ──────────────────────────────
                    _logoBlock(),
                    const SizedBox(height: 40),

                    // ── Hero title ────────────────────────
                    const Text(
                      'أهلاً بيك! 👋',
                      style: TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w900,
                        color: Color(0xFF0D1B2A), letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'سجّل دخول واحجز إجازتك القادمة',
                      style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Tab selector ─────────────────────
                    _tabSelector(),
                    const SizedBox(height: 24),

                    // ── Form ─────────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOut,
                      child: _tabIndex == 0 ? _phoneForm() : _emailForm(),
                    ),
                    const SizedBox(height: 22),

                    // ── Main button ───────────────────────
                    _mainBtn(),
                    const SizedBox(height: 32),

                    // ── Divider ───────────────────────────
                    _divider(),
                    const SizedBox(height: 20),

                    // ── Social: Google + Apple ────────────
                    _socialRow(),
                    const SizedBox(height: 14),

                    // ── Guest ─────────────────────────────
                    _guestChip(),
                    const SizedBox(height: 32),

                    // ── Register link ─────────────────────
                    _registerLink(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Logo block ────────────────────────────────────────
  Widget _logoBlock() => Row(children: [
    // لو عندك logo.png، استخدم Image.asset
    // لو لأ، بيستخدم الـ icon كـ fallback
    Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.35),
            blurRadius: 18, offset: const Offset(0, 7))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.flight_takeoff_rounded,
            color: Colors.white, size: 28),
        ),
      ),
    ),
    const SizedBox(width: 14),
    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Yalla Trip',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
              color: Color(0xFF1565C0), letterSpacing: -0.4)),
      Text('اكتشف · احجز · استمتع',
          style: TextStyle(fontSize: 11, color: Color(0xFFFF6D00),
              fontWeight: FontWeight.w600, letterSpacing: 0.4)),
    ]),
  ]);

  // ── Tab selector ──────────────────────────────────────
  Widget _tabSelector() => Container(
    height: 54,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.07),
          blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Row(children: [
      _tabItem(0, Icons.phone_android_rounded, 'رقم الهاتف'),
      _tabItem(1, Icons.email_outlined,        'البريد الإلكتروني'),
    ]),
  );

  Widget _tabItem(int idx, IconData icon, String label) {
    final sel = _tabIndex == idx;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _tabIndex = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF1565C0) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16,
              color: sel ? Colors.white : Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: sel ? Colors.white : Colors.grey.shade500,
          )),
        ]),
      ),
    ));
  }

  // ── Phone form ────────────────────────────────────────
  Widget _phoneForm() => Column(
    key: const ValueKey('phone'),
    children: [
      _card(child: Column(children: [
        // Country picker
        GestureDetector(
          onTap: _showCountryPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(
                  color: Colors.grey.shade100, width: 1.5))),
            child: Row(children: [
              Text(_countryFlag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: Text('$_countryName ($_countryCode)',
                  style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700))),
              Icon(Icons.expand_more_rounded,
                  color: Colors.grey.shade400, size: 20),
            ]),
          ),
        ),
        // Phone number
        TextFormField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          validator: (v) => _tabIndex == 0 && (v == null || v.length < 9)
              ? 'أدخل رقم هاتف صحيح' : null,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'رقم الهاتف',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: const Icon(Icons.phone_outlined,
                size: 20, color: Color(0xFF1565C0)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
          ),
        ),
      ])),
      const SizedBox(height: 8),
      Row(children: [
        const SizedBox(width: 4),
        Icon(Icons.info_outline_rounded,
            size: 13, color: Colors.grey.shade400),
        const SizedBox(width: 5),
        Text('سيتم إرسال رمز OTP على رقمك',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    ],
  );

  // ── Email form ────────────────────────────────────────
  Widget _emailForm() => Column(
    key: const ValueKey('email'),
    children: [
      _card(child: TextFormField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        validator: (v) => _tabIndex == 1 && (v == null || !v.contains('@'))
            ? 'أدخل بريد إلكتروني صحيح' : null,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'البريد الإلكتروني',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: const Icon(Icons.email_outlined,
              size: 20, color: Color(0xFF1565C0)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 18),
        ),
      )),
      const SizedBox(height: 12),
      _card(child: TextFormField(
        controller: _passCtrl,
        obscureText: _obscurePass,
        validator: (v) => _tabIndex == 1 && (v == null || v.length < 6)
            ? 'كلمة المرور قصيرة جداً' : null,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'كلمة المرور',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              size: 20, color: Color(0xFF1565C0)),
          suffixIcon: IconButton(
            icon: Icon(_obscurePass
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
                size: 20, color: Colors.grey.shade400),
            onPressed: () =>
                setState(() => _obscurePass = !_obscurePass),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 18),
        ),
      )),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: const Text('نسيت كلمة المرور؟',
              style: TextStyle(fontSize: 13, color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w700)),
        ),
      ),
    ],
  );

  Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: child,
  );

  Widget _mainBtn() => SizedBox(
    width: double.infinity, height: 58,
    child: ElevatedButton(
      onPressed: _isLoading ? null : _signIn,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        disabledBackgroundColor:
            const Color(0xFF1565C0).withValues(alpha: 0.5),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
      ),
      child: _isLoading
          ? const SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_tabIndex == 0
                  ? 'إرسال رمز التحقق'
                  : 'تسجيل الدخول',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Icon(_tabIndex == 0
                  ? Icons.sms_outlined
                  : Icons.arrow_forward_rounded,
                  size: 18),
            ]),
    ),
  );

  Widget _divider() => Row(children: [
    const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text('أو تابع بـ',
          style: TextStyle(fontSize: 13,
              color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
    ),
    const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
  ]);

  Widget _socialRow() => Row(children: [
    Expanded(child: _socialChip(
      onTap: _googleSignIn,
      icon: _googleIcon(),
      label: 'Google',
    )),
    const SizedBox(width: 12),
    Expanded(child: _socialChip(
      onTap: _appleSignIn,
      icon: const Icon(Icons.apple_rounded, size: 22, color: Colors.black),
      label: 'Apple',
    )),
  ]);

  Widget _socialChip({
    required VoidCallback onTap,
    required Widget icon,
    required String label,
  }) => GestureDetector(
    onTap: _isLoading ? null : onTap,
    child: Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        icon,
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(
            fontSize: 14.5, fontWeight: FontWeight.w700,
            color: Color(0xFF0D1B2A))),
      ]),
    ),
  );

  Widget _googleIcon() => Container(
    width: 24, height: 24,
    decoration: BoxDecoration(
        shape: BoxShape.circle, color: Colors.grey.shade100),
    child: const Center(
      child: Text('G', style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w900,
          color: Color(0xFF4285F4))),
    ),
  );

  Widget _guestChip() => GestureDetector(
    onTap: _isLoading ? null : _guestLogin,
    child: Container(
      width: double.infinity, height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFFF6D00).withValues(alpha: 0.45), width: 1.8),
        boxShadow: [BoxShadow(
            color: const Color(0xFFFF6D00).withValues(alpha: 0.08),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6D00).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_outline_rounded,
              size: 17, color: Color(0xFFFF6D00)),
        ),
        const SizedBox(width: 10),
        const Text('تصفح كزائر',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700,
                color: Color(0xFFFF6D00))),
        const SizedBox(width: 6),
        const Icon(Icons.arrow_forward_ios_rounded,
            size: 12, color: Color(0xFFFF6D00)),
      ]),
    ),
  );

  Widget _registerLink() => Center(
    child: GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const RegisterPage())),
      child: RichText(text: const TextSpan(
        text: 'مش عندك حساب؟  ',
        style: TextStyle(color: Color(0xFF888888), fontSize: 13.5),
        children: [TextSpan(
          text: 'سجّل دلوقتي',
          style: TextStyle(color: Color(0xFF1565C0),
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFF1565C0)),
        )],
      )),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
//  WAVE PAINTER
// ═══════════════════════════════════════════════════════════════
class _LoginWavePainter extends CustomPainter {
  final double t;
  _LoginWavePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFF5F3EE));

    final p = Paint()..style = PaintingStyle.fill;

    p.color = const Color(0xFF1565C0).withValues(alpha: 0.12);
    canvas.drawPath(Path()
      ..moveTo(size.width * 0.3, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.35 + 45 * math.sin(t * math.pi))
      ..cubicTo(
        size.width * 0.8, size.height * 0.30 + 30 * math.sin(t * math.pi),
        size.width * 0.6, size.height * 0.22 + 20 * math.cos(t * math.pi),
        size.width * 0.3, size.height * 0.15 + 15 * math.sin(t * math.pi),
      )
      ..close(), p);

    p.color = const Color(0xFF1565C0).withValues(alpha: 0.07);
    canvas.drawPath(Path()
      ..moveTo(size.width * 0.55, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.20 + 25 * math.cos(t * math.pi))
      ..cubicTo(
        size.width * 0.85, size.height * 0.17,
        size.width * 0.72, size.height * 0.12,
        size.width * 0.55, size.height * 0.08,
      )
      ..close(), p);

    p.color = const Color(0xFFFF6D00).withValues(alpha: 0.10);
    canvas.drawPath(Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.72, size.height)
      ..cubicTo(
        size.width * 0.6, size.height * 0.85 + 30 * math.cos(t * math.pi),
        size.width * 0.35, size.height * 0.80 + 25 * math.sin(t * math.pi),
        0, size.height * 0.78 + 22 * math.cos(t * math.pi),
      )
      ..close(), p);

    p.color = const Color(0xFFFF6D00).withValues(alpha: 0.06);
    canvas.drawPath(Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.45, size.height)
      ..cubicTo(
        size.width * 0.35, size.height * 0.90 + 18 * math.sin(t * math.pi),
        size.width * 0.18, size.height * 0.88,
        0, size.height * 0.86,
      )
      ..close(), p);
  }

  @override
  bool shouldRepaint(_LoginWavePainter old) => old.t != t;
}
