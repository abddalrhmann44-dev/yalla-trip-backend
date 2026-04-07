// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Booking Summary Page
//  Shown after successful booking — displays code + breakdown
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../widgets/constants.dart';
import '../../data/models/booking_model.dart';
import '../widgets/pricing_breakdown_card.dart';

const _kOcean = Color(0xFF1565C0);
const _kGreen = Color(0xFF4CAF50);

class BookingSummaryPage extends StatelessWidget {
  final BookingModel booking;
  const BookingSummaryPage({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('EEEE, d MMMM yyyy', 'ar').format(booking.bookingDate);

    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: context.kCard,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: context.kText, size: 22),
          onPressed: () =>
              Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        title: Text('تم الحجز بنجاح',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        centerTitle: true,
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // ── Success banner ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _kGreen.withValues(alpha: 0.08),
                _kOcean.withValues(alpha: 0.06),
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: _kGreen, size: 40),
            ),
            const SizedBox(height: 14),
            Text('تم تأكيد حجزك! 🎉',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: context.kText)),
            const SizedBox(height: 6),
            Text('احفظ كود الحجز لتقديمه عند الوصول',
                style: TextStyle(fontSize: 13, color: context.kSub)),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Booking code ────────────────────────────────────
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: booking.bookingCode));
            HapticFeedback.mediumImpact();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('تم نسخ كود الحجز',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              backgroundColor: _kOcean,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              margin: const EdgeInsets.all(16),
            ));
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kOcean.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kOcean.withValues(alpha: 0.2)),
            ),
            child: Column(children: [
              Text('كود الحجز',
                  style: TextStyle(fontSize: 13, color: context.kSub)),
              const SizedBox(height: 8),
              Text(booking.bookingCode,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: _kOcean,
                    letterSpacing: 4,
                  )),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.copy_rounded, size: 14, color: context.kSub),
                const SizedBox(width: 4),
                Text('اضغط للنسخ',
                    style: TextStyle(fontSize: 12, color: context.kSub)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // ── Details ─────────────────────────────────────────
        _infoCard(context, [
          _infoRow(context, '📍', 'المكان', booking.placeName),
          _infoRow(context, '📅', 'التاريخ', dateStr),
          _infoRow(context, '👥', 'عدد الأشخاص',
              '${booking.numberOfPeople}'),
          _infoRow(context, '💳', 'الدفع', booking.paymentMethod),
          if (booking.promoCodeUsed.isNotEmpty)
            _infoRow(
                context, '🏷️', 'كود الخصم', booking.promoCodeUsed),
        ]),
        const SizedBox(height: 20),

        // ── Pricing breakdown ───────────────────────────────
        PricingBreakdownCard(
          basePrice: booking.basePrice,
          discount: booking.discountApplied,
          subtotal: booking.finalPrice,
          appFee: booking.appFeeAmount,
          ownerEarnings: booking.ownerEarnings,
          appFeePercent: booking.appFeePercent,
          promoCode: booking.promoCodeUsed,
        ),
        const SizedBox(height: 32),

        // ── Back button ─────────────────────────────────────
        GestureDetector(
          onTap: () =>
              Navigator.of(context).popUntil((r) => r.isFirst),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _kOcean,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('العودة للصفحة الرئيسية',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900)),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _infoCard(BuildContext context, List<Widget> rows) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.kBorder),
        ),
        child: Column(children: rows),
      );

  Widget _infoRow(
          BuildContext context, String emoji, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.kSub)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.kText)),
          ),
        ]),
      );
}
