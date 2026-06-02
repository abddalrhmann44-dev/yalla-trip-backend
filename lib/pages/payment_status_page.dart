// ═══════════════════════════════════════════════════════════════
//  TALAA — Payment Status Page
//  Polls the backend after the user returns from the gateway web
//  view and shows a success / failure / pending screen.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/booking_model.dart';
import '../models/payment_model.dart';
import '../services/booking_service.dart';
import '../services/payment_service.dart';
import '../utils/api_client.dart';
import '../utils/error_handler.dart';
import '../widgets/constants.dart';
import 'home_page.dart';
import 'payment_webview_page.dart';

const _kOcean = Color(0xFFB54414);
const _kGreen = Color(0xFF2E7D32);
const _kRed = Color(0xFFD32F2F);
const _kAmber = Color(0xFFF57C00);

class PaymentStatusPage extends StatefulWidget {
  final int paymentId;

  /// Optional – surfaced to the user so they can re-open the gateway
  /// page without going all the way back to method selection.
  final String? checkoutUrl;

  /// Optional – the voucher reference number returned by Fawry so the
  /// user can pay at a physical outlet later.
  final String? fawryReference;

  const PaymentStatusPage({
    super.key,
    required this.paymentId,
    this.checkoutUrl,
    this.fawryReference,
  });

  @override
  State<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends State<PaymentStatusPage> {
  PaymentStatus? _status;
  BookingModel? _booking;
  String? _error;
  Timer? _poller;
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    _fetchOnce();
    _poller = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _fetchOnce(),
    );
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _fetchOnce() async {
    try {
      final s = await PaymentService.getPayment(widget.paymentId);
      if (!mounted) return;
      setState(() {
        _status = s;
        _error = null;
        _firstLoad = false;
      });
      if (s.isTerminal) {
        _poller?.cancel();
        if (s.state == PayState.paid) {
          HapticFeedback.heavyImpact();
          // Fetch booking detail to reveal owner contact phone.
          _fetchBookingContact(s.bookingId);
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.getMessage(e);
        _firstLoad = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحديث حالة الدفع';
        _firstLoad = false;
      });
    }
  }

  Future<void> _fetchBookingContact(int bookingId) async {
    try {
      final b = await BookingService.getBookingDetail(bookingId);
      if (!mounted) return;
      setState(() => _booking = b);
    } catch (_) {
      // Non-critical — success screen still shows without phone.
    }
  }

  Future<void> _reopenCheckout() async {
    final url = widget.checkoutUrl ?? _status?.checkoutUrl;
    if (url == null || url.isEmpty) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaymentWebViewPage(checkoutUrl: url),
      ),
    );
    // Force an immediate poll on return so the UI snaps to the new
    // state without waiting up to 4 seconds for the timer.
    if (mounted) await _fetchOnce();
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (_) => false,
    );
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
          onPressed: _goHome,
        ),
        title: Text(
          'حالة الدفع',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: context.kText,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _firstLoad ? _buildLoading() : _buildBody(),
      ),
    );
  }

  Widget _buildLoading() => const Center(
        child: CircularProgressIndicator(color: _kOcean),
      );

  Widget _buildBody() {
    final s = _status;
    if (s == null) {
      return _buildError(
        title: 'تعذر تحميل حالة الدفع',
        body: _error ?? 'حاول مرة أخرى بعد لحظات',
      );
    }

    switch (s.state) {
      case PayState.paid:
        return _buildSuccess(s);
      case PayState.failed:
        return _buildFailure(s);
      case PayState.expired:
        return _buildError(
          title: 'انتهت صلاحية الدفع',
          body: 'الرجاء إنشاء عملية دفع جديدة للحجز.',
        );
      case PayState.cancelled:
        return _buildError(
          title: 'تم إلغاء عملية الدفع',
          body: 'يمكنك المحاولة مرة أخرى من صفحة الحجز.',
        );
      case PayState.refunded:
        return _buildError(
          title: 'تم استرداد المبلغ',
          body: 'تم رد ${s.amount.toStringAsFixed(0)} ${s.currency}',
        );
      case PayState.processing:
      case PayState.pending:
        return _buildPending(s);
    }
  }

  // ── success ────────────────────────────────────────────────
  Widget _buildSuccess(PaymentStatus s) {
    final ownerPhone = _booking?.ownerContactPhone;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          _circleIcon(Icons.check_rounded, _kGreen),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'تم الدفع بنجاح 🎉',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: context.kText,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'تم تأكيد حجزك، شكراً لاستخدامك طلعة ✨',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.kSub),
            ),
          ),
          const SizedBox(height: 24),
          _amountCard(s, _kGreen),
          const SizedBox(height: 16),
          // Owner phone — shown only after payment is confirmed.
          if (ownerPhone != null && ownerPhone.isNotEmpty)
            _ownerPhoneCard(ownerPhone)
          else if (_booking != null)
            // Booking loaded but no phone on file.
            _noPhoneNote(),
          const SizedBox(height: 32),
          _primaryButton('الرجوع للرئيسية', _goHome),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _ownerPhoneCard(String phone) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_rounded,
                    color: _kGreen, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'رقم تليفون صاحب العقار',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B5E20)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _kGreen.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(
                    phone,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Color(0xFF1B5E20)),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: phone));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('تم نسخ الرقم'),
                        backgroundColor: _kGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.copy_rounded,
                        color: _kGreen, size: 18),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            const Text(
              '🔒 ظهر هذا الرقم لأن دفعك اكتمل — لا تشاركه مع أحد',
              style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF388E3C)),
            ),
          ],
        ),
      );

  Widget _noPhoneNote() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.kBorder),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFFF6B35), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'صاحب العقار لم يضف رقم تليفون بعد — تواصل معه عبر الشات',
              style: TextStyle(fontSize: 12, color: context.kSub),
            ),
          ),
        ]),
      );

  // ── pending / processing ──────────────────────────────────
  Widget _buildPending(PaymentStatus s) {
    final isFawryVoucher =
        s.provider == PayProvider.fawry && s.method == PayMethod.fawryVoucher;
    final ref = widget.fawryReference ?? s.providerRef;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        _circleIcon(Icons.access_time_rounded, _kAmber, pulse: true),
        const SizedBox(height: 20),
        Center(
          child: Text(
            isFawryVoucher ? 'بانتظار الدفع في فوري' : 'بانتظار تأكيد الدفع',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: context.kText,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            isFawryVoucher
                ? 'ادفع المبلغ في أقرب نقطة فوري، وسنُحدّث الحالة تلقائياً'
                : 'جاري التحقق من الدفع مع البنك، قد يستغرق دقائق',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.kSub),
          ),
        ),
        const SizedBox(height: 24),
        if (isFawryVoucher && ref != null && ref.isNotEmpty)
          _referenceCard(ref)
        else
          _amountCard(s, _kAmber),
        const Spacer(),
        if ((widget.checkoutUrl ?? s.checkoutUrl) != null)
          _secondaryButton('إعادة فتح صفحة الدفع', _reopenCheckout),
        const SizedBox(height: 10),
        _primaryButton('الرجوع للرئيسية', _goHome),
      ],
    );
  }

  // ── failure ────────────────────────────────────────────────
  Widget _buildFailure(PaymentStatus s) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          _circleIcon(Icons.close_rounded, _kRed),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'فشل الدفع',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: context.kText,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              s.errorMessage ?? 'حاول مرة أخرى أو اختر طريقة دفع أخرى',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.kSub),
            ),
          ),
          const SizedBox(height: 24),
          _amountCard(s, _kRed),
          const Spacer(),
          _secondaryButton(
            'العودة للحجز',
            () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 10),
          _primaryButton('الرجوع للرئيسية', _goHome),
        ],
      );

  // ── generic error ─────────────────────────────────────────
  Widget _buildError({required String title, required String body}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          _circleIcon(Icons.error_outline_rounded, _kRed),
          const SizedBox(height: 20),
          Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: context.kText,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.kSub),
            ),
          ),
          const Spacer(),
          _primaryButton('الرجوع للرئيسية', _goHome),
        ],
      );

  // ── pieces ────────────────────────────────────────────────
  Widget _circleIcon(IconData icon, Color color, {bool pulse = false}) {
    final child = Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 48),
    );
    if (!pulse) return Center(child: child);
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.95, end: 1.05),
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOut,
        onEnd: () {
          if (mounted) setState(() {});
        },
        builder: (_, v, __) => Transform.scale(scale: v, child: child),
      ),
    );
  }

  Widget _amountCard(PaymentStatus s, Color accent) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.kBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المبلغ',
                    style: TextStyle(color: context.kSub, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.amount.toStringAsFixed(0)} ${s.currency}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _providerLabel(s.provider),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _referenceCard(String ref) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kAmber.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.confirmation_number_rounded,
                    color: _kAmber, size: 20),
                SizedBox(width: 8),
                Text(
                  'رقم الدفع في فوري',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _kAmber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              ref,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: _kOcean,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('نسخ الرقم'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: ref));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم النسخ'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      );

  Widget _primaryButton(String label, VoidCallback onTap) => SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kOcean,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            label,
            style:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
      );

  Widget _secondaryButton(String label, VoidCallback onTap) => SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: _kOcean,
            side: const BorderSide(color: _kOcean, width: 1.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            label,
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
      );

  String _providerLabel(PayProvider p) {
    switch (p) {
      case PayProvider.fawry:
        return 'Fawry';
      case PayProvider.paymob:
        return 'Paymob';
      case PayProvider.cod:
        return 'نقداً';
    }
  }
}
