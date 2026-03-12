// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Register Page  (Premium Dark Design)
// ═══════════════════════════════════════════════════════════════
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'otp_page.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {

  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  int  _tab         = 0;
  bool _loading     = false;
  bool _obscurePass = true;
  bool _obscureConf = true;

  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  late final AnimationController _bgCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  late final AnimationController _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  @override
  void dispose() {
    _bgCtrl.dispose(); _fadeCtrl.dispose();
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────
  Future<void> _registerPhone() async {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.length < 3) { _err('أدخل اسمك الكامل (3 أحرف على الأقل)'); return; }
    if (phone.length < 9) { _err('أدخل رقم هاتف صحيح'); return; }

    setState(() => _loading = true);
    final raw  = phone.startsWith('0') ? phone.substring(1) : phone;
    final full = '+20$raw';

    await _auth.verifyPhoneNumber(
      phoneNumber: full,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (cred) async {
        await _auth.signInWithCredential(cred);
        await _saveUser(name, '', full);
        if (mounted) _goHome();
      },
      verificationFailed: (e) {
        setState(() => _loading = false);
        _err(e.code == 'invalid-phone-number'
            ? 'رقم الهاتف غير صحيح' : 'حدث خطأ، حاول مرة أخرى');
      },
      codeSent: (verId, token) {
        setState(() => _loading = false);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => OtpPage(
            phoneNumber: full, verificationId: verId,
            resendToken: token, userName: name,
          ),
        ));
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> _registerEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
      await cred.user!.updateDisplayName(_nameCtrl.text.trim());
      await _saveUser(_nameCtrl.text.trim(), _emailCtrl.text.trim(), '');
      if (mounted) _goHome();
    } on FirebaseAuthException catch (e) {
      String msg = 'حدث خطأ، حاول مرة أخرى';
      if (e.code == 'email-already-in-use') msg = 'البريد الإلكتروني مسجل مسبقاً';
      else if (e.code == 'weak-password')   msg = 'كلمة المرور ضعيفة جداً';
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
      'uid': uid, 'name': name, 'email': email,
      'phone': phone, 'role': 'guest',
      'createdAt': FieldValue.serverTimestamp(), 'avatar': '',
    });
  }

  void _goHome() => Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()), (_) => false);

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
            painter: _AuthBgPainterReg(_bgCtrl.value),
            size: size,
          ),
        ),

        SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                  const Text('انضم لينا\nدلوقتي ✨',
                      style: TextStyle(
                        fontSize: 38, fontWeight: FontWeight.w900,
                        color: Colors.white, height: 1.1, letterSpacing: -1,
                      )),
                  const SizedBox(height: 10),
                  Text('إنشاء حساب جديد في ثوانٍ',
                      style: TextStyle(fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 32),

                  // ── Tab ─────────────────────────────
                  _tabSelector(),
                  const SizedBox(height: 24),

                  // ── Name (always) ───────────────────
                  _glassField(
                    ctrl: _nameCtrl,
                    hint: 'الاسم الكامل',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 14),

                  // ── Tab fields ──────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: _tab == 0 ? _phoneFields() : _emailFields(),
                  ),
                  const SizedBox(height: 28),

                  // ── Submit ──────────────────────────
                  _submitBtn(),
                  const SizedBox(height: 20),

                  // ── Login link ──────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: RichText(text: TextSpan(
                        text: 'عندك حساب بالفعل؟  ',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 13.5),
                        children: const [TextSpan(
                          text: 'سجّل دخولك',
                          style: TextStyle(color: Color(0xFF42A5F5),
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFF42A5F5)),
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
          colors: [Color(0xFFFF6D00), Color(0xFFFF8F00)]),
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
    final sel = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: sel ? const LinearGradient(
                colors: [Color(0xFFFF6D00), Color(0xFFFF8F00)]) : null,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: sel ? Colors.white : Colors.white38),
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

  Widget _glassField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? formatters,
  }) => Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    ),
    child: TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyType,
      validator: validator,
      inputFormatters: formatters,
      style: const TextStyle(color: Colors.white, fontSize: 15,
          fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFFFF8F00)),
        suffixIcon: suffix,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 18),
      ),
    ),
  );

  Widget _phoneFields() => Column(
    key: const ValueKey('phone'),
    children: [
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            decoration: BoxDecoration(
                border: Border(right: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08), width: 1.5))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🇪🇬', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              Text('+20', style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
            ]),
          ),
          Expanded(child: TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11)],
            style: const TextStyle(color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '01X XXXX XXXX',
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 18),
            ),
          )),
        ]),
      ),
    ],
  );

  Widget _emailFields() => Form(
    key: _formKey,
    child: Column(key: const ValueKey('email'), children: [
      _glassField(
        ctrl: _emailCtrl, hint: 'البريد الإلكتروني',
        icon: Icons.email_outlined, keyType: TextInputType.emailAddress,
        validator: (v) => (v == null || !v.contains('@'))
            ? 'أدخل بريد إلكتروني صحيح' : null,
      ),
      const SizedBox(height: 14),
      _glassField(
        ctrl: _passCtrl, hint: 'كلمة المرور',
        icon: Icons.lock_outline_rounded, obscure: _obscurePass,
        suffix: IconButton(
          icon: Icon(_obscurePass ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
              size: 20, color: Colors.white38),
          onPressed: () => setState(() => _obscurePass = !_obscurePass),
        ),
        validator: (v) => (v == null || v.length < 6)
            ? 'كلمة المرور 6 أحرف على الأقل' : null,
      ),
      const SizedBox(height: 14),
      _glassField(
        ctrl: _confirmCtrl, hint: 'تأكيد كلمة المرور',
        icon: Icons.lock_outline_rounded, obscure: _obscureConf,
        suffix: IconButton(
          icon: Icon(_obscureConf ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
              size: 20, color: Colors.white38),
          onPressed: () => setState(() => _obscureConf = !_obscureConf),
        ),
        validator: (v) => v != _passCtrl.text
            ? 'كلمتا المرور غير متطابقتين' : null,
      ),
    ]),
  );

  Widget _submitBtn() {
    final isPhone = _tab == 0;
    return GestureDetector(
      onTap: _loading ? null : (isPhone ? _registerPhone : _registerEmail),
      child: Container(
        width: double.infinity, height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _loading
                ? [const Color(0xFFFF6D00).withValues(alpha: 0.5),
                   const Color(0xFFFF8F00).withValues(alpha: 0.5)]
                : [const Color(0xFFFF6D00), const Color(0xFFFF8F00)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: _loading ? [] : [BoxShadow(
            color: const Color(0xFFFF6D00).withValues(alpha: 0.4),
            blurRadius: 20, offset: const Offset(0, 8),
          )],
        ),
        child: Center(child: _loading
            ? const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(isPhone ? 'إرسال رمز التحقق' : 'إنشاء الحساب',
                    style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(width: 8),
                Icon(isPhone ? Icons.sms_outlined : Icons.arrow_forward_rounded,
                    size: 18, color: Colors.white),
              ])),
      ),
    );
  }
}

// ── Background Painter ─────────────────────────────────────────
class _AuthBgPainterReg extends CustomPainter {
  final double t;
  _AuthBgPainterReg(this.t);

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF060D1A));
    final p = Paint()..style = PaintingStyle.fill;

    // Orange orb top right (register = orange themed)
    p.shader = RadialGradient(colors: [
      const Color(0xFFFF6D00).withValues(alpha: 0.38),
      const Color(0xFFFF6D00).withValues(alpha: 0),
    ]).createShader(Rect.fromCircle(
      center: Offset(s.width * (0.90 + 0.06 * math.sin(t * math.pi)),
                     s.height * (0.10 + 0.05 * math.cos(t * math.pi))),
      radius: s.width * 0.6,
    ));
    canvas.drawCircle(
      Offset(s.width * (0.90 + 0.06 * math.sin(t * math.pi)),
             s.height * (0.10 + 0.05 * math.cos(t * math.pi))),
      s.width * 0.6, p,
    );

    // Blue orb bottom left
    p.shader = RadialGradient(colors: [
      const Color(0xFF1565C0).withValues(alpha: 0.30),
      const Color(0xFF1565C0).withValues(alpha: 0),
    ]).createShader(Rect.fromCircle(
      center: Offset(s.width * (0.06 + 0.05 * math.cos(t * math.pi)),
                     s.height * (0.88 + 0.04 * math.sin(t * math.pi))),
      radius: s.width * 0.5,
    ));
    canvas.drawCircle(
      Offset(s.width * (0.06 + 0.05 * math.cos(t * math.pi)),
             s.height * (0.88 + 0.04 * math.sin(t * math.pi))),
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
  bool shouldRepaint(_AuthBgPainterReg o) => o.t != t;
}
