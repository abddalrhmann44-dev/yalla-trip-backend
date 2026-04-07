// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Booking Page
//  Full booking flow: people → date → promo → payment → confirm
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../widgets/constants.dart';
import '../../data/models/app_config_model.dart';
import '../../data/models/promo_code_model.dart';
import '../../data/services/booking_service.dart';
import '../../data/services/promo_code_service.dart';
import '../../data/services/payment_service.dart';
import '../providers/booking_providers.dart';
import '../widgets/pricing_breakdown_card.dart';
import 'booking_summary_page.dart';

const _kOcean  = Color(0xFF1565C0);
const _kGreen  = Color(0xFF4CAF50);
const _kRed    = Color(0xFFEF5350);
const _kOrange = Color(0xFFFF6D00);

class BookingPage extends ConsumerStatefulWidget {
  final String placeId;
  final String placeName;
  final String bookingType; // beach | aqua_park | chalet
  final String ownerId;
  final double pricePerPerson;

  const BookingPage({
    super.key,
    required this.placeId,
    required this.placeName,
    required this.bookingType,
    required this.ownerId,
    required this.pricePerPerson,
  });

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  int _people = 1;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  PaymentMethod _paymentMethod = PaymentMethod.visa;
  final _promoCtrl = TextEditingController();

  PromoCodeModel? _validPromo;
  String? _promoError;
  bool _promoLoading = false;
  bool _booking = false;
  double _appFeePercent = 10.0;
  bool _appFeeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAppFee();
  }

  @override
  void dispose() {
    _promoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAppFee() async {
    final fee = await ref.read(adminConfigServiceProvider).getAppFeePercent();
    if (mounted) setState(() { _appFeePercent = fee; _appFeeLoaded = true; });
  }

  PricingResult get _pricing {
    return BookingService().calculatePricing(
      pricePerPerson: widget.pricePerPerson,
      numberOfPeople: _people,
      appFeePercent: _appFeePercent,
      promoDiscountPercent: _validPromo?.discountPercent ?? 0,
    );
  }

  // ── Validate promo ────────────────────────────────────────
  Future<void> _validatePromo() async {
    final code = _promoCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() { _promoLoading = true; _promoError = null; _validPromo = null; });
    try {
      final promo = await ref.read(promoCodeServiceProvider).validatePromo(code);
      setState(() { _validPromo = promo; _promoLoading = false; });
      HapticFeedback.mediumImpact();
    } on PromoException catch (e) {
      setState(() { _promoError = e.message; _promoLoading = false; });
    } catch (_) {
      setState(() { _promoError = 'حدث خطأ'; _promoLoading = false; });
    }
  }

  // ── Pick date ─────────────────────────────────────────────
  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _kOcean),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  // ── Confirm booking ───────────────────────────────────────
  Future<void> _confirmBooking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('يجب تسجيل الدخول أولاً', _kRed);
      return;
    }

    setState(() => _booking = true);

    try {
      // 1. Process payment
      final payResult = await ref.read(paymentServiceProvider).handlePayment(
        method: _paymentMethod,
        amount: _pricing.subtotal,
        userId: user.uid,
      );

      if (!payResult.success) {
        if (mounted) {
          setState(() => _booking = false);
          _snack(payResult.errorMessage ?? 'فشل في الدفع', _kRed);
        }
        return;
      }

      // 2. Create booking
      final booking = await ref.read(bookingServiceProvider).createBooking(
        userId: user.uid,
        userName: user.displayName ?? 'ضيف',
        ownerId: widget.ownerId,
        placeId: widget.placeId,
        placeName: widget.placeName,
        bookingType: widget.bookingType,
        numberOfPeople: _people,
        pricePerPerson: widget.pricePerPerson,
        appFeePercent: _appFeePercent,
        paymentMethod: PaymentService.methodLabel(_paymentMethod),
        bookingDate: _selectedDate,
        promoDiscountPercent: _validPromo?.discountPercent ?? 0,
        promoCode: _validPromo?.code ?? '',
      );

      if (!mounted) return;
      setState(() => _booking = false);

      // 3. Navigate to summary
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingSummaryPage(booking: booking),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _booking = false);
        _snack('حدث خطأ: $e', _kRed);
      }
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final p = _pricing;
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'ar').format(_selectedDate);

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
        title: Text('حجز جديد',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        centerTitle: true,
      ),
      body: !_appFeeLoaded
          ? const Center(child: CircularProgressIndicator(color: _kOcean))
          : ListView(padding: const EdgeInsets.all(20), children: [
              // Place header
              _placeHeader(context),
              const SizedBox(height: 20),

              // Number of people
              _sectionLabel('عدد الأشخاص'),
              const SizedBox(height: 10),
              _peoplePicker(context),
              const SizedBox(height: 20),

              // Date
              _sectionLabel('تاريخ الحجز'),
              const SizedBox(height: 10),
              _datePicker(context, dateStr),
              const SizedBox(height: 20),

              // Promo code
              _sectionLabel('كود خصم (اختياري)'),
              const SizedBox(height: 10),
              _promoField(context),
              const SizedBox(height: 20),

              // Payment method
              _sectionLabel('طريقة الدفع'),
              const SizedBox(height: 10),
              _paymentSelector(context),
              const SizedBox(height: 24),

              // Pricing breakdown
              PricingBreakdownCard(
                basePrice: p.basePrice,
                discount: p.discount,
                subtotal: p.subtotal,
                appFee: p.appFee,
                ownerEarnings: p.ownerEarnings,
                appFeePercent: p.appFeePercent,
                promoCode: _validPromo?.code ?? '',
              ),
              const SizedBox(height: 100),
            ]),

      // Bottom bar
      bottomNavigationBar: _bottomBar(context, p),
    );
  }

  // ── Widgets ───────────────────────────────────────────────

  Widget _placeHeader(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kOcean.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kOcean.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Text(_typeEmoji(widget.bookingType),
              style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(widget.placeName,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: context.kText)),
              const SizedBox(height: 2),
              Text(
                  '${widget.pricePerPerson.toStringAsFixed(0)} جنيه / شخص',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kOcean)),
            ]),
          ),
        ]),
      );

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: context.kText));

  Widget _peoplePicker(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.kBorder),
        ),
        child: Row(children: [
          const Text('👥', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text('$_people شخص',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.kText)),
          const Spacer(),
          _counterBtn(Icons.remove_circle_outline_rounded, _people > 1,
              () => setState(() => _people--)),
          const SizedBox(width: 8),
          _counterBtn(Icons.add_circle_outline_rounded, _people < 50,
              () => setState(() => _people++)),
        ]),
      );

  Widget _counterBtn(IconData icon, bool enabled, VoidCallback onTap) =>
      GestureDetector(
        onTap: enabled ? onTap : null,
        child: Icon(icon,
            size: 28,
            color: enabled ? _kOcean : context.kBorder),
      );

  Widget _datePicker(BuildContext context, String dateStr) => GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: context.kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.kBorder),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded,
                size: 20, color: _kOcean),
            const SizedBox(width: 12),
            Expanded(
              child: Text(dateStr,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.kText)),
            ),
            Icon(Icons.chevron_left_rounded,
                color: context.kSub, size: 20),
          ]),
        ),
      );

  Widget _promoField(BuildContext context) => Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _promoCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'أدخل كود الخصم',
                prefixIcon: const Icon(Icons.local_offer_rounded,
                    size: 20, color: _kOrange),
                suffixIcon: _promoLoading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _kOcean)),
                      )
                    : null,
                filled: true,
                fillColor: context.kCard,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.kBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.kBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: _kOcean, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _promoLoading ? null : _validatePromo,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: _kOcean,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('تحقق',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ),
          ),
        ]),
        if (_validPromo != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  size: 16, color: _kGreen),
              const SizedBox(width: 6),
              Text(
                  'خصم ${_validPromo!.discountPercent.toStringAsFixed(0)}% تم التطبيق',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kGreen)),
            ]),
          ),
        if (_promoError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded,
                  size: 16, color: _kRed),
              const SizedBox(width: 6),
              Text(_promoError!,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kRed)),
            ]),
          ),
      ]);

  Widget _paymentSelector(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PaymentMethod.values.map((m) {
        final sel = _paymentMethod == m;
        return GestureDetector(
          onTap: () => setState(() => _paymentMethod = m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? _kOcean.withValues(alpha: 0.08) : context.kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: sel ? _kOcean : context.kBorder,
                  width: sel ? 2 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(PaymentService.methodIcon(m),
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(PaymentService.methodLabel(m),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: sel ? _kOcean : context.kText)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _bottomBar(BuildContext context, PricingResult p) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.kCard,
          border: Border(top: BorderSide(color: context.kBorder)),
        ),
        child: SafeArea(
          child: Row(children: [
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
              Text('${p.subtotal.toStringAsFixed(0)} جنيه',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _kOcean)),
              Text('الإجمالي',
                  style: TextStyle(fontSize: 12, color: context.kSub)),
            ]),
            const Spacer(),
            GestureDetector(
              onTap: _booking ? null : _confirmBooking,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: _booking ? _kOcean.withValues(alpha: 0.6) : _kOcean,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _kOcean.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _booking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('تأكيد الحجز',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900)),
                        SizedBox(width: 6),
                        Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 18),
                      ]),
              ),
            ),
          ]),
        ),
      );

  String _typeEmoji(String type) {
    switch (type) {
      case 'beach': return '🏖️';
      case 'aqua_park': return '🌊';
      case 'chalet': return '🏡';
      default: return '🎯';
    }
  }
}
