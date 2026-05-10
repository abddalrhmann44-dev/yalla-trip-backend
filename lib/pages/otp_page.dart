// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — OTP Verification Page
//  Firebase Phone Auth — No role selection — always starts as guest
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart' show appSettings;
import '../utils/app_strings.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../widgets/constants.dart';
import 'home_page.dart';
import 'register_page.dart';

// ── Phone-auth provider toggle ───────────────────────────────
// Mirrors the flag in [LoginPage].  When ``false`` (the default
// today) this page verifies the OTP through our own backend
// (WhatsApp / WaAPI); flip to ``true`` to fall back to Firebase
// Phone Auth using the [verificationId] passed in by the caller.
const bool _kUseFirebasePhoneAuth = false;

class OtpPage extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int?   resendToken;
  final String userName;

  const OtpPage({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
    this.userName = '',
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage>
    with SingleTickerProviderStateMixin {

  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _foci =
      List.generate(6, (_) => FocusNode());

  bool   _isLoading   = false;
  bool   _canResend   = false;
  int    _secondsLeft = 60;
  Timer? _timer;
  String _verificationId;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  final _auth = FirebaseAuth.instance;

  _OtpPageState() : _verificationId = '';

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
    _verificationId = widget.verificationId;
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _foci[0].requestFocus();
    });
  }

  void _onLangChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange);
    _timer?.cancel();
    _animCtrl.dispose();
    for (final c in _ctrls) { c.dispose(); }
    for (final f in _foci) { f.dispose(); }
    super.dispose();
  }

  void _startTimer() {
    _secondsLeft = 60;
    _canResend   = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
        if (mounted) { setState(() => _canResend = true); }
      } else {
        if (mounted) { setState(() => _secondsLeft--); }
      }
    });
  }

  String get _otpCode => _ctrls.map((c) => c.text).join();

  Future<void> _verifyOTP() async {
    if (_otpCode.length < 6) {
      _showError(S.otpEnterCode);
      return;
    }
    setState(() => _isLoading = true);
    if (_kUseFirebasePhoneAuth) {
      await _verifyFirebase();
    } else {
      await _verifyWhatsapp();
    }
  }

  /// New default — hand the typed code to our backend, which checks
  /// it against the WhatsApp OTP it issued and returns a JWT pair on
  /// success.
  Future<void> _verifyWhatsapp() async {
    try {
      final res = await AuthService.verifyWhatsappOtp(
        phone: widget.phoneNumber,
        code: _otpCode,
        name: widget.userName,
      );
      if (!mounted) return;
      if (res.error != null) {
        _showError(res.error!);
        for (final c in _ctrls) { c.clear(); }
        _foci[0].requestFocus();
        return;
      }
      HapticFeedback.heavyImpact();
      _routeAfterBackendAuth(isNew: res.isNewUser);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Legacy Firebase Phone Auth verification, kept behind the
  /// [_kUseFirebasePhoneAuth] flag for emergency fallback only.
  Future<void> _verifyFirebase() async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpCode,
      );
      final result = await _auth.signInWithCredential(credential);

      // ── Exchange Firebase token for backend JWT ──
      final fbUser = result.user;
      if (fbUser != null) {
        if (widget.userName.isNotEmpty) {
          await fbUser.updateDisplayName(widget.userName);
        }
        final idToken = await fbUser.getIdToken();
        if (idToken != null) {
          await AuthService.exchangeFirebaseToken(idToken);
        }
      }

      if (mounted) {
        HapticFeedback.heavyImpact();
        _routeAfterAuth(result);
      }
    } on FirebaseAuthException catch (e) {
      String msg = S.otpWrong;
      if (e.code == 'session-expired') {
        msg = S.otpExpired;
      } else if (e.code == 'invalid-verification-code') {
        msg = S.otpInvalid;
      }
      _showError(msg);
      for (final c in _ctrls) { c.clear(); }
      _foci[0].requestFocus();
    } finally {
      if (mounted) { setState(() => _isLoading = false); }
    }
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;
    setState(() => _isLoading = true);

    if (_kUseFirebasePhoneAuth) {
      await _resendFirebase();
    } else {
      await _resendWhatsapp();
    }
  }

  /// New default — ask the backend to send a fresh WhatsApp OTP.
  Future<void> _resendWhatsapp() async {
    final err = await AuthService.startWhatsappOtp(widget.phoneNumber);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (err != null) {
      _showError(err);
      return;
    }
    _startTimer();
    for (final c in _ctrls) { c.clear(); }
    _foci[0].requestFocus();
    _showSuccess(S.otpResent);
  }

  Future<void> _resendFirebase() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      forceResendingToken: widget.resendToken,

      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isLoading      = false;
        });
        _startTimer();
        for (final c in _ctrls) { c.clear(); }
        _foci[0].requestFocus();
        _showSuccess(S.otpResent);
      },

      verificationCompleted: (PhoneAuthCredential credential) async {
        final result = await _auth.signInWithCredential(credential);
        final fbUser = result.user;
        if (fbUser != null) {
          final idToken = await fbUser.getIdToken();
          if (idToken != null) {
            await AuthService.exchangeFirebaseToken(idToken);
          }
        }
        if (mounted) _routeAfterAuth(result);
      },

      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        _showError(S.otpResendFailed);
      },

      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  /// Route users based on whether this is their first successful auth.
  ///
  /// * New users   → [RegisterPage]   (collect name + optional email).
  /// * Returning   → [HomePage]       (straight into the app).
  void _routeAfterAuth(UserCredential result) {
    final isNew = result.additionalUserInfo?.isNewUser ?? false;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => isNew ? const RegisterPage() : const HomePage(),
      ),
      (_) => false,
    );
  }

  /// Backend-driven counterpart of [_routeAfterAuth] — used when we
  /// authenticate through the WhatsApp OTP flow and therefore have
  /// no [UserCredential] to inspect.  ``isNew`` comes from the
  /// backend's verify-otp response (placeholder name + no email).
  void _routeAfterBackendAuth({required bool isNew}) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => isNew ? const RegisterPage() : const HomePage(),
      ),
      (_) => false,
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF8A3D)]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 20, offset: const Offset(0, 6),
                    )],
                  ),
                  child: const Icon(Icons.sms_rounded,
                      color: Colors.white, size: 36),
                ),

                const SizedBox(height: 24),

                const Text('تحقق من هاتفك',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    )),

                const SizedBox(height: 10),

                Text(
                  'تم إرسال كود التحقق إلى\n${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 36),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) => _otpField(i)),
                ),

                const SizedBox(height: 32),

                _canResend
                    ? GestureDetector(
                        onTap: _resendOTP,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded,
                                  color: AppColors.primary, size: 16),
                              SizedBox(width: 6),
                              Text('إرسال كود جديد',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ]),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_outlined,
                              size: 15, color: AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Text(
                            'إعادة الإرسال بعد $_secondsLeft ثانية',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ]),

                const SizedBox(height: 36),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text('تأكيد الكود ✓',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'رقم خاطئ؟ تغيير الرقم',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _otpField(int index) {
    return Container(
      width: 46, height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _foci[index].hasFocus
              ? AppColors.primary
              : AppColors.border,
          width: _foci[index].hasFocus ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _foci[index].hasFocus
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _ctrls[index],
        focusNode: _foci[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (val) {
          if (val.isNotEmpty) {
            if (index < 5) {
              _foci[index + 1].requestFocus();
            } else {
              _foci[index].unfocus();
              _verifyOTP();
            }
          } else {
            if (index > 0) {
              _foci[index - 1].requestFocus();
            }
          }
          setState(() {});
        },
        onTap: () => setState(() {}),
      ),
    );
  }
}
