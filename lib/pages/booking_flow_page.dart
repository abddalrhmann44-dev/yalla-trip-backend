// ═══════════════════════════════════════════════════════════════
//  TALAA — Booking Flow Page
//  3 steps: تواريخ → تفاصيل + سياسة الإلغاء → تأكيد → PaymentPage
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../main.dart' show appSettings;
import '../utils/app_strings.dart';
import '../widgets/constants.dart';
import '../widgets/guests_animation_counter.dart';
import '../models/property_model_api.dart';
import 'payment_page.dart';

const _kOrange = Color(0xFFFF6D00);
const _kGreen  = Color(0xFF22C55E);

class BookingFlowPage extends StatefulWidget {
  final PropertyApi propertyApi;
  const BookingFlowPage({super.key, required this.propertyApi});
  @override State<BookingFlowPage> createState() => _BookingFlowPageState();
}

class _BookingFlowPageState extends State<BookingFlowPage>
    with TickerProviderStateMixin {

  int _step = 0;
  final PageController _pageCtrl = PageController();
  late AnimationController _progressCtrl;
  late Animation<double>   _progressAnim;

  // Booking data
  DateTime? _checkIn;
  DateTime? _checkOut;
  int       _guests    = 1;
  String    _guestNote = '';
  final _noteCtrl = TextEditingController();

  PropertyApi get p => widget.propertyApi;

  int get _nights {
    if (_checkIn == null || _checkOut == null) return 0;
    return _checkOut!.difference(_checkIn!).inDays;
  }

  int get _baseTotal {
    if (_nights <= 0) return 0;
    return (p.pricePerNight * _nights).toInt();
  }

  int get _cleaningFee => p.cleaningFee.toStringAsFixed(0) == '0' ? 0 : p.cleaningFee.toInt();
  int get _grandTotal  => _baseTotal + _cleaningFee;

  // ── Wave 25: hybrid deposit + cash-on-arrival ─────────────
  // Mirrors ``app/services/deposit.py`` server-side so the receipt
  // the guest sees here matches what the backend will charge at
  // checkout.  The 10 % constant tracks
  // ``settings.PLATFORM_FEE_PERCENT`` — keep them in sync.
  static const double _kCommissionRate = 0.10;

  /// Number of nights the deposit must cover so the platform
  /// commission is fully covered by the online portion.  Mirrors the
  /// ``max(1, ceil(commission / price_per_night))`` rule on the
  /// backend.
  int get _depositNights {
    if (!p.cashOnArrivalEnabled || _nights <= 0) return 0;
    final commission = _grandTotal * _kCommissionRate;
    final perNight = p.pricePerNight;
    if (perNight <= 0) return 1;
    final nightsNeeded = (commission / perNight).ceil();
    return nightsNeeded.clamp(1, _nights);
  }

  /// Online deposit — what the guest pays right now via the gateway.
  /// For listings without cash-on-arrival this is the full total so
  /// the legacy UI rendering stays intact.
  int get _depositAmount {
    if (!p.cashOnArrivalEnabled) return _grandTotal;
    final raw = (p.pricePerNight * _depositNights).toInt();
    return raw.clamp(0, _grandTotal);
  }

  /// Remaining cash the host collects on arrival.  Always
  /// ``total - deposit`` so the invariant
  /// ``deposit + remaining == total`` holds.
  int get _remainingCash {
    if (!p.cashOnArrivalEnabled) return 0;
    return (_grandTotal - _depositAmount).clamp(0, _grandTotal);
  }

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _progressAnim = Tween(begin: 0.33, end: 0.33)
        .animate(CurvedAnimation(parent: _progressCtrl,
            curve: Curves.easeOut));
    _progressCtrl.forward();
  }

  void _onLangChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange);
    _progressCtrl.dispose();
    _noteCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goStep(int step) {
    setState(() => _step = step);
    _pageCtrl.animateToPage(step,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut);
    final targets = [0.33, 0.66, 1.0];
    _progressAnim = Tween(begin: _progressAnim.value,
        end: targets[step])
        .animate(CurvedAnimation(parent: _progressCtrl,
            curve: Curves.easeOut));
    _progressCtrl.forward(from: 0);
  }

  bool get _canProceedStep0 =>
      _checkIn != null && _checkOut != null && _nights >= 1;

  // ═══════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: context.kText, size: 18),
          onPressed: () {
            if (_step > 0) { _goStep(_step - 1); }
            else { Navigator.pop(context); }
          },
        ),
        title: Text(_stepTitle(),
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: context.kText)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: AnimatedBuilder(
            animation: _progressAnim,
            builder: (_, __) => LinearProgressIndicator(
              value: _progressAnim.value,
              backgroundColor: context.kBorder,
              valueColor: const AlwaysStoppedAnimation(_kOrange),
              minHeight: 4,
            ),
          ),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _step0Dates(),
          _step1Details(),
          _step2Confirm(),
        ],
      ),
    );
  }

  String _stepTitle() {
    switch (_step) {
      case 0:  return S.chooseDates;
      case 1:  return S.bookingDetails;
      default: return S.confirmBooking;
    }
  }

  // ═══════════════════════════════════════
  //  STEP 0 — DATE PICKER
  // ═══════════════════════════════════════
  Widget _step0Dates() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Property mini card
        _propertyMiniCard(),
        const SizedBox(height: 20),

        // Calendar header
        Text(S.dateRange,
            style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.w900, color: context.kText)),
        const SizedBox(height: 4),
        Text('الحد الأدنى 1 ليالي',
            style: TextStyle(fontSize: 13, color: context.kSub)),
        const SizedBox(height: 20),

        // Date range tiles
        Row(children: [
          Expanded(child: _dateTile(
            label: S.arrivalDate,
            icon: Icons.login_rounded,
            date: _checkIn,
            color: _kGreen,
            onTap: () => _pickDate(isCheckIn: true),
          )),
          const SizedBox(width: 12),
          Expanded(child: _dateTile(
            label: S.departureDate,
            icon: Icons.logout_rounded,
            date: _checkOut,
            color: _kOrange,
            onTap: () => _pickDate(isCheckIn: false),
          )),
        ]),

        if (_checkIn != null && _checkOut != null && _nights > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _kOrange.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.nights_stay_rounded,
                  color: _kOrange, size: 20),
              const SizedBox(width: 10),
              Text('$_nights ليالي',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900,
                      color: _kOrange)),
              const Spacer(),
              Text('${_baseTotal.toString()} جنيه',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900,
                      color: _kOrange)),
            ]),
          ),
        ],

        if (_checkIn != null && _checkOut != null &&
            _nights < 1 && _nights > 0)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3F3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFEF5350).withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFEF5350), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'الحد الأدنى للإقامة 1 ليالي',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFFEF5350),
                    fontWeight: FontWeight.w600),
              )),
            ]),
          ),

        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: _canProceedStep0
                ? () => _goStep(1)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('التالي: تفاصيل الحجز ←',
                style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ]),
    );
  }

  Widget _dateTile({
    required String label,
    required IconData icon,
    required DateTime? date,
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: date != null
            ? color.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: date != null ? color : context.kBorder,
          width: date != null ? 1.8 : 1.5,
        ),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: date != null ? color : context.kSub),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
              fontSize: 11, color: date != null ? color : context.kSub,
              fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Text(
          date != null
              ? '${date.day}/${date.month}/${date.year}'
              : 'اختر تاريخ',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w900,
              color: date != null ? context.kText : context.kSub),
        ),
      ]),
    ),
  );

  Future<void> _pickDate({required bool isCheckIn}) async {
    final now   = DateTime.now();
    final first = isCheckIn
        ? now
        : (_checkIn ?? now).add(
            const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: first,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('ar'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _kOrange,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isCheckIn) {
        _checkIn  = picked;
        _checkOut = null;
      } else {
        _checkOut = picked;
      }
    });
  }

  // ═══════════════════════════════════════
  //  STEP 1 — DETAILS + POLICY
  // ═══════════════════════════════════════
  Widget _step1Details() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Booking summary
        _summaryCard(),
        const SizedBox(height: 20),

        // Guests (Lottie animation + counter)
        Text(S.guestsNum,
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w900, color: context.kText)),
        const SizedBox(height: 12),
        GuestsAnimationCounter(
          guestCount: _guests,
          maxGuests: p.maxGuests,
          onChanged: (v) => setState(() => _guests = v),
        ),
        const SizedBox(height: 20),

        // Note to host
        Text('ملاحظة للمضيف (اختياري)',
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w900, color: context.kText)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.kBorder),
          ),
          child: TextField(
            controller: _noteCtrl,
            maxLines: 3,
            maxLength: 200,
            onChanged: (v) => _guestNote = v,
            decoration: InputDecoration(
              hintText: 'أي طلبات خاصة؟ (وقت وصول مبكر، مناسبة، إلخ)',
              hintStyle: TextStyle(
                  color: Colors.grey.shade400, fontSize: 13),
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Cancellation & booking policy ────────────
        _policySection(),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: () => _goStep(2),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('التالي: مراجعة الحجز ←',
                style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ]),
    );
  }

  // _guestCounter() replaced by GuestsAnimationCounter widget

  // ── Policy section (كـ Airbnb) ──────────────────────
  Widget _policySection() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.kBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.policy_rounded, color: _kOrange, size: 18),
        SizedBox(width: 8),
        Text('سياسة الإلغاء والحجز',
            style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.w900, color: context.kText)),
      ]),
      Divider(height: 20, color: context.kBorder),

      // Cancellation policy
      _policyItem(
        icon: Icons.cancel_outlined,
        color: _kGreen,
        title: 'إلغاء مجاني',
        body: 'يمكنك الإلغاء مجاناً قبل الوصول بـ 7 أيام على الأقل.',
      ),
      const SizedBox(height: 12),
      _policyItem(
        icon: Icons.cancel_rounded,
        color: _kOrange,
        title: 'إلغاء جزئي',
        body: 'الإلغاء بين 3 و7 أيام قبل الوصول: استرداد 50% من المبلغ.',
      ),
      const SizedBox(height: 12),
      _policyItem(
        icon: Icons.money_off_rounded,
        color: const Color(0xFFEF5350),
        title: 'بدون استرداد',
        body: 'الإلغاء قبل أقل من 3 أيام أو عدم الحضور: لا يُسترد المبلغ.',
      ),
      Divider(height: 20, color: context.kBorder),

      // Booking rules
      _policyItem(
        icon: Icons.access_time_rounded,
        color: _kOrange,
        title: 'وقت الوصول والمغادرة',
        body: 'الوصول من الساعة 14:00 '
              '— وقت الإغلاق ${p.closingTime ?? "22:00"}.',
      ),
      const SizedBox(height: 12),
      _policyItem(
        icon: Icons.no_drinks_rounded,
        color: context.kSub,
        title: 'قواعد العقار',
        body: 'يُرجى احترام جيران العقار وعدم إقامة حفلات صاخبة.',
      ),

      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          '⚠️ بالمتابعة وإتمام الدفع، أنت توافق على سياسة الإلغاء والقواعد المذكورة أعلاه.',
          style: TextStyle(fontSize: 12,
              color: Color(0xFF92400E), height: 1.5),
        ),
      ),
    ]),
  );

  Widget _policyItem({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 17, color: color),
    ),
    const SizedBox(width: 12),
    Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800, color: context.kText)),
        const SizedBox(height: 3),
        Text(body, style: TextStyle(
            fontSize: 12, color: context.kSub, height: 1.5)),
      ],
    )),
  ]);

  // ═══════════════════════════════════════
  //  STEP 2 — CONFIRM
  // ═══════════════════════════════════════
  Widget _step2Confirm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Property card
        _propertyMiniCard(),
        const SizedBox(height: 20),

        // Trip summary
        Text('ملخص الرحلة',
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w900, color: context.kText)),
        const SizedBox(height: 12),
        _summaryCard(),
        const SizedBox(height: 20),

        // Price breakdown
        Text('تفاصيل السعر',
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w900, color: context.kText)),
        const SizedBox(height: 12),
        _priceBreakdown(),
        const SizedBox(height: 24),

        // Proceed to payment
        SizedBox(
          width: double.infinity, height: 58,
          child: ElevatedButton(
            onPressed: _proceedToPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('إتمام الحجز والدفع',
                    style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  // For cash-on-arrival listings the button shows
                  // the *deposit* (= what's about to leave the
                  // guest's card right now), not the grand total.
                  child: Text(
                    '${p.cashOnArrivalEnabled ? _depositAmount : _grandTotal} جنيه',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text('🔒 دفع آمن ومشفر',
              style: TextStyle(fontSize: 12, color: context.kSub)),
        ),
      ]),
    );
  }

  Widget _priceBreakdown() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.kBorder),
    ),
    child: Column(children: [
      _priceRow('${p.pricePerNight.toStringAsFixed(0)} جنيه × $_nights ليالي',
          '$_baseTotal جنيه'),
      if (_cleaningFee > 0)
        _priceRow(S.cleaningFee, '$_cleaningFee جنيه'),
      Divider(height: 20, color: context.kBorder),
      _priceRow(S.totalPrice, '$_grandTotal جنيه', bold: true),
      // ── Wave 25 — hybrid deposit + cash split ───────────────
      // Surface this only for opted-in listings; legacy ones keep
      // showing just the grand total exactly like before.
      if (p.cashOnArrivalEnabled) ...[
        const SizedBox(height: 14),
        _depositSplitCard(),
      ],
    ]),
  );

  /// Highlights the "you pay X online now, Y in cash on arrival"
  /// split.  Designed to be unmissable so guests aren't surprised at
  /// check-in by an extra cash demand.
  Widget _depositSplitCard() {
    final depositLabel = _depositNights > 0
        ? (_depositNights == 1
            ? 'ليلة واحدة'
            : 'ليالى $_depositNights')
        : '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF66BB6A), width: 1.2),
      ),
      child: Column(children: [
        Row(children: const [
          Text('💵', style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'دفع جزئى — استلم الباقى للمضيف عند الوصول',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B5E20)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        _priceRow(
          depositLabel.isNotEmpty
              ? 'تدفع الآن (عربون $depositLabel)'
              : 'تدفع الآن (عربون)',
          '$_depositAmount جنيه',
          bold: true,
        ),
        if (_remainingCash > 0)
          _priceRow(
            'تدفع كاش للمضيف عند الوصول',
            '$_remainingCash جنيه',
          ),
      ]),
    );
  }

  Widget _priceRow(String label, String val, {bool bold = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(
            fontSize: 13, color: bold ? context.kText : context.kSub,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w400))),
        Text(val, style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: bold ? _kOrange : context.kText)),
      ]),
    );

  void _proceedToPayment() {
    final checkInStr  = '${_checkIn!.day}/${_checkIn!.month}/${_checkIn!.year}';
    final checkOutStr = '${_checkOut!.day}/${_checkOut!.month}/${_checkOut!.year}';

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PaymentPage(
        property:        p,
        checkIn:         checkInStr,
        checkOut:        checkOutStr,
        nights:          _nights,
        guests:          _guests,
        guestNote:       _guestNote,
        baseAmount:      _baseTotal,
        cleaningFee:     _cleaningFee,
        totalAmount:     _grandTotal,
        // Wave 25 — for hybrid listings the gateway only charges the
        // deposit; ``totalAmount`` stays as the grand total so the
        // receipt UI keeps showing the trip-wide cost.
        depositAmount:   _depositAmount,
        remainingCash:   _remainingCash,
      ),
    ));
  }

  // ── Shared Widgets ────────────────────────────────────

  Widget _propertyMiniCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.kBorder),
    ),
    child: Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: p.images.isEmpty
            ? Container(width: 60, height: 60,
                color: _kOrange.withValues(alpha: 0.1),
                child: const Icon(Icons.villa_rounded,
                    color: _kOrange, size: 28))
            : Image.network(p.images[0], width: 60,
                height: 60, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    width: 60, height: 60,
                    color: _kOrange.withValues(alpha: 0.1),
                    child: const Icon(Icons.villa_rounded,
                        color: _kOrange, size: 28))),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w800, color: context.kText)),
          const SizedBox(height: 3),
          Text('${p.categoryEmoji} ${p.category} · ${p.area}',
              style: TextStyle(fontSize: 12, color: context.kSub)),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.star_rounded,
                size: 13, color: Color(0xFFF59E0B)),
            const SizedBox(width: 3),
            Text(p.rating.toStringAsFixed(1),
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: context.kText)),
          ]),
        ],
      )),
      Text('${p.pricePerNight.toStringAsFixed(0)}\nجنيه/ليلة',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w900, color: _kOrange)),
    ]),
  );

  Widget _summaryCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.kBorder),
    ),
    child: Column(children: [
      Row(children: [
        _summaryItem(Icons.login_rounded, 'الوصول',
            _checkIn != null
                ? '${_checkIn!.day}/${_checkIn!.month}/${_checkIn!.year}'
                : '—',
            _kGreen),
        const SizedBox(width: 1),
        Container(width: 1, height: 40, color: context.kBorder),
        const SizedBox(width: 1),
        _summaryItem(Icons.logout_rounded, 'المغادرة',
            _checkOut != null
                ? '${_checkOut!.day}/${_checkOut!.month}/${_checkOut!.year}'
                : '—',
            _kOrange),
        Container(width: 1, height: 40, color: context.kBorder),
        _summaryItem(Icons.nights_stay_rounded,
            'ليالي', '$_nights', _kOrange),
        Container(width: 1, height: 40, color: context.kBorder),
        _summaryItem(Icons.people_rounded,
            'ضيوف', '$_guests', context.kSub),
      ]),
    ]),
  );

  Widget _summaryItem(IconData icon, String label,
      String val, Color color) =>
    Expanded(child: Column(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(height: 4),
      Text(val, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: context.kSub)),
    ]));
}
