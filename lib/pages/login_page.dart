// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Login Page
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../main.dart' show appSettings;
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'home_page.dart';
import '../utils/app_strings.dart';
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

  bool   get _ar => appSettings.arabic;
  String _t(String ar, String en) => _ar ? ar : en;

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  void _onLangChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange);
    _emailCtrl.dispose(); _passCtrl.dispose();
    _phoneCtrl.dispose(); _nameCtrl.dispose();
    super.dispose();
  }

  // ── Auth ────────────────────────────────────────────────────
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
    if (_tabIndex == 0) {
      await _phoneOtp();
    } else {
      if (!_formKey.currentState!.validate()) return;
      await _emailLogin();
    }
  }

  Future<void> _phoneOtp() async {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.length < 3)  { _showError(_t('أدخل اسمك الكامل', 'Enter your full name')); return; }
    if (phone.length < 9) { _showError(_t('أدخل رقم هاتف صحيح', 'Enter a valid phone number')); return; }
    setState(() => _isLoading = true);
    final full = '$_countryCode$phone';
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
            ? _t('رقم الهاتف غير صحيح', 'Invalid phone number')
            : e.code == 'too-many-requests'
                ? _t('محاولات كثيرة، انتظر قليلاً', 'Too many attempts')
                : _t('حدث خطأ، حاول مرة أخرى', 'An error occurred'));
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
      String msg = _t('حدث خطأ، حاول مرة أخرى', 'An error occurred');
      if (e.code == 'user-not-found') msg = _t('البريد غير مسجل', 'Email not found');
      if (e.code == 'wrong-password') msg = _t('كلمة المرور غير صحيحة', 'Wrong password');
      if (e.code == 'invalid-email')  msg = _t('البريد غير صحيح', 'Invalid email');
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
      _showError(_t('خطأ في تسجيل الدخول بـ Google', 'Google sign-in failed'));
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
      if (e.code != AuthorizationErrorCode.canceled) {
        _showError(_t('Apple Sign In فشل', 'Apple Sign In failed'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCountrySheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_t('اختر الدولة', 'Select Country'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ..._countries.map((c) => ListTile(
              leading: Text(c['flag']!,
                  style: const TextStyle(fontSize: 24)),
              title: Text(c['name']!),
              trailing: Text(c['code']!,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              selected: c['code'] == _countryCode,
              selectedColor: const Color(0xFFFF5C00),
              onTap: () {
                setState(() {
                  _countryCode = c['code']!;
                  _countryFlag = c['flag']!;
                });
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(children: [

        // Background image
        Positioned(
          top: 0, left: 0, right: 0,
          height: MediaQuery.of(context).size.height * 0.45,
          child: Image.asset(
            'assets/images/login_bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF1565C0)),
          ),
        ),

        // Header
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(height: 30),
                Text(S.loginTitle,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 8),
                Text(S.loginSubtitle,
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ),
        ),

        // Main Form Card
        Positioned(
          top: MediaQuery.of(context).size.height * 0.35,
          left: 0, right: 0, bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(40)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Tabs ────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _tabIndex = 0),
                            child: _buildTabItem(
                              _t('رقم الهاتف', 'Phone'),
                              _tabIndex == 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _tabIndex = 1),
                            child: _buildTabItem(
                              _t('البريد الإلكتروني', 'Email'),
                              _tabIndex == 1,
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 32),

                    // ── Fields ──────────────────────────
                    if (_tabIndex == 0) _buildPhoneView()
                    else _buildEmailView(),

                    const SizedBox(height: 32),

                    // ── Submit ───────────────────────────
                    _buildMainBtn(
                      label: _tabIndex == 0
                          ? _t('إرسال رمز التحقق', 'Send Code')
                          : S.loginAction,
                      icon: _tabIndex == 0
                          ? Icons.bolt_rounded
                          : Icons.login_rounded,
                      onTap: _signIn,
                    ),
                    const SizedBox(height: 24),

                    // ── Divider ──────────────────────────
                    _buildDivider(_t('أو تابع بـ', 'or continue with')),
                    const SizedBox(height: 24),

                    // ── Social ───────────────────────────
                    Row(children: [
                      Expanded(child: _buildSocialBtn(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 22, height: 22,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFF1F3F4)),
                              child: const Center(child: Text('G',
                                  style: TextStyle(fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF4285F4))))),
                            const SizedBox(width: 8),
                            const Text('Google',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ]),
                        onTap: _isLoading ? null : _googleSignIn,
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _buildSocialBtn(
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.apple, size: 26),
                            SizedBox(width: 8),
                            Text('Apple',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ]),
                        onTap: _isLoading ? null : _appleSignIn,
                      )),
                    ]),
                    const SizedBox(height: 30),

                    // ── Register link ─────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const RegisterPage())),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                color: Color(0xFF6C757D),
                                fontSize: 14),
                            children: [
                              TextSpan(
                                text: _ar
                                    ? '${S.noAccount}  '
                                    : "Don't have an account?  ",
                              ),
                              TextSpan(
                                text: _t('سجّل دلوقتي', 'Register'),
                                style: const TextStyle(
                                    color: Color(0xFFFF5C00),
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Loading overlay
        if (_isLoading)
          Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFFFF5C00)),
            ),
          ),
      ]),
    ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────

  Widget _buildTabItem(String label, bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: active ? [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4, offset: const Offset(0, 2),
        )] : [],
      ),
      child: Center(
        child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: active
                    ? const Color(0xFF0D1B2A)
                    : const Color(0xFFADB5BD),
                fontWeight:
                    active ? FontWeight.bold : FontWeight.normal,
                fontSize: 14)),
      ),
    );
  }

  Widget _buildPhoneView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(_t('الاسم الكامل', 'Full Name')),
        const SizedBox(height: 10),
        _textField(_nameCtrl, _t('اسمك الكامل', 'Your name'),
            Icons.person_outline_rounded, false),
        const SizedBox(height: 20),
        _label(_t('رقم الهاتف', 'Phone Number')),
        const SizedBox(height: 10),
        // LTR so +20 stays correct in Arabic mode
        Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDEE2E6)),
            ),
            child: Row(children: [
              _buildCountryPicker(),
              Container(width: 1, height: 30,
                  color: const Color(0xFFDEE2E6)),
              Expanded(
                child: TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: '1XX XXX XXXX',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(_t('البريد الإلكتروني', 'Email')),
        const SizedBox(height: 10),
        _textField(_emailCtrl, 'example@mail.com',
            Icons.alternate_email_rounded, false,
            keyType: TextInputType.emailAddress,
            validator: (v) => (v == null || !v.contains('@'))
                ? _t('بريد غير صحيح', 'Invalid email') : null),
        const SizedBox(height: 20),
        _label(_t('كلمة المرور', 'Password')),
        const SizedBox(height: 10),
        _textField(_passCtrl, '••••••••',
            Icons.lock_outline_rounded, true,
            validator: (v) => (v == null || v.length < 6)
                ? _t('كلمة المرور قصيرة', 'Password too short')
                : null),
        Align(
          alignment: _ar
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize:
                    MaterialTapTargetSize.shrinkWrap),
            child: Text(S.forgotPass,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFFF5C00),
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _label(String txt) => Text(txt,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF495057)));

  Widget _textField(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    bool isPass, {
    TextInputType? keyType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDEE2E6)),
      ),
      child: TextFormField(
        controller: ctrl,
        obscureText: isPass && _obscurePass,
        keyboardType: keyType,
        validator: validator,
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF0D1B2A)),
        decoration: InputDecoration(
          prefixIcon: Icon(icon,
              color: const Color(0xFF6C757D), size: 20),
          suffixIcon: isPass
              ? IconButton(
                  icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: const Color(0xFF6C757D),
                      size: 20),
                  onPressed: () => setState(
                      () => _obscurePass = !_obscurePass),
                )
              : null,
          hintText: hint,
          hintStyle: TextStyle(
              color: const Color(0xFF0D1B2A).withValues(alpha: 0.3)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildCountryPicker() {
    return InkWell(
      onTap: _showCountrySheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 15),
        child: Row(children: [
          Text(_countryFlag,
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(_countryCode,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
        ]),
      ),
    );
  }

  Widget _buildMainBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFF8C00), Color(0xFFFF5C00)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: const Color(0xFFFF5C00).withValues(alpha: 0.3),
            blurRadius: 12, offset: const Offset(0, 6),
          )],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  const SizedBox(width: 8),
                  Icon(icon, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialBtn({
    required Widget child,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF0D1B2A).withValues(alpha: 0.1)),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2),
          )],
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildDivider(String label) {
    return Row(children: [
      Expanded(child: Divider(
          color: const Color(0xFF0D1B2A).withValues(alpha: 0.1))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFADB5BD),
                fontWeight: FontWeight.bold)),
      ),
      Expanded(child: Divider(
          color: const Color(0xFF0D1B2A).withValues(alpha: 0.1))),
    ]);
  }
}
