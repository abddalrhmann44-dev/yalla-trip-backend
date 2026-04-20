// ═══════════════════════════════════════════════════════════════
//  TALAA — Cancel Booking Sheet
//  Fetches the refund quote and confirms the cancellation.
//  Returns the updated BookingModel on success, or null on cancel.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/booking_model.dart';
import '../models/refund_quote.dart';
import '../services/booking_service.dart';
import '../utils/api_client.dart';
import '../utils/error_handler.dart';
import 'constants.dart';

const _kOcean = Color(0xFF1B4D5C);
const _kGreen = Color(0xFF2E7D32);
const _kRed = Color(0xFFD32F2F);
const _kAmber = Color(0xFFF57C00);

/// Show the cancel-booking bottom sheet for [booking] and await
/// confirmation.  Returns the refreshed booking row on success.
Future<BookingModel?> showCancelBookingSheet(
  BuildContext context,
  BookingModel booking,
) {
  return showModalBottomSheet<BookingModel?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CancelBookingSheet(booking: booking),
  );
}

class _CancelBookingSheet extends StatefulWidget {
  final BookingModel booking;
  const _CancelBookingSheet({required this.booking});

  @override
  State<_CancelBookingSheet> createState() => _CancelBookingSheetState();
}

class _CancelBookingSheetState extends State<_CancelBookingSheet> {
  bool _loadingQuote = true;
  bool _submitting = false;
  String? _error;
  RefundQuote? _quote;
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuote() async {
    try {
      final q = await BookingService.cancelPreview(widget.booking.id);
      if (!mounted) return;
      setState(() {
        _quote = q;
        _loadingQuote = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.getMessage(e);
        _loadingQuote = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل معلومات الاسترداد';
        _loadingQuote = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final updated = await BookingService.cancelBooking(
        widget.booking.id,
        reason: _reasonCtrl.text,
      );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.getMessage(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: context.kCard,
            borderRadius: BorderRadius.circular(24),
          ),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loadingQuote) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: _kOcean)),
      );
    }
    if (_quote == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: _kRed, size: 42),
          const SizedBox(height: 12),
          Text(
            _error ?? 'تعذر تحميل معلومات الاسترداد',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.kText),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      );
    }

    final q = _quote!;
    final accent = q.isFullRefund
        ? _kGreen
        : q.isPartial
            ? _kAmber
            : _kRed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: context.kBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Title
        Text(
          'إلغاء الحجز',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: context.kText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'كود ${widget.booking.bookingCode}',
          style: TextStyle(fontSize: 12, color: context.kSub),
        ),
        const SizedBox(height: 18),

        // Refund card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    q.noRefund
                        ? Icons.block_rounded
                        : q.isFullRefund
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                    color: accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    q.noRefund
                        ? 'لا يوجد استرداد'
                        : 'استرداد ${q.refundablePercent}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'سياسة ${policyLabelAr(q.policy)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${q.refundAmount.toStringAsFixed(0)} ج.م',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                q.reasonAr,
                style: TextStyle(
                  fontSize: 12,
                  color: context.kSub,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Text(
          'سبب الإلغاء (اختياري)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: context.kText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.kSand,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.kBorder),
          ),
          child: TextField(
            controller: _reasonCtrl,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'ما سبب إلغاء الحجز؟',
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ),

        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kOcean,
                    side: const BorderSide(color: _kOcean, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'تراجع',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRed,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'تأكيد الإلغاء',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
