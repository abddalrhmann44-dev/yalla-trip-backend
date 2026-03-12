// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Login Page  (Premium Dark Design)
// ═══════════════════════════════════════════════════════════════
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'home_page.dart';
import 'otp_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {

  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nameCtrl  = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  bool   _obscurePass = true;
  bool   _isLoading   = false;
  int    _tabIndex    = 0;
  String _countryCode = '+20';
  String _countryFlag = '🇪🇬';
  String _countryName = 'Egypt';

  final _auth = FirebaseAuth.instance;

  static const _countries = [
    {'flag': '🇪🇬', 'name': 'Egypt',        'code': '+20'},
    {'flag': '🇸🇦', 'name': 'Saudi Arabia', 'code': '+966'},
    {'flag': '🇦🇪', 'name': 'UAE',          'code': '+971'},
    {'flag': '🇰🇼', 'name': 'Kuwait',       'code': '+965'},
    {'flag': '🇶🇦', 'name': 'Qatar',        'code': '+974'},
    {'flag': '🇯🇴', 'name': 'Jordan',       'code': '+962'},
    {'flag': '🇱🇧', 'name': 'Lebanon',      'code': '+961'},
    {'flag': '🇬🇧', 'name': 'UK',           'code': '+44'},
    {'flag': '🇺🇸', 'name': 'USA',          'code': '+1'},
  ];

  late final AnimationController _bgCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  late final AnimationController _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  @override
  void dispose() {
    _bgCtrl.dispose(); _fadeCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose();
    _phoneCtrl.dispose(); _nameCtrl.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────
  void _goHome() => Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()), (_) => false);

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.w700))),
      ]),
      backgroundColor: const Color(0xFFEF5350),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    _tabIndex == 0 ? await _phoneOtp() : await _emailLogin();
  }

  Future<void> _phoneOtp() async {
    setState(() => _isLoading = true);
    final full = '$_countryCode${_phoneCtrl.text.trim()}';
    final name = _nameCtrl.text.trim();
    await _auth.verifyPhoneNumber(
      phoneNumber: full,
      timeout: const Duration(seconds: 60),
      codeSent: (verId, token) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => OtpPage(
            phoneNumber: full, verificationId: verId,
            resendToken: token, userName: name,
          ),
        ));
      },
      verificationCompleted: (cred) async {
        await _auth.signInWithCredential(cred);
        if (name.isNotEmpty) await _auth.currentUser?.updateDisplayName(name);
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
        email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
      if (mounted) _goHome();
    } on FirebaseAuthException catch (e) {
      String msg = 'حدث خطأ، حاول مرة أخرى';
      if (e.code == 'user-not-found')  msg = 'البريد الإلكتروني غير مسجل';
      if (e.code == 'wrong-password')  msg = 'كلمة المرور غير صحيحة';
      if (e.code == 'invalid-email')   msg = 'البريد الإلكتروني غير صحيح';
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
    } catch (_) {
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
          idToken: apC.identityToken, accessToken: apC.authorizationCode);
      await _auth.signInWithCredential(cred);
      if (mounted) _goHome();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) _showError('Apple Sign In فشل');
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
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: Color(0xFF0F1E35),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const Padding(padding: EdgeInsets.all(20),
              child: Text('اختر الدولة', style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white))),
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
                        color: sel ? const Color(0xFF42A5F5) : Colors.white70)),
                trailing: sel ? const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF1565C0)) : null,
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

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
      body: Stack(fit: StackFit.expand, children: [

        AnimatedBuilder(
          animation: _bgCtrl,
          builder: (_, __) => CustomPaint(
            painter: _AuthBgPainter(_bgCtrl.value, isLogin: true),
            size: size,
          ),
        ),

        SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Back + Logo ─────────────────────
                    Row(children: [
                      _backBtn(),
                      const Spacer(),
                      _logoChip(),
                    ]),
                    const SizedBox(height: 36),

                    // ── Headline ────────────────────────
                    const Text('أهلاً بك\nمجدداً 👋',
                        style: TextStyle(
                          fontSize: 38, fontWeight: FontWeight.w900,
                          color: Colors.white, height: 1.1, letterSpacing: -1,
                        )),
                    const SizedBox(height: 10),
                    Text('تسجيل الدخول للمتابعة',
                        style: TextStyle(fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 32),

                    // ── Tab selector ────────────────────
                    _tabSelector(),
                    const SizedBox(height: 24),

                    // ── Form fields ─────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: _tabIndex == 0 ? _phoneForm() : _emailForm(),
                    ),
                    const SizedBox(height: 24),

                    // ── Main button ─────────────────────
                    _mainBtn(),
                    const SizedBox(height: 28),

                    // ── Divider ─────────────────────────
                    _divider(),
                    const SizedBox(height: 20),

                    // ── Social ──────────────────────────
                    _socialRow(),
                    const SizedBox(height: 12),
                    _guestBtn(),
                    const SizedBox(height: 28),

                    // ── Register link ───────────────────
                    _registerLink(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────

  Widget _backBtn() => GestureDetector(
    onTap: () => Navigator.pop(context),
    child: Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: const Icon(Icons.arrow_back_ios_new_rounded,
          size: 15, color: Colors.white),
    ),
  );

  Widget _logoChip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 14),
      SizedBox(width: 5),
      Text('Yalla Trip', style: TextStyle(
          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _tabSelector() => Container(
    height: 50,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: Row(children: [
      _tabItem(0, Icons.phone_android_rounded, 'رقم الهاتف'),
      _tabItem(1, Icons.email_outlined,        'البريد الإلكتروني'),
    ]),
  );

  Widget _tabItem(int idx, IconData icon, String label) {
    final sel = _tabIndex == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: sel ? const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]) : null,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15,
                color: sel ? Colors.white : Colors.white38),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: sel ? Colors.white : Colors.white38,
            )),
          ]),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    ),
    child: child,
  );

  InputDecoration _inputDec(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF42A5F5)),
        suffixIcon: suffix,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      );

  Widget _phoneForm() => Column(key: const ValueKey('phone'), children: [
    _glassCard(child: TextFormField(
      controller: _nameCtrl,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(color: Colors.white, fontSize: 15,
          fontWeight: FontWeight.w600),
      validator: (v) => _tabIndex == 0 && (v == null || v.trim().length < 3)
          ? 'أدخل اسمك الكامل' : null,
      decoration: _inputDec('الاسم الكامل', Icons.person_outline_rounded),
    )),
    const SizedBox(height: 12),
    _glassCard(child: Column(children: [
      GestureDetector(
        onTap: _showCountryPicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08), width: 1))),
          child: Row(children: [
            Text(_countryFlag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(child: Text('$_countryName ($_countryCode)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7)))),
            Icon(Icons.expand_more_rounded,
                color: Colors.white.withValues(alpha: 0.3), size: 20),
          ]),
        ),
      ),
      TextFormField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(11)],
        style: const TextStyle(color: Colors.white, fontSize: 15,
            fontWeight: FontWeight.w600),
        validator: (v) => _tabIndex == 0 && (v == null || v.length < 9)
            ? 'أدخل رقم هاتف صحيح' : null,
        decoration: _inputDec('رقم الهاتف', Icons.phone_outlined),
      ),
    ])),
    const SizedBox(height: 6),
    Padding(padding: const EdgeInsets.only(right: 4),
      child: Text('سيتم إرسال رمز OTP على رقمك',
          style: TextStyle(fontSize: 12,
              color: Colors.white.withValues(alpha: 0.3)))),
  ]);

  Widget _emailForm() => Column(key: const ValueKey('email'), children: [
    _glassCard(child: TextFormField(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white, fontSize: 15,
          fontWeight: FontWeight.w600),
      validator: (v) => _tabIndex == 1 && (v == null || !v.contains('@'))
          ? 'أدخل بريد إلكتروني صحيح' : null,
      decoration: _inputDec('البريد الإلكتروني', Icons.email_outlined),
    )),
    const SizedBox(height: 12),
    _glassCard(child: TextFormField(
      controller: _passCtrl,
      obscureText: _obscurePass,
      style: const TextStyle(color: Colors.white, fontSize: 15,
          fontWeight: FontWeight.w600),
      validator: (v) => _tabIndex == 1 && (v == null || v.length < 6)
          ? 'كلمة المرور قصيرة جداً' : null,
      decoration: _inputDec('كلمة المرور', Icons.lock_outline_rounded,
          suffix: IconButton(
            icon: Icon(_obscurePass ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
                size: 20, color: Colors.white38),
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
          )),
    )),
    Align(alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        child: const Text('نسيت كلمة المرور؟',
            style: TextStyle(fontSize: 13, color: Color(0xFF42A5F5),
                fontWeight: FontWeight.w700)),
      )),
  ]);

  Widget _mainBtn() => GestureDetector(
    onTap: _isLoading ? null : _signIn,
    child: Container(
      width: double.infinity, height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isLoading
              ? [const Color(0xFF1565C0).withValues(alpha: 0.5),
                 const Color(0xFF1E88E5).withValues(alpha: 0.5)]
              : [const Color(0xFF1565C0), const Color(0xFF1E88E5)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: _isLoading ? [] : [BoxShadow(
          color: const Color(0xFF1565C0).withValues(alpha: 0.45),
          blurRadius: 20, offset: const Offset(0, 8),
        )],
      ),
      child: Center(child: _isLoading
          ? const SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_tabIndex == 0 ? 'إرسال رمز التحقق' : 'تسجيل الدخول',
                  style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(width: 8),
              Icon(_tabIndex == 0 ? Icons.sms_outlined
                  : Icons.arrow_forward_rounded,
                  size: 18, color: Colors.white),
            ])),
    ),
  );

  Widget _divider() => Row(children: [
    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text('أو تابع بـ',
          style: TextStyle(fontSize: 12,
              color: Colors.white.withValues(alpha: 0.3),
              fontWeight: FontWeight.w500))),
    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
  ]);

  Widget _socialRow() => Row(children: [
    Expanded(child: _socialChip(
        onTap: _googleSignIn,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 22, height: 22,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1)),
            child: const Center(child: Text('G', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900,
                color: Color(0xFF4285F4))))),
          const SizedBox(width: 7),
          const Text('Google', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ]))),
    const SizedBox(width: 10),
    Expanded(child: _socialChip(
        onTap: _appleSignIn,
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.apple_rounded, color: Colors.white, size: 20),
          SizedBox(width: 7),
          Text('Apple', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ]))),
  ]);

  Widget _socialChip({required VoidCallback onTap, required Widget child}) =>
      GestureDetector(
        onTap: _isLoading ? null : onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      );

  Widget _guestBtn() => GestureDetector(
    onTap: _isLoading ? null : _guestLogin,
    child: Container(
      width: double.infinity, height: 50,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: const Color(0xFFFF6D00).withValues(alpha: 0.35), width: 1.5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 28, height: 28,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: const Color(0xFFFF6D00).withValues(alpha: 0.12)),
          child: const Icon(Icons.person_outline_rounded,
              size: 16, color: Color(0xFFFF6D00))),
        const SizedBox(width: 8),
        const Text('تصفح كزائر',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: Color(0xFFFF6D00))),
        const SizedBox(width: 5),
        const Icon(Icons.arrow_forward_ios_rounded,
            size: 11, color: Color(0xFFFF6D00)),
      ]),
    ),
  );

  Widget _registerLink() => Center(
    child: GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const RegisterPage())),
      child: RichText(text: TextSpan(
        text: 'مش عندك حساب؟  ',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.35),
            fontSize: 13.5),
        children: const [TextSpan(
          text: 'سجّل دلوقتي',
          style: TextStyle(color: Color(0xFF42A5F5),
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFF42A5F5)),
        )],
      )),
    ),
  );
}

// ── Shared Auth Background Painter ─────────────────────────────
class _AuthBgPainter extends CustomPainter {
  final double t;
  final bool isLogin;
  _AuthBgPainter(this.t, {required this.isLogin});

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF060D1A));
    final p = Paint()..style = PaintingStyle.fill;

    // Blue orb
    p.shader = RadialGradient(colors: [
      const Color(0xFF1565C0).withValues(alpha: isLogin ? 0.45 : 0.40),
      const Color(0xFF1565C0).withValues(alpha: 0),
    ]).createShader(Rect.fromCircle(
      center: Offset(s.width * (0.88 + 0.07 * math.sin(t * math.pi)),
                     s.height * (0.12 + 0.05 * math.cos(t * math.pi))),
      radius: s.width * 0.6,
    ));
    canvas.drawCircle(
      Offset(s.width * (0.88 + 0.07 * math.sin(t * math.pi)),
             s.height * (0.12 + 0.05 * math.cos(t * math.pi))),
      s.width * 0.6, p,
    );

    // Orange orb
    p.shader = RadialGradient(colors: [
      const Color(0xFFFF6D00).withValues(alpha: 0.22),
      const Color(0xFFFF6D00).withValues(alpha: 0),
    ]).createShader(Rect.fromCircle(
      center: Offset(s.width * (0.08 + 0.05 * math.cos(t * math.pi)),
                     s.height * (0.85 + 0.04 * math.sin(t * math.pi))),
      radius: s.width * 0.5,
    ));
    canvas.drawCircle(
      Offset(s.width * (0.08 + 0.05 * math.cos(t * math.pi)),
             s.height * (0.85 + 0.04 * math.sin(t * math.pi))),
      s.width * 0.5, p,
    );

    // Dot grid
    final dot = Paint()
      ..color = Colors.white.withValues(alpha: 0.022)
      ..style = PaintingStyle.fill;
    for (int r = 0; r < 22; r++) {
      for (int c = 0; c < 11; c++) {
        if ((r + c) % 3 == 0) {
          canvas.drawCircle(
              Offset(c * s.width / 10, r * s.height / 21), 1.1, dot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_AuthBgPainter o) => o.t != t;
}
