// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Register Page
//  Phone OTP (primary) + Email (secondary)
//  Animated wavy background
// ═══════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'otp_page.dart';
import 'onboarding_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {

  // ── Controllers ──────────────────────────────────────────────
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  // ── State ────────────────────────────────────────────────────
  int  _tab         = 0;   // 0 = Phone, 1 = Email
  bool _loading     = false;
  bool _agreed      = false;
  bool _obscurePass = true;
  bool _obscureConf = true;

  // ── Firebase ─────────────────────────────────────────────────
  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // ── Animations ───────────────────────────────────────────────
  late final AnimationController _waveCtrl = AnimationController(
    vsync: this, duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 650),
  )..forward();

  late final Animation<double> _fade =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  @override
  void dispose() {
    _waveCtrl.dispose(); _fadeCtrl.dispose();
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════════════════

  Future<void> _registerPhone() async {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.length < 3) { _err('أدخل اسمك الكامل (3 أحرف على الأقل)'); return; }
    if (phone.length < 9) { _err('أدخل رقم هاتف صحيح'); return; }
    if (!_agreed)          { _err('يجب الموافقة على الشروط والأحكام'); return; }

    setState(() => _loading = true);

    final raw = phone.startsWith('0') ? phone.substring(1) : phone;
    final fullPhone = '+20$raw';

    await _auth.verifyPhoneNumber(
      phoneNumber: fullPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential cred) async {
        await _auth.signInWithCredential(cred);
        await _saveUser(name, '', fullPhone);
        if (mounted) _goOnboarding();
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _loading = false);
        _err(e.code == 'invalid-phone-number'
            ? 'رقم الهاتف غير صحيح'
            : 'حدث خطأ، حاول مرة أخرى');
      },
      codeSent: (String verId, int? token) {
        setState(() => _loading = false);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => OtpPage(
            phoneNumber: fullPhone,
            verificationId: verId,
            resendToken: token,
            userName: name,
          ),
        ));
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> _registerEmail() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) { _err('يجب الموافقة على الشروط والأحكام'); return; }

    setState(() => _loading = true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      await cred.user!.updateDisplayName(_nameCtrl.text.trim());
      await _saveUser(_nameCtrl.text.trim(), _emailCtrl.text.trim(), '');
      if (mounted) _goOnboarding();
    } on FirebaseAuthException catch (e) {
      String msg = 'حدث خطأ، حاول مرة أخرى';
      if (e.code == 'email-already-in-use') msg = 'البريد الإلكتروني مسجل مسبقاً';
      else if (e.code == 'weak-password')   msg = 'كلمة المرور ضعيفة — 6 أحرف على الأقل';
      else if (e.code == 'invalid-email')   msg = 'البريد الإلكتروني غير صحيح';
      _err(msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveUser(String name, String email, String phone) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set({
      'uid':       uid,
      'name':      name,
      'email':     email,
      'phone':     phone,
      'role':      'guest',
      'createdAt': FieldValue.serverTimestamp(),
      'avatar':    '',
    });
  }

  void _goOnboarding() => Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const OnboardingPage()),
    (_) => false,
  );

  void _err(String msg) {
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

  // ═══════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EE),
      body: Stack(children: [
        // ── Animated wavy bg ──────────────────────────
        Positioned.fill(child: AnimatedBuilder(
          animation: _waveCtrl,
          builder: (_, __) => CustomPaint(
            painter: _WavePainter(_waveCtrl.value),
          ),
        )),

        SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Top bar ───────────────────────────
                  Row(children: [
                    _backBtn(),
                    const SizedBox(width: 12),
                    _logoChip(),
                  ]),

                  const SizedBox(height: 32),

                  // ── Heading ───────────────────────────
                  const Text('إنشاء حساب جديد',
                      style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w900,
                        color: Color(0xFF0D1B2A), letterSpacing: -0.5,
                      )),
                  const SizedBox(height: 6),
                  Text('انضم لـ يلا تريب واكتشف أجمل الوجهات',
                      style: TextStyle(fontSize: 13.5,
                          color: Colors.grey.shade600)),

                  const SizedBox(height: 28),

                  // ── Tab selector ──────────────────────
                  _tabSelector(),
                  const SizedBox(height: 22),

                  // ── Name field (always visible) ───────
                  _field(
                    ctrl: _nameCtrl,
                    hint: 'الاسم الكامل',
                    icon: Icons.person_outline_rounded,
                    validator: (v) => (v == null || v.trim().length < 3)
                        ? 'أدخل اسمك الكامل' : null,
                  ),
                  const SizedBox(height: 14),

                  // ── Tab-specific fields ───────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: _tab == 0
                        ? _phoneFields()
                        : _emailFields(),
                  ),

                  const SizedBox(height: 22),

                  // ── Terms ─────────────────────────────
                  _termsRow(),
                  const SizedBox(height: 24),

                  // ── Submit ────────────────────────────
                  _submitBtn(),
                  const SizedBox(height: 20),

                  // ── Login link ────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: RichText(text: const TextSpan(
                        text: 'عندك حساب بالفعل؟  ',
                        style: TextStyle(color: Color(0xFF888888), fontSize: 13.5),
                        children: [TextSpan(
                          text: 'تسجيل الدخول',
                          style: TextStyle(
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.w800,
                          ),
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
      ]),
    );
  }

  // ═══════════════════════════════════════════════════
  //  WIDGETS
  // ═══════════════════════════════════════════════════

  Widget _backBtn() => GestureDetector(
    onTap: () => Navigator.pop(context),
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: const Icon(Icons.arrow_back_ios_new_rounded,
          size: 16, color: Color(0xFF0D1B2A)),
    ),
  );

  Widget _logoChip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF1565C0),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: const [
      Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 16),
      SizedBox(width: 6),
      Text('Yalla Trip',
          style: TextStyle(color: Colors.white, fontSize: 13,
              fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _tabSelector() => Container(
    height: 54,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.07),
          blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: Row(children: [
      _tabItem(0, Icons.phone_android_rounded, 'رقم الهاتف'),
      _tabItem(1, Icons.email_outlined,         'البريد الإلكتروني'),
    ]),
  );

  Widget _tabItem(int idx, IconData icon, String label) {
    final sel = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF1565C0) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }

  // ── Phone fields ──────────────────────────────────────
  Widget _phoneFields() => Column(
    key: const ValueKey('phone'),
    children: [
      // Phone number with Egypt code
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          // Flag + code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(
                  color: Colors.grey.shade200, width: 1.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🇪🇬', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              Text('+20', style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade700, fontSize: 14)),
            ]),
          ),
          Expanded(
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: '01X XXXX XXXX',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
              ),
            ),
          ),
        ]),
      ),
    ],
  );

  // ── Email fields ──────────────────────────────────────
  Widget _emailFields() => Form(
    key: _formKey,
    child: Column(
      key: const ValueKey('email'),
      children: [
        _field(
          ctrl: _emailCtrl,
          hint: 'البريد الإلكتروني',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => (v == null || !v.contains('@'))
              ? 'أدخل بريد إلكتروني صحيح' : null,
        ),
        const SizedBox(height: 14),
        _field(
          ctrl: _passCtrl,
          hint: 'كلمة المرور',
          icon: Icons.lock_outline_rounded,
          obscure: _obscurePass,
          suffix: IconButton(
            icon: Icon(_obscurePass
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
                size: 20, color: Colors.grey.shade400),
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
          ),
          validator: (v) => (v == null || v.length < 6)
              ? 'كلمة المرور 6 أحرف على الأقل' : null,
        ),
        const SizedBox(height: 14),
        _field(
          ctrl: _confirmCtrl,
          hint: 'تأكيد كلمة المرور',
          icon: Icons.lock_outline_rounded,
          obscure: _obscureConf,
          suffix: IconButton(
            icon: Icon(_obscureConf
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
                size: 20, color: Colors.grey.shade400),
            onPressed: () => setState(() => _obscureConf = !_obscureConf),
          ),
          validator: (v) => v != _passCtrl.text
              ? 'كلمتا المرور غير متطابقتين' : null,
        ),
      ],
    ),
  );

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF1565C0)),
        suffixIcon: suffix,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    ),
  );

  Widget _termsRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      GestureDetector(
        onTap: () => setState(() => _agreed = !_agreed),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: _agreed ? const Color(0xFF1565C0) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _agreed ? const Color(0xFF1565C0) : Colors.grey.shade300,
              width: 1.8,
            ),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
          ),
          child: _agreed
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : null,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: RichText(text: const TextSpan(
        text: 'أوافق على  ',
        style: TextStyle(color: Color(0xFF888888), fontSize: 13),
        children: [
          TextSpan(text: 'الشروط والأحكام',
              style: TextStyle(color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w700)),
          TextSpan(text: '  و  '),
          TextSpan(text: 'سياسة الخصوصية',
              style: TextStyle(color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w700)),
        ],
      ))),
    ],
  );

  Widget _submitBtn() {
    final isPhone = _tab == 0;
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _loading ? null : (isPhone ? _registerPhone : _registerEmail),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              const Color(0xFF1565C0).withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
        ),
        child: _loading
            ? const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(
                  isPhone ? 'إرسال رمز التحقق' : 'إنشاء الحساب',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      letterSpacing: 0.2),
                ),
                const SizedBox(width: 8),
                Icon(isPhone
                    ? Icons.sms_outlined
                    : Icons.arrow_forward_rounded,
                    size: 18),
              ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  WAVY BACKGROUND PAINTER
// ═══════════════════════════════════════════════════════════════
class _WavePainter extends CustomPainter {
  final double t;
  _WavePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Soft sand base
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFF5F3EE));

    final p = Paint()..style = PaintingStyle.fill;

    // ── Top-right blue wave ───────────────────────────
    p.color = const Color(0xFF1565C0).withValues(alpha: 0.09);
    final path1 = Path()
      ..moveTo(size.width * 0.4, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.32 + 40 * math.sin(t * math.pi))
      ..cubicTo(
        size.width * 0.75, size.height * 0.28 + 30 * math.sin(t * math.pi),
        size.width * 0.55, size.height * 0.22 + 20 * math.cos(t * math.pi),
        size.width * 0.35, size.height * 0.18 + 15 * math.sin(t * math.pi),
      )
      ..close();
    canvas.drawPath(path1, p);

    // Second top wave — lighter
    p.color = const Color(0xFF1565C0).withValues(alpha: 0.05);
    final path2 = Path()
      ..moveTo(size.width * 0.6, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.18 + 20 * math.cos(t * math.pi))
      ..cubicTo(
        size.width * 0.85, size.height * 0.15,
        size.width * 0.7,  size.height * 0.12,
        size.width * 0.55, size.height * 0.08,
      )
      ..close();
    canvas.drawPath(path2, p);

    // ── Bottom-left orange wave ───────────────────────
    p.color = const Color(0xFFFF6D00).withValues(alpha: 0.08);
    final path3 = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.7, size.height)
      ..lineTo(size.width * 0.65, size.height * 0.82 + 25 * math.sin(t * math.pi))
      ..cubicTo(
        size.width * 0.45, size.height * 0.78 + 20 * math.cos(t * math.pi),
        size.width * 0.2,  size.height * 0.84 + 15 * math.sin(t * math.pi),
        0, size.height * 0.80 + 20 * math.cos(t * math.pi),
      )
      ..close();
    canvas.drawPath(path3, p);

    // Second bottom wave
    p.color = const Color(0xFFFF6D00).withValues(alpha: 0.04);
    final path4 = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.4, size.height)
      ..lineTo(size.width * 0.35, size.height * 0.90 + 15 * math.sin(t * math.pi))
      ..cubicTo(
        size.width * 0.2, size.height * 0.88,
        size.width * 0.1, size.height * 0.92,
        0, size.height * 0.88,
      )
      ..close();
    canvas.drawPath(path4, p);
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t;
}
