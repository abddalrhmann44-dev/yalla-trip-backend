// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Register Page  (Clean Minimal White — matches Welcome)
// ═══════════════════════════════════════════════════════════════
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
    with SingleTickerProviderStateMixin {

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

  late final AnimationController _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

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
    _fadeCtrl.dispose();
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────
  Future<void> _registerPhone() async {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.length < 3)  { _err('أدخل اسمك الكامل (3 أحرف على الأقل)'); return; }
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fade,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Back ────────────────────────────
                _BackBtn(onTap: () => Navigator.pop(context)),
                const SizedBox(height: 32),

                // ── Logo + headline ──────────────────
                _MiniLogo(),
                const SizedBox(height: 20),

                const Text('إنشاء حساب',
                    style: TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w900,
                      color: Color(0xFF0D1B2A), letterSpacing: -1,
                    )),
                const SizedBox(height: 6),
                Text('انضم لـ Yalla Trip واكتشف أجمل الوجهات',
                    style: TextStyle(fontSize: 14,
                        color: const Color(0xFF0D1B2A).withValues(alpha: 0.4),
                        fontWeight: FontWeight.w500)),

                const SizedBox(height: 32),

                // ── Tab ─────────────────────────────
                _TabSelector(
                  selected: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: 24),

                // ── Name (always) ────────────────────
                _Field(
                  ctrl: _nameCtrl, hint: 'الاسم الكامل',
                  icon: Icons.person_outline_rounded,
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'أدخل اسمك الكامل' : null,
                ),
                const SizedBox(height: 14),

                // ── Tab fields ───────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: _tab == 0 ? _phoneFields() : _emailFields(),
                ),
                const SizedBox(height: 28),

                // ── Submit ───────────────────────────
                _PrimaryBtn(
                  label: _tab == 0 ? 'إرسال رمز التحقق' : 'إنشاء الحساب',
                  icon: _tab == 0
                      ? Icons.sms_outlined
                      : Icons.arrow_forward_rounded,
                  loading: _loading,
                  onTap: _tab == 0 ? _registerPhone : _registerEmail,
                ),
                const SizedBox(height: 24),

                // ── Login link ───────────────────────
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: RichText(text: TextSpan(
                      text: 'عندك حساب بالفعل؟  ',
                      style: TextStyle(
                          color: const Color(0xFF0D1B2A).withValues(alpha: 0.4),
                          fontSize: 13.5),
                      children: const [TextSpan(
                        text: 'سجّل دخولك',
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
    );
  }

  // ── Form widgets ─────────────────────────────────────────────

  Widget _phoneFields() => Column(
    key: const ValueKey('phone'),
    children: [
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF0D1B2A).withValues(alpha: 0.07)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            decoration: BoxDecoration(
                border: Border(right: BorderSide(
                    color: const Color(0xFF0D1B2A).withValues(alpha: 0.07)))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🇪🇬', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              Text('+20',
                  style: TextStyle(fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D1B2A).withValues(alpha: 0.6),
                      fontSize: 14)),
            ]),
          ),
          Expanded(child: TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11)],
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                color: Color(0xFF0D1B2A)),
            decoration: InputDecoration(
              hintText: '01X XXXX XXXX',
              hintStyle: TextStyle(
                  color: const Color(0xFF0D1B2A).withValues(alpha: 0.3),
                  fontSize: 14),
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
      _Field(
        ctrl: _emailCtrl, hint: 'البريد الإلكتروني',
        icon: Icons.email_outlined,
        keyType: TextInputType.emailAddress,
        validator: (v) => (v == null || !v.contains('@'))
            ? 'أدخل بريد إلكتروني صحيح' : null,
      ),
      const SizedBox(height: 14),
      _Field(
        ctrl: _passCtrl, hint: 'كلمة المرور',
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
        validator: (v) => (v == null || v.length < 6)
            ? 'كلمة المرور 6 أحرف على الأقل' : null,
      ),
      const SizedBox(height: 14),
      _Field(
        ctrl: _confirmCtrl, hint: 'تأكيد كلمة المرور',
        icon: Icons.lock_outline_rounded,
        obscure: _obscureConf,
        suffix: IconButton(
          icon: Icon(_obscureConf
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
              size: 20,
              color: const Color(0xFF0D1B2A).withValues(alpha: 0.35)),
          onPressed: () => setState(() => _obscureConf = !_obscureConf),
        ),
        validator: (v) => v != _passCtrl.text
            ? 'كلمتا المرور غير متطابقتين' : null,
      ),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  SHARED WIDGETS (same as login_page)
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

class _MiniLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 48, height: 48,
    decoration: BoxDecoration(
      color: const Color(0xFF1565C0),
      borderRadius: BorderRadius.circular(15),
      boxShadow: [BoxShadow(
        color: const Color(0xFF1565C0).withValues(alpha: 0.20),
        blurRadius: 12, offset: const Offset(0, 5),
      )],
    ),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.flight_takeoff_rounded,
            color: Colors.white, size: 20),
        const SizedBox(height: 2),
        Container(width: 16, height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6D00),
            borderRadius: BorderRadius.circular(1))),
      ]),
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
    this.obscure = false, this.suffix, this.keyType, this.validator,
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
