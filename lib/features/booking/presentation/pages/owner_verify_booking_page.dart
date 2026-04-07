// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Owner Verify Booking Page
//  Owner enters booking code → sees full booking breakdown
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../widgets/constants.dart';
import '../../data/models/booking_model.dart';
import '../providers/booking_providers.dart';
import '../widgets/pricing_breakdown_card.dart';

const _kOcean = Color(0xFF1565C0);
const _kGreen = Color(0xFF4CAF50);
const _kRed   = Color(0xFFEF5350);

class OwnerVerifyBookingPage extends ConsumerStatefulWidget {
  const OwnerVerifyBookingPage({super.key});
  @override
  ConsumerState<OwnerVerifyBookingPage> createState() =>
      _OwnerVerifyBookingPageState();
}

class _OwnerVerifyBookingPageState
    extends ConsumerState<OwnerVerifyBookingPage> {
  final _codeCtrl = TextEditingController();
  BookingModel? _result;
  bool _loading = false;
  bool _notFound = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _notFound = false;
      _result = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    final booking = await ref
        .read(ownerVerificationServiceProvider)
        .verifyBookingCode(code, ownerId: user?.uid);

    setState(() {
      _loading = false;
      _result = booking;
      _notFound = booking == null;
    });

    if (booking != null) HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: context.kCard,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: context.kText, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('تحقق من كود الحجز',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        centerTitle: true,
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // ── Input ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.kBorder),
          ),
          child: Column(children: [
            const Icon(Icons.qr_code_scanner_rounded,
                size: 48, color: _kOcean),
            const SizedBox(height: 14),
            Text('أدخل كود الحجز',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.kText)),
            const SizedBox(height: 6),
            Text('الكود مكون من 8 أحرف',
                style: TextStyle(fontSize: 13, color: context.kSub)),
            const SizedBox(height: 18),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              maxLength: 8,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: context.kText),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'XXXXXXXX',
                hintStyle: TextStyle(
                    color: context.kBorder,
                    letterSpacing: 4,
                    fontSize: 24),
                filled: true,
                fillColor: context.kSand,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: context.kBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: context.kBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: _kOcean, width: 2)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _loading ? null : _verify,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _kOcean,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text('تحقق',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ),
          ]),
        ),

        // ── Error state ─────────────────────────────────────
        if (_notFound) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kRed.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded,
                  size: 28, color: _kRed),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('كود غير صحيح',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.kText)),
                  const SizedBox(height: 4),
                  Text('تأكد من الكود وحاول تاني',
                      style:
                          TextStyle(fontSize: 12, color: context.kSub)),
                ]),
              ),
            ]),
          ),
        ],

        // ── Result ──────────────────────────────────────────
        if (_result != null) ...[
          const SizedBox(height: 20),
          _buildResult(context, _result!),
        ],
      ]),
    );
  }

  Widget _buildResult(BuildContext context, BookingModel b) {
    final dateStr = DateFormat('dd/MM/yyyy').format(b.bookingDate);
    return Column(children: [
      // Success badge
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kGreen.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded,
              size: 28, color: _kGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text('حجز مؤكد ✅',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: context.kText)),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      // Details card
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.kBorder),
        ),
        child: Column(children: [
          _detailRow(context, 'اسم الضيف', b.userName),
          _detailRow(context, 'المكان', b.placeName),
          _detailRow(context, 'التاريخ', dateStr),
          _detailRow(context, 'عدد الأشخاص', '${b.numberOfPeople}'),
          _detailRow(context, 'طريقة الدفع', b.paymentMethod),
          _detailRow(context, 'الحالة', b.status),
        ]),
      ),
      const SizedBox(height: 16),

      PricingBreakdownCard(
        basePrice: b.basePrice,
        discount: b.discountApplied,
        subtotal: b.finalPrice,
        appFee: b.appFeeAmount,
        ownerEarnings: b.ownerEarnings,
        appFeePercent: b.appFeePercent,
        promoCode: b.promoCodeUsed,
        showOwnerEarnings: true,
      ),
    ]);
  }

  Widget _detailRow(BuildContext context, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.kSub)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.kText)),
        ]),
      );
}
