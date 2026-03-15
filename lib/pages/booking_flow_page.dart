// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Booking Flow Page
//  3 steps: تواريخ → تفاصيل + سياسة الإلغاء → تأكيد → PaymentPage
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../main.dart' show appSettings;
import '../utils/app_strings.dart';
import '../models/property_model.dart';
import 'payment_page.dart';

const _kOcean  = Color(0xFF1565C0);
const _kOrange = Color(0xFFFF6D00);
const _kSand   = Color(0xFFF5F3EE);
const _kText   = Color(0xFF0D1B2A);
const _kSub    = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kGreen  = Color(0xFF22C55E);

class BookingFlowPage extends StatefulWidget {
  final PropertyModel property;
  const BookingFlowPage({super.key, required this.property});
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

  PropertyModel get p => widget.property;

  int get _nights {
    if (_checkIn == null || _checkOut == null) return 0;
    return _checkOut!.difference(_checkIn!).inDays;
  }

  int get _baseTotal {
    if (_nights <= 0) return 0;
    return (p.price * _nights).toInt();
  }

  int get _cleaningFee => p.cleaningFee.toInt();
  int get _grandTotal  => _baseTotal + _cleaningFee;

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
      _checkIn != null && _checkOut != null && _nights >= p.minNights;

  // ═══════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSand,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kText, size: 18),
          onPressed: () {
            if (_step > 0) { _goStep(_step - 1); }
            else { Navigator.pop(context); }
          },
        ),
        title: Text(_stepTitle(),
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: _kText)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: AnimatedBuilder(
            animation: _progressAnim,
            builder: (_, __) => LinearProgressIndicator(
              value: _progressAnim.value,
              backgroundColor: _kBorder,
              valueColor: const AlwaysStoppedAnimation(_kOcean),
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
                fontWeight: FontWeight.w900, color: _kText)),
        const SizedBox(height: 4),
        Text('الحد الأدنى ${p.minNights} ليالي',
            style: const TextStyle(fontSize: 13, color: _kSub)),
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
              color: _kOcean.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _kOcean.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.nights_stay_rounded,
                  color: _kOcean, size: 20),
              const SizedBox(width: 10),
              Text('$_nights ليالي',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900,
                      color: _kOcean)),
              const Spacer(),
              Text('${_baseTotal.toString()} جنيه',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900,
                      color: _kOcean)),
            ]),
          ),
        ],

        if (_checkIn != null && _checkOut != null &&
            _nights < p.minNights && _nights > 0)
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
                'الحد الأدنى للإقامة ${p.minNights} ليالي',
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
              backgroundColor: _kOcean,
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
          color: date != null ? color : _kBorder,
          width: date != null ? 1.8 : 1.5,
        ),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: date != null ? color : _kSub),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
              fontSize: 11, color: date != null ? color : _kSub,
              fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Text(
          date != null
              ? '${date.day}/${date.month}/${date.year}'
              : 'اختر تاريخ',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w900,
              color: date != null ? _kText : _kSub),
        ),
      ]),
    ),
  );

  Future<void> _pickDate({required bool isCheckIn}) async {
    final now   = DateTime.now();
    final first = isCheckIn
        ? now
        : (_checkIn ?? now).add(
            Duration(days: p.minNights));
    final picked = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: first,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('ar'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _kOcean,
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

        // Guests
        Text(S.guestsNum,
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w900, color: _kText)),
        const SizedBox(height: 12),
        _guestCounter(),
        const SizedBox(height: 20),

        // Note to host
        const Text('ملاحظة للمضيف (اختياري)',
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w900, color: _kText)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
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
              backgroundColor: _kOcean,
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

  Widget _guestCounter() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _kBorder),
    ),
    child: Row(children: [
      const Icon(Icons.people_rounded, color: _kOcean, size: 22),
      const SizedBox(width: 12),
      const Text('ضيوف',
          style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.w700, color: _kText)),
      const Spacer(),
      _counterBtn(Icons.remove_rounded,
          _guests > 1 ? () => setState(() => _guests--) : null),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('$_guests',
            style: const TextStyle(fontSize: 18,
                fontWeight: FontWeight.w900, color: _kText)),
      ),
      _counterBtn(Icons.add_rounded,
          _guests < p.guests ? () => setState(() => _guests++) : null),
    ]),
  );

  Widget _counterBtn(IconData icon, VoidCallback? onTap) =>
    GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: onTap != null
              ? _kOcean.withValues(alpha: 0.08)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: onTap != null
                ? _kOcean.withValues(alpha: 0.2)
                : Colors.grey.shade200),
        ),
        child: Icon(icon, size: 18,
            color: onTap != null ? _kOcean : Colors.grey.shade400),
      ),
    );

  // ── Policy section (كـ Airbnb) ──────────────────────
  Widget _policySection() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _kBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.policy_rounded, color: _kOcean, size: 18),
        SizedBox(width: 8),
        Text('سياسة الإلغاء والحجز',
            style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.w900, color: _kText)),
      ]),
      const Divider(height: 20, color: _kBorder),

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
      const Divider(height: 20, color: _kBorder),

      // Booking rules
      _policyItem(
        icon: Icons.access_time_rounded,
        color: _kOcean,
        title: 'وقت الوصول والمغادرة',
        body: 'الوصول من الساعة ${p.checkinTime.isNotEmpty ? p.checkinTime : "14:00"} '
              '— المغادرة قبل ${p.checkoutTime.isNotEmpty ? p.checkoutTime : "12:00"}.',
      ),
      const SizedBox(height: 12),
      _policyItem(
        icon: Icons.no_drinks_rounded,
        color: _kSub,
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
        Text(title, style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800, color: _kText)),
        const SizedBox(height: 3),
        Text(body, style: const TextStyle(
            fontSize: 12, color: _kSub, height: 1.5)),
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
        const Text('ملخص الرحلة',
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w900, color: _kText)),
        const SizedBox(height: 12),
        _summaryCard(),
        const SizedBox(height: 20),

        // Price breakdown
        const Text('تفاصيل السعر',
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w900, color: _kText)),
        const SizedBox(height: 12),
        _priceBreakdown(),
        const SizedBox(height: 24),

        // Proceed to payment
        SizedBox(
          width: double.infinity, height: 58,
          child: ElevatedButton(
            onPressed: _proceedToPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOcean,
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
                  child: Text('$_grandTotal جنيه',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text('🔒 دفع آمن ومشفر',
              style: TextStyle(fontSize: 12, color: _kSub)),
        ),
      ]),
    );
  }

  Widget _priceBreakdown() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _kBorder),
    ),
    child: Column(children: [
      _priceRow('${p.price.toInt()} جنيه × $_nights ليالي',
          '$_baseTotal جنيه'),
      if (_cleaningFee > 0)
        _priceRow(S.cleaningFee, '$_cleaningFee جنيه'),
      const Divider(height: 20, color: _kBorder),
      _priceRow(S.totalPrice, '$_grandTotal جنيه', bold: true),
    ]),
  );

  Widget _priceRow(String label, String val, {bool bold = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(
            fontSize: 13, color: bold ? _kText : _kSub,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w400))),
        Text(val, style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: bold ? _kOcean : _kText)),
      ]),
    );

  void _proceedToPayment() {
    final checkInStr  = '${_checkIn!.day}/${_checkIn!.month}/${_checkIn!.year}';
    final checkOutStr = '${_checkOut!.day}/${_checkOut!.month}/${_checkOut!.year}';

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PaymentPage(
        property:     p,
        checkIn:      checkInStr,
        checkOut:     checkOutStr,
        nights:       _nights,
        guests:       _guests,
        guestNote:    _guestNote,
        baseAmount:   _baseTotal,
        cleaningFee:  _cleaningFee,
        totalAmount:  _grandTotal,
      ),
    ));
  }

  // ── Shared Widgets ────────────────────────────────────

  Widget _propertyMiniCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _kBorder),
    ),
    child: Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: p.images.isEmpty
            ? Container(width: 60, height: 60,
                color: _kOcean.withValues(alpha: 0.1),
                child: const Icon(Icons.villa_rounded,
                    color: _kOcean, size: 28))
            : Image.network(p.images[0], width: 60,
                height: 60, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    width: 60, height: 60,
                    color: _kOcean.withValues(alpha: 0.1),
                    child: const Icon(Icons.villa_rounded,
                        color: _kOcean, size: 28))),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w800, color: _kText)),
          const SizedBox(height: 3),
          Text('${p.categoryEmoji} ${p.category} · ${p.area}',
              style: const TextStyle(fontSize: 12, color: _kSub)),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.star_rounded,
                size: 13, color: Color(0xFFF59E0B)),
            const SizedBox(width: 3),
            Text(p.rating.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: _kText)),
          ]),
        ],
      )),
      Text('${p.price.toInt()}\nجنيه/ليلة',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w900, color: _kOcean)),
    ]),
  );

  Widget _summaryCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _kBorder),
    ),
    child: Column(children: [
      Row(children: [
        _summaryItem(Icons.login_rounded, 'الوصول',
            _checkIn != null
                ? '${_checkIn!.day}/${_checkIn!.month}/${_checkIn!.year}'
                : '—',
            _kGreen),
        const SizedBox(width: 1),
        Container(width: 1, height: 40, color: _kBorder),
        const SizedBox(width: 1),
        _summaryItem(Icons.logout_rounded, 'المغادرة',
            _checkOut != null
                ? '${_checkOut!.day}/${_checkOut!.month}/${_checkOut!.year}'
                : '—',
            _kOrange),
        Container(width: 1, height: 40, color: _kBorder),
        _summaryItem(Icons.nights_stay_rounded,
            'ليالي', '$_nights', _kOcean),
        Container(width: 1, height: 40, color: _kBorder),
        _summaryItem(Icons.people_rounded,
            'ضيوف', '$_guests', _kSub),
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
      Text(label, style: const TextStyle(fontSize: 10, color: _kSub)),
    ]));
}
