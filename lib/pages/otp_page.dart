// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — OTP Verification Page
//  Firebase Phone Auth — No role selection — always starts as guest
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/constants.dart';
import 'home_page.dart';

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

  @override
  void dispose() {
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
      _showError('أدخل الكود المكون من 6 أرقام كاملاً');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpCode,
      );
      final result = await _auth.signInWithCredential(credential);
      final uid    = result.user!.uid;

      // ── حفظ بيانات المستخدم في Firestore (role = guest دايماً) ──
      final db  = FirebaseFirestore.instance;
      final doc = await db.collection('users').doc(uid).get();

      if (!doc.exists) {
        // تسجيل جديد — إنشاء document بـ role guest
        await db.collection('users').doc(uid).set({
          'uid':       uid,
          'name':      widget.userName.isNotEmpty
                         ? widget.userName
                         : (result.user?.displayName ?? ''),
          'phone':     widget.phoneNumber,
          'role':      'guest',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // مستخدم قديم — حدّث الاسم فقط لو موجود
        if (widget.userName.isNotEmpty) {
          await db.collection('users').doc(uid).update({
            'name':      widget.userName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (widget.userName.isNotEmpty) {
        await result.user?.updateDisplayName(widget.userName);
      }

      if (mounted) {
        HapticFeedback.heavyImpact();
        _goHome();
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'الكود غير صحيح، حاول مرة أخرى';
      if (e.code == 'session-expired') {
        msg = 'انتهت صلاحية الكود، اطلب كوداً جديداً';
      } else if (e.code == 'invalid-verification-code') {
        msg = 'الكود المدخل غير صحيح';
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
        _showSuccess('تم إرسال كود جديد ✅');
      },

      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        if (mounted) { _goHome(); }
      },

      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        _showError('فشل إرسال الكود، حاول مرة أخرى');
      },

      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
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
                        colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
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
