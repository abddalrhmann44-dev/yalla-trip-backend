// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Login Page  (Clean Minimal White — matches Welcome)
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
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

  late final AnimationController _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
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
      if (e.code == 'user-not-found')      msg = 'البريد الإلكتروني غير مسجل';
      if (e.code == 'wrong-password')      msg = 'كلمة المرور غير صحيحة';
      if (e.code == 'invalid-credential')  msg = 'كلمة المرور غير صحيحة';
      if (e.code == 'invalid-email')       msg = 'البريد الإلكتروني غير صحيح';
      if (e.code == 'too-many-requests')   msg = 'محاولات كثيرة، انتظر قليلاً';
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
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('اختر الدولة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: Color(0xFF0D1B2A))),
          ),
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
                        color: sel
                            ? const Color(0xFF1565C0)
                            : const Color(0xFF0D1B2A))),
                trailing: sel
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF1565C0))
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

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(children: [

        // ── صورة الخلفية كاملة ──────────────────────────────
        SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Image.asset(
            'assets/images/login_bg.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),


        FadeTransition(
        opacity: _fade,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Back ───────────────────────────
                  _BackBtn(onTap: () => Navigator.pop(context)),
                  const SizedBox(height: 32),


                  Text(S.loginTitle,
                      style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w900,
                        color: Color(0xFF0D1B2A), letterSpacing: -1,
                      )),
                  const SizedBox(height: 6),
                  Text(S.loginSubtitle,
                      style: TextStyle(fontSize: 14,
                          color: const Color(0xFF0D1B2A).withValues(alpha: 0.4),
                          fontWeight: FontWeight.w500)),

                  const SizedBox(height: 32),

                  // ── Tab ─────────────────────────────
                  _TabSelector(
                    selected: _tabIndex,
                    onChanged: (i) => setState(() => _tabIndex = i),
                  ),
                  const SizedBox(height: 24),

                  // ── Fields ──────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: _tabIndex == 0 ? _phoneForm() : _emailForm(),
                  ),
                  const SizedBox(height: 24),

                  // ── Main button ─────────────────────
                  _PrimaryBtn(
                    label: _tabIndex == 0 ? 'إرسال رمز التحقق' : 'تسجيل الدخول',
                    icon: _tabIndex == 0
                        ? Icons.sms_outlined
                        : Icons.arrow_forward_rounded,
                    loading: _isLoading,
                    onTap: _signIn,
                  ),
                  const SizedBox(height: 28),

                  // ── Divider ─────────────────────────
                  _Divider(),
                  const SizedBox(height: 20),

                  // ── Social ──────────────────────────
                  Row(children: [
                    Expanded(child: _SocialBtn(
                      onTap: _isLoading ? null : _googleSignIn,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 20, height: 20,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFF1F3F4)),
                            child: const Center(child: Text('G',
                                style: TextStyle(fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF4285F4))))),
                          const SizedBox(width: 8),
                          const Text('Google', style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: Color(0xFF0D1B2A))),
                        ]),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _SocialBtn(
                      onTap: _isLoading ? null : _appleSignIn,
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.apple_rounded,
                              color: Color(0xFF0D1B2A), size: 20),
                          SizedBox(width: 8),
                          Text('Apple', style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: Color(0xFF0D1B2A))),
                        ]),
                    )),
                  ]),

                  const SizedBox(height: 10),

                  // ── Guest ───────────────────────────
                  _SocialBtn(
                    onTap: _isLoading ? null : _guestLogin,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_outline_rounded,
                            size: 18,
                            color: const Color(0xFF0D1B2A).withValues(alpha: 0.5)),
                        const SizedBox(width: 8),
                        Text(S.guestBtn,
                            style: TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0D1B2A)
                                    .withValues(alpha: 0.6))),
                      ]),
                  ),

                  const SizedBox(height: 28),

                  // ── Register link ───────────────────
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterPage())),
                      child: RichText(text: TextSpan(
                        text: '${S.noAccount}  ',
                        style: TextStyle(
                            color: const Color(0xFF0D1B2A).withValues(alpha: 0.4),
                            fontSize: 13.5),
                        children: const [TextSpan(
                          text: 'سجّل دلوقتي',
                          style: TextStyle(
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFF1565C0)),
                        )],
                      )),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
        ), // FadeTransition
      ]), // Stack
    );
  }

  // ── Form widgets ─────────────────────────────────────────────

  Widget _phoneForm() => Column(key: const ValueKey('phone'), children: [
    _Field(
      ctrl: _nameCtrl, hint: S.namePlaceholder,
      icon: Icons.person_outline_rounded,
      validator: (v) => _tabIndex == 0 && (v == null || v.trim().length < 3)
          ? 'أدخل اسمك الكامل' : null,
    ),
    const SizedBox(height: 12),
    _CountryPhoneField(
      flag: _countryFlag, code: _countryCode, name: _countryName,
      ctrl: _phoneCtrl,
      onPickCountry: _showCountryPicker,
      validator: (v) => _tabIndex == 0 && (v == null || v.length < 9)
          ? 'أدخل رقم هاتف صحيح' : null,
    ),
    const SizedBox(height: 6),
    Align(alignment: Alignment.centerRight,
      child: Text('سيتم إرسال رمز OTP على رقمك',
          style: TextStyle(fontSize: 12,
              color: const Color(0xFF0D1B2A).withValues(alpha: 0.35)))),
  ]);

  Widget _emailForm() => Column(key: const ValueKey('email'), children: [
    _Field(
      ctrl: _emailCtrl, hint: S.emailPlaceholder,
      icon: Icons.email_outlined,
      keyType: TextInputType.emailAddress,
      validator: (v) => _tabIndex == 1 && (v == null || !v.contains('@'))
          ? 'أدخل بريد إلكتروني صحيح' : null,
    ),
    const SizedBox(height: 12),
    _Field(
      ctrl: _passCtrl, hint: S.passPlaceholder,
      icon: Icons.lock_outline_rounded,
      obscure: _obscurePass,
      suffix: IconButton(
        icon: Icon(_obscurePass
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
            size: 20,
            color: const Color(0xFF0D1B2A).withValues(alpha: 0.35)),
        onPressed: () => setState(() => _obscurePass = !_obscurePass),
      ),
      validator: (v) => _tabIndex == 1 && (v == null || v.length < 6)
          ? 'كلمة المرور قصيرة جداً' : null,
    ),
    Align(alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        child: Text(S.forgotPass,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1565C0),
                fontWeight: FontWeight.w700)),
      )),
  ]);
}

// ══════════════════════════════════════════════════════════════
//  SHARED WIDGETS — same style as WelcomePage
// ══════════════════════════════════════════════════════════════

class _BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF0D1B2A).withValues(alpha: 0.08)),
      ),
      child: const Icon(Icons.arrow_back_ios_new_rounded,
          size: 16, color: Color(0xFF0D1B2A)),
    ),
  );
}



class _TabSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _TabSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    height: 50,
    decoration: BoxDecoration(
      color: const Color(0xFFF5F7FF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(children: [
      _item(0, Icons.phone_android_rounded, 'رقم الهاتف'),
      _item(1, Icons.email_outlined, 'البريد الإلكتروني'),
    ]),
  );

  Widget _item(int idx, IconData icon, String label) {
    final sel = selected == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: sel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: sel ? [BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8, offset: const Offset(0, 2),
            )] : [],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15,
                color: sel
                    ? const Color(0xFF1565C0)
                    : const Color(0xFF0D1B2A).withValues(alpha: 0.35)),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: sel
                  ? const Color(0xFF1565C0)
                  : const Color(0xFF0D1B2A).withValues(alpha: 0.35),
            )),
          ]),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyType;
  final String? Function(String?)? validator;

  const _Field({
    required this.ctrl, required this.hint, required this.icon,
    this.obscure = false, this.suffix, this.keyType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF5F7FF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
          color: const Color(0xFF0D1B2A).withValues(alpha: 0.07)),
    ),
    child: TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyType,
      validator: validator,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
          color: Color(0xFF0D1B2A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: const Color(0xFF0D1B2A).withValues(alpha: 0.3),
            fontSize: 14),
        prefixIcon: Icon(icon, size: 20,
            color: const Color(0xFF1565C0).withValues(alpha: 0.7)),
        suffixIcon: suffix,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 18),
      ),
    ),
  );
}

class _CountryPhoneField extends StatelessWidget {
  final String flag, code, name;
  final TextEditingController ctrl;
  final VoidCallback onPickCountry;
  final String? Function(String?)? validator;

  const _CountryPhoneField({
    required this.flag, required this.code, required this.name,
    required this.ctrl, required this.onPickCountry, this.validator,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF5F7FF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
          color: const Color(0xFF0D1B2A).withValues(alpha: 0.07)),
    ),
    child: Column(children: [
      GestureDetector(
        onTap: onPickCountry,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(
                  color: const Color(0xFF0D1B2A).withValues(alpha: 0.07)))),
          child: Row(children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(child: Text('$name ($code)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D1B2A).withValues(alpha: 0.7)))),
            Icon(Icons.expand_more_rounded,
                color: const Color(0xFF0D1B2A).withValues(alpha: 0.3),
                size: 20),
          ]),
        ),
      ),
      TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(11)],
        validator: validator,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
            color: Color(0xFF0D1B2A)),
        decoration: InputDecoration(
          hintText: 'رقم الهاتف',
          hintStyle: TextStyle(
              color: const Color(0xFF0D1B2A).withValues(alpha: 0.3),
              fontSize: 14),
          prefixIcon: Icon(Icons.phone_outlined, size: 20,
              color: const Color(0xFF1565C0).withValues(alpha: 0.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 16),
        ),
      ),
    ]),
  );
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.icon,
      required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: AnimatedOpacity(
      opacity: loading ? 0.7 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: double.infinity, height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.28),
            blurRadius: 16, offset: const Offset(0, 6),
          )],
        ),
        child: Center(child: loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(label, style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white, size: 18),
              ])),
      ),
    ),
  );
}

class _SocialBtn extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _SocialBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
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
      child: child,
    ),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Divider(
        color: const Color(0xFF0D1B2A).withValues(alpha: 0.1))),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text('أو تابع بـ',
          style: TextStyle(fontSize: 12,
              color: const Color(0xFF0D1B2A).withValues(alpha: 0.35),
              fontWeight: FontWeight.w500)),
    ),
    Expanded(child: Divider(
        color: const Color(0xFF0D1B2A).withValues(alpha: 0.1))),
  ]);
}
