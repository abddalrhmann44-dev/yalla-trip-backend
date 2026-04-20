// ═══════════════════════════════════════════════════════════════
//  TALAA — Phone Verification (Wave 23)
//
//  Two-step flow:
//    1. User types their Egyptian mobile number → POST /me/phone/start-otp
//    2. User types the 6-digit code → POST /me/phone/verify-otp
//
//  On success the page pops `true` so the caller can refresh the user
//  profile / proceed with the gated action (e.g. publishing a chalet).
// ═══════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/chat_service.dart';
import '../utils/api_client.dart';
import '../utils/error_handler.dart';
import '../widgets/constants.dart';

class PhoneVerificationPage extends StatefulWidget {
  /// Optional pre-filled phone (e.g. from User.phone) so the owner
  /// doesn't have to retype it if they already saved one in their
  /// profile but hasn't verified it yet.
  final String? initialPhone;

  /// Short explanation of *why* verification is required — shown at
  /// the top of the page.  Defaults to the generic owner-onboarding
  /// copy.
  final String? reasonAr;

  const PhoneVerificationPage({
    super.key,
    this.initialPhone,
    this.reasonAr,
  });

  @override
  State<PhoneVerificationPage> createState() => _PhoneVerificationPageState();
}

class _PhoneVerificationPageState extends State<PhoneVerificationPage> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _loading = false;
  bool _codeSent = false;
  String? _error;
  String? _normalizedPhone; // what the backend echoed back
  int _secondsLeft = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneCtrl.text = widget.initialPhone!;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────
  Future<void> _sendCode() async {
    final raw = _phoneCtrl.text.trim();
    if (raw.length < 6) {
      setState(() => _error = 'ادخل رقم موبايل صحيح');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final normalised = await PhoneOtpService.startOtp(raw);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _normalizedPhone = normalised;
        _secondsLeft = 60;
      });
      _startCountdown();
    } on ApiException catch (e) {
      setState(() => _error = ErrorHandler.getMessage(e));
    } catch (_) {
      setState(() => _error = 'تعذّر إرسال الكود. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'الكود يجب أن يكون 6 أرقام');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PhoneOtpService.verifyOtp(
        _normalizedPhone ?? _phoneCtrl.text,
        code,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: AppColors.success,
        content: Text('تم توثيق رقم الموبايل بنجاح ✅'),
      ));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = ErrorHandler.getMessage(e));
    } catch (_) {
      setState(() => _error = 'تعذّر التحقق من الكود');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startCountdown() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 0) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  // ── UI ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text('توثيق رقم الموبايل',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Reason banner ───────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      width: 1.5),
                ),
                child: Row(children: [
                  const Icon(Icons.verified_user_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.reasonAr ??
                          'وثّق رقم موبايلك لتتمكن من استقبال رسائل الضيوف وإنشاء حجوزات مؤكدة.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Phone field ─────────────────────────────────
              const Text('رقم الموبايل',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                enabled: !_codeSent,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]')),
                ],
                decoration: InputDecoration(
                  hintText: '01012345678',
                  prefixIcon: const Icon(Icons.phone_android_rounded,
                      color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              if (!_codeSent)
                FilledButton(
                  onPressed: _loading ? null : _sendCode,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('إرسال كود التحقق',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800)),
                ),

              // ── Code field ─────────────────────────────────
              if (_codeSent) ...[
                Text(
                  'أرسلنا كوداً مكوّناً من 6 أرقام إلى $_normalizedPhone',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: AppColors.primary,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    hintText: '------',
                    filled: true,
                    fillColor: AppColors.white,
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _loading ? null : _verifyCode,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('تأكيد الكود',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: (_secondsLeft > 0 || _loading)
                        ? null
                        : () {
                            setState(() {
                              _codeSent = false;
                              _codeCtrl.clear();
                            });
                          },
                    child: Text(
                      _secondsLeft > 0
                          ? 'إعادة الإرسال خلال ${_secondsLeft}s'
                          : 'إعادة إرسال الكود',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                        width: 1.5),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
