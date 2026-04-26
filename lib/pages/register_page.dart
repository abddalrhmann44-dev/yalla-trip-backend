// ═══════════════════════════════════════════════════════════════
//  TALAA — Register Page  (Airbnb-minimal redesign)
//  Profile completion step for NEW users after phone OTP / Google.
//  White background, no hero image — just typography + form fields.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/app_strings.dart';
import '../main.dart' show userProvider, appSettings;
import 'home_page.dart';
import 'terms_page.dart';
import 'terms_acceptance_page.dart';

// ── Design tokens (match LoginPage) ──────────────────────────
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

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    // Prefill from Firebase if Google sign-in already provided data.
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      if ((u.displayName ?? '').isNotEmpty) _nameCtrl.text = u.displayName!;
      if ((u.email ?? '').isNotEmpty) _emailCtrl.text = u.email!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  //  ACTIONS
  // ══════════════════════════════════════════════════════════════
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      // Defensive: button is disabled when not agreed, but guard
      // anyway in case it's invoked programmatically.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(appSettings.arabic
            ? 'لازم توافق على الشروط أولاً'
            : 'You must accept the Terms first'),
        backgroundColor: _T.error,
      ));
      return;
    }

    // Persist the consent so the post-login Terms gate doesn't ask again.
    await TermsAcceptancePage.markAccepted();

    setState(() => _loading = true);
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    try {
      // 1) Update Firebase display name so it shows up in auth UIs.
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null && name.isNotEmpty) {
        await fbUser.updateDisplayName(name);
      }

      // 2) Patch the backend profile via the existing REST endpoint.
      final updates = <String, dynamic>{'name': name};
      if (email.isNotEmpty) updates['email'] = email;
      await userProvider.updateProfile(updates);
    } catch (_) {
      // Non-blocking: even if the backend patch fails we still let the
      // user into the app — they can retry the profile edit later.
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (_) => false,
    );
  }

  /// Abandon profile completion — sign out and return to HomePage as guest.
  Future<void> _cancel() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {/* best-effort */}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (_) => false,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          // ── Top bar: close (×) ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              const Spacer(),
              _IconBtn(icon: Icons.close_rounded, onTap: _cancel),
            ]),
          ),

          // ── Form body ─────────────────────────────────────
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  const SizedBox(height: 16),
                  Text(
                    S.registerTitle,
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
                    S.registerSub,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _T.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Full name section ────────────────────
                  const _Label('الاسم الكامل'),
                  const SizedBox(height: 8),
                  _Field(
                    ctrl: _nameCtrl,
                    hint: 'مثال: أحمد محمد',
                    autofillHints: const [AutofillHints.name],
                    validator: (v) => (v == null || v.trim().length < 3)
                        ? 'أدخل اسمك الكامل (3 أحرف على الأقل)'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اكتب اسمك زي ما هو في البطاقة عشان نقدر نأكد حجوزاتك.',
                    style: const TextStyle(
                        fontSize: 12, color: _T.muted, height: 1.5),
                  ),

                  const SizedBox(height: 22),

                  // ── Email section ────────────────────────
                  _Label(S.emailOptional),
                  const SizedBox(height: 8),
                  _Field(
                    ctrl: _emailCtrl,
                    hint: 'name@example.com',
                    keyType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) {
                      if (v == null || v.isEmpty) return null; // optional
                      final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(v.trim());
                      return ok ? null : 'أدخل بريد إلكتروني صحيح';
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    S.emailWhy,
                    style: const TextStyle(
                        fontSize: 12, color: _T.muted, height: 1.5),
                  ),

                  const SizedBox(height: 28),

                  // ── Terms acceptance (must be ticked) ────
                  _TermsCheckbox(
                    checked: _agreed,
                    onChanged: (v) => setState(() => _agreed = v),
                    onOpenTerms: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TermsPage(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _PrimaryBtn(
                    label: S.registerAction,
                    loading: _loading,
                    enabled: _agreed,
                    onTap: _submit,
                  ),

                  const SizedBox(height: 12),
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

/// Standard single-line input with focused state matching Airbnb style.
class _Field extends StatefulWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType? keyType;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  const _Field({
    required this.ctrl,
    required this.hint,
    this.keyType,
    this.autofillHints,
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
          autofillHints: widget.autofillHints,
          validator: widget.validator,
          cursorColor: _T.primary,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _T.navy),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(
                color: _T.soft,
                fontSize: 14,
                fontWeight: FontWeight.w500),
            border: InputBorder.none,
            errorStyle: const TextStyle(
                fontSize: 12,
                color: _T.error,
                fontWeight: FontWeight.w600),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          ),
        ),
      );
}

/// Circular icon button (× to cancel, etc.).
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

/// Primary full-width button with orange gradient. Disabled state
/// (no Terms accepted) renders as muted grey to make it obvious why
/// the button isn't tappable.
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

/// Mandatory Terms checkbox shown above the primary action. The full
/// policy is reachable by tapping the highlighted phrases inside the
/// label, which navigates to [TermsPage].
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
    final linkStyle = const TextStyle(
      fontSize: 13,
      height: 1.55,
      fontWeight: FontWeight.w700,
      color: _T.navy,
      decoration: TextDecoration.underline,
      decorationColor: _T.soft,
    );
    final body = const TextStyle(
      fontSize: 13,
      height: 1.55,
      color: _T.muted,
      fontWeight: FontWeight.w500,
    );
    final tap = TapGestureRecognizer()..onTap = onOpenTerms;
    final richText = ar
        ? RichText(
            text: TextSpan(style: body, children: [
              const TextSpan(text: 'قرأت ووافقت على '),
              TextSpan(
                  text: 'شروط الخدمة وسياسة الخصوصية',
                  style: linkStyle,
                  recognizer: tap),
              const TextSpan(text: '، وأقرّ بأن عمري 18 عاماً أو أكثر.'),
            ]),
          )
        : RichText(
            text: TextSpan(style: body, children: [
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
