// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Code Lookup Page
//
//  البحث بكود العقار (PROP-XXXXXX) أو كود الحجز (XXXXXXXX):
//  • بيانات العقار الكاملة + بيانات المالك (صور البطاقة)
//  • قائمة جميع الحجوزات المربوطة بالعقار
//  • بيانات الضيف الكاملة (اسم، هاتف، صور بطاقة)
//  • تفاصيل مالية كاملة: الإجمالي، العمولات، المستحقات
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/admin_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';

const _kOcean  = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF4CAF50);
const _kRed    = Color(0xFFEF5350);
const _kPurple = Color(0xFF7E57C2);
const _kAmber  = Color(0xFFFFA726);

// ── Models ─────────────────────────────────────────────────────
class _BookingBrief {
  final String bookingCode;
  final String? guestName, guestPhone, guestEmail;
  final String? guestIdFront, guestIdBack;
  final String checkIn, checkOut;
  final int guestsCount;
  final double totalPrice, platformFee, adminFee, ownerPayout;
  final double promoDiscount, walletDiscount;
  final double? refundAmount;
  final String status, paymentStatus, payoutStatus;
  final String createdAt;

  _BookingBrief.fromJson(Map<String, dynamic> j)
      : bookingCode = j['booking_code'] as String,
        guestName = j['guest_name'] as String?,
        guestPhone = j['guest_phone'] as String?,
        guestEmail = j['guest_email'] as String?,
        guestIdFront = j['guest_id_front'] as String?,
        guestIdBack = j['guest_id_back'] as String?,
        checkIn = j['check_in'] as String,
        checkOut = j['check_out'] as String,
        guestsCount = (j['guests_count'] as num).toInt(),
        totalPrice = (j['total_price'] as num).toDouble(),
        platformFee = (j['platform_fee'] as num).toDouble(),
        adminFee = (j['admin_fee'] as num).toDouble(),
        ownerPayout = (j['owner_payout'] as num).toDouble(),
        promoDiscount = (j['promo_discount'] as num).toDouble(),
        walletDiscount = (j['wallet_discount'] as num).toDouble(),
        refundAmount = (j['refund_amount'] as num?)?.toDouble(),
        status = j['status'] as String,
        paymentStatus = j['payment_status'] as String,
        payoutStatus = j['payout_status'] as String,
        createdAt = j['created_at'] as String;
}

class _PropertyLookup {
  final String propertyCode;
  final int propertyId;
  final String propertyName, area, category, status;
  final double pricePerNight;
  final bool isVerified;
  final String createdAt;
  final int ownerId;
  final String ownerName;
  final String? ownerPhone, ownerEmail, ownerIdFront, ownerIdBack;
  final List<_BookingBrief> bookings;

  _PropertyLookup.fromJson(Map<String, dynamic> j)
      : propertyCode = j['property_code'] as String,
        propertyId = j['property_id'] as int,
        propertyName = j['property_name'] as String,
        area = j['area'] as String,
        category = j['category'] as String,
        status = j['status'] as String,
        pricePerNight = (j['price_per_night'] as num).toDouble(),
        isVerified = j['is_verified'] as bool,
        createdAt = j['created_at'] as String,
        ownerId = j['owner_id'] as int,
        ownerName = j['owner_name'] as String,
        ownerPhone = j['owner_phone'] as String?,
        ownerEmail = j['owner_email'] as String?,
        ownerIdFront = j['owner_id_front'] as String?,
        ownerIdBack = j['owner_id_back'] as String?,
        bookings = (j['bookings'] as List)
            .map((e) => _BookingBrief.fromJson(e as Map<String, dynamic>))
            .toList();
}

class _BookingLookup {
  final String bookingCode;
  final int bookingId;
  final String? propertyCode;
  final int propertyId;
  final String propertyName, area;
  final int guestId;
  final String? guestName, guestPhone, guestEmail;
  final String? guestIdFront, guestIdBack;
  final int ownerId;
  final String? ownerName, ownerPhone, ownerEmail;
  final String checkIn, checkOut;
  final int guestsCount;
  final double totalPrice, platformFee, adminFee, ownerPayout;
  final double depositAmount, remainingCash;
  final double promoDiscount, walletDiscount;
  final double? refundAmount;
  final String status, paymentStatus, payoutStatus, cashStatus;
  final String createdAt;

  _BookingLookup.fromJson(Map<String, dynamic> j)
      : bookingCode = j['booking_code'] as String,
        bookingId = j['booking_id'] as int,
        propertyCode = j['property_code'] as String?,
        propertyId = j['property_id'] as int,
        propertyName = j['property_name'] as String,
        area = j['area'] as String,
        guestId = j['guest_id'] as int,
        guestName = j['guest_name'] as String?,
        guestPhone = j['guest_phone'] as String?,
        guestEmail = j['guest_email'] as String?,
        guestIdFront = j['guest_id_front'] as String?,
        guestIdBack = j['guest_id_back'] as String?,
        ownerId = j['owner_id'] as int,
        ownerName = j['owner_name'] as String?,
        ownerPhone = j['owner_phone'] as String?,
        ownerEmail = j['owner_email'] as String?,
        checkIn = j['check_in'] as String,
        checkOut = j['check_out'] as String,
        guestsCount = (j['guests_count'] as num).toInt(),
        totalPrice = (j['total_price'] as num).toDouble(),
        platformFee = (j['platform_fee'] as num).toDouble(),
        adminFee = (j['admin_fee'] as num).toDouble(),
        ownerPayout = (j['owner_payout'] as num).toDouble(),
        depositAmount = (j['deposit_amount'] as num).toDouble(),
        remainingCash = (j['remaining_cash_amount'] as num).toDouble(),
        promoDiscount = (j['promo_discount'] as num).toDouble(),
        walletDiscount = (j['wallet_discount'] as num).toDouble(),
        refundAmount = (j['refund_amount'] as num?)?.toDouble(),
        status = j['status'] as String,
        paymentStatus = j['payment_status'] as String,
        payoutStatus = j['payout_status'] as String,
        cashStatus = j['cash_collection_status'] as String,
        createdAt = j['created_at'] as String;
}

// ── Page ───────────────────────────────────────────────────────
class AdminCodeLookupPage extends StatefulWidget {
  const AdminCodeLookupPage({super.key});
  @override
  State<AdminCodeLookupPage> createState() => _AdminCodeLookupPageState();
}

enum _Mode { property, booking }

class _AdminCodeLookupPageState extends State<AdminCodeLookupPage> {
  final _ctrl = TextEditingController();
  _Mode _mode = _Mode.property;
  bool _loading = false;
  _PropertyLookup? _propResult;
  _BookingLookup? _bookingResult;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _propResult = null;
      _bookingResult = null;
    });
    try {
      if (_mode == _Mode.property) {
        final data = await AdminService.lookupPropertyCode(code);
        setState(() => _propResult = _PropertyLookup.fromJson(data));
      } else {
        final data = await AdminService.lookupBookingCode(code);
        setState(() => _bookingResult = _BookingLookup.fromJson(data));
      }
    } on ApiException catch (e) {
      setState(() => _error = ErrorHandler.getMessage(e));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('البحث بالكود',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Mode toggle ──────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: context.kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.kBorder),
            ),
            child: Row(children: [
              _modeBtn('كود عقار', _Mode.property, Icons.apartment_rounded),
              _modeBtn('كود حجز', _Mode.booking, Icons.confirmation_number_rounded),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Search bar ───────────────────────────────────────
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: _mode == _Mode.property
                      ? 'PROP-AB12CD'
                      : 'YT-XXXXXXXX',
                  hintStyle:
                      TextStyle(fontSize: 13, color: context.kSub),
                  prefixIcon: Icon(
                    _mode == _Mode.property
                        ? Icons.qr_code_rounded
                        : Icons.tag_rounded,
                    color: _kOcean,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: context.kCard,
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kOcean, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _search,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOcean,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search_rounded,
                        color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // ── Error ────────────────────────────────────────────
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kRed.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: _kRed, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          color: _kRed,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ]),
            ),

          // ── Results ──────────────────────────────────────────
          if (_propResult != null) _buildPropertyResult(_propResult!),
          if (_bookingResult != null) _buildBookingResult(_bookingResult!),
        ],
      ),
    );
  }

  Widget _modeBtn(String label, _Mode mode, IconData icon) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _mode = mode;
            _propResult = null;
            _bookingResult = null;
            _error = null;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _mode == mode
                  ? _kOcean
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon,
                  size: 16,
                  color: _mode == mode ? Colors.white : context.kSub),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color:
                          _mode == mode ? Colors.white : context.kSub)),
            ]),
          ),
        ),
      );

  // ── Property result ─────────────────────────────────────────
  Widget _buildPropertyResult(_PropertyLookup p) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Property card
      _card(children: [
        _badgeRow(p.propertyCode, p.status),
        const SizedBox(height: 10),
        _label('العقار', p.propertyName),
        _row2('المنطقة', p.area, 'الفئة', p.category),
        _row2('السعر/ليلة', '${p.pricePerNight.toStringAsFixed(0)} ج.م',
            'تاريخ الرفع', p.createdAt.substring(0, 10)),
        if (p.isVerified)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              const Icon(Icons.verified_rounded,
                  color: _kGreen, size: 16),
              const SizedBox(width: 4),
              const Text('مالك موثق',
                  style: TextStyle(
                      color: _kGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
      ]),
      const SizedBox(height: 12),

      // Owner card
      _sectionTitle('بيانات المالك', Icons.person_rounded, _kPurple),
      const SizedBox(height: 8),
      _card(children: [
        _label('الاسم', p.ownerName),
        if (p.ownerPhone != null)
          _copyRow('الهاتف', p.ownerPhone!),
        if (p.ownerEmail != null)
          _copyRow('الإيميل', p.ownerEmail!),
        if (p.ownerIdFront != null || p.ownerIdBack != null) ...[
          const SizedBox(height: 10),
          const Text('صور البطاقة الشخصية',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _kPurple)),
          const SizedBox(height: 8),
          _idImages(p.ownerIdFront, p.ownerIdBack),
        ],
      ]),
      const SizedBox(height: 12),

      // Bookings
      _sectionTitle(
          'الحجوزات (${p.bookings.length})',
          Icons.calendar_month_rounded,
          _kOcean),
      const SizedBox(height: 8),
      if (p.bookings.isEmpty)
        Center(
          child: Text('لا توجد حجوزات بعد',
              style: TextStyle(color: context.kSub, fontSize: 13)),
        )
      else
        ...p.bookings.map(_buildBookingBrief),
      const SizedBox(height: 40),
    ]);
  }

  Widget _buildBookingBrief(_BookingBrief b) {
    final isPaid = b.paymentStatus == 'paid';
    final isCancelled = b.status == 'cancelled';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCancelled
              ? _kRed.withValues(alpha: 0.3)
              : isPaid
                  ? _kGreen.withValues(alpha: 0.3)
                  : context.kBorder,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding:
            const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(b.bookingCode,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace')),
              const SizedBox(height: 2),
              Text('${b.guestName ?? '—'}  •  ${b.checkIn} → ${b.checkOut}',
                  style: TextStyle(
                      fontSize: 11,
                      color: context.kSub,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${b.totalPrice.toStringAsFixed(0)} ج.م',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isPaid ? _kGreen : context.kText)),
            _statusBadge(b.status, b.paymentStatus),
          ]),
        ]),
        children: [
          // Guest info
          if (b.guestPhone != null)
            _copyRow('هاتف الضيف', b.guestPhone!),
          if (b.guestEmail != null)
            _copyRow('إيميل الضيف', b.guestEmail!),
          if (b.guestIdFront != null || b.guestIdBack != null) ...[
            const SizedBox(height: 8),
            const Text('بطاقة الضيف',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _kPurple)),
            const SizedBox(height: 6),
            _idImages(b.guestIdFront, b.guestIdBack),
          ],
          const SizedBox(height: 10),
          // Financials
          _finRow('الإجمالي', b.totalPrice, _kOcean),
          _finRow('عمولة المنصة', b.platformFee, _kGreen),
          if (b.adminFee > 0)
            _finRow('مصاريف إدارية', b.adminFee, _kPurple),
          _finRow('مستحق المالك', b.ownerPayout, _kAmber),
          if (b.promoDiscount > 0)
            _finRow('خصم بروموشن', -b.promoDiscount, _kRed),
          if (b.walletDiscount > 0)
            _finRow('خصم محفظة', -b.walletDiscount, _kRed),
          if (b.refundAmount != null && b.refundAmount! > 0)
            _finRow('مسترد', -b.refundAmount!, _kRed),
          const SizedBox(height: 6),
          _row2('حالة الصرف', b.payoutStatus,
              'ضيوف', '${b.guestsCount}'),
        ],
      ),
    );
  }

  // ── Booking result ──────────────────────────────────────────
  Widget _buildBookingResult(_BookingLookup b) {
    final isPaid = b.paymentStatus == 'paid';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Booking header
      _card(children: [
        _badgeRow(b.bookingCode, b.status),
        if (b.propertyCode != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _copyRow('كود العقار', b.propertyCode!),
          ),
        const SizedBox(height: 8),
        _label('العقار', '${b.propertyName}  •  ${b.area}'),
        _row2('تاريخ الدخول', b.checkIn, 'تاريخ الخروج', b.checkOut),
        _row2('عدد الضيوف', '${b.guestsCount}', 'بتاريخ', b.createdAt.substring(0, 10)),
      ]),
      const SizedBox(height: 12),

      // Guest card
      _sectionTitle('بيانات الضيف', Icons.person_outline_rounded, _kPurple),
      const SizedBox(height: 8),
      _card(children: [
        _label('الاسم', b.guestName ?? '—'),
        if (b.guestPhone != null) _copyRow('الهاتف', b.guestPhone!),
        if (b.guestEmail != null) _copyRow('الإيميل', b.guestEmail!),
        if (b.guestIdFront != null || b.guestIdBack != null) ...[
          const SizedBox(height: 10),
          const Text('صور البطاقة الشخصية',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _kPurple)),
          const SizedBox(height: 8),
          _idImages(b.guestIdFront, b.guestIdBack),
        ],
      ]),
      const SizedBox(height: 12),

      // Owner card
      _sectionTitle('بيانات المالك', Icons.home_rounded, _kAmber),
      const SizedBox(height: 8),
      _card(children: [
        _label('الاسم', b.ownerName ?? '—'),
        if (b.ownerPhone != null) _copyRow('الهاتف', b.ownerPhone!),
        if (b.ownerEmail != null) _copyRow('الإيميل', b.ownerEmail!),
      ]),
      const SizedBox(height: 12),

      // Financials
      _sectionTitle('التفاصيل المالية', Icons.payments_rounded, _kGreen),
      const SizedBox(height: 8),
      _card(children: [
        _finRow('الإجمالي المدفوع', b.totalPrice, _kOcean),
        _finRow('عمولة المنصة', b.platformFee, _kGreen),
        if (b.adminFee > 0) _finRow('مصاريف إدارية', b.adminFee, _kPurple),
        _finRow('مستحق المالك', b.ownerPayout,
            isPaid ? _kGreen : _kAmber),
        if (b.depositAmount > 0)
          _finRow('العربون المدفوع', b.depositAmount, _kOcean),
        if (b.remainingCash > 0)
          _finRow('نقدي عند الوصول', b.remainingCash, _kAmber),
        if (b.promoDiscount > 0)
          _finRow('خصم بروموشن', -b.promoDiscount, _kRed),
        if (b.walletDiscount > 0)
          _finRow('خصم محفظة', -b.walletDiscount, _kRed),
        if (b.refundAmount != null && b.refundAmount! > 0)
          _finRow('مسترد', -b.refundAmount!, _kRed),
        const Divider(height: 16),
        _row2('حالة الدفع', _paymentLabel(b.paymentStatus),
            'صرف المالك', b.payoutStatus),
        _row2('نقدي عند الوصول', _cashLabel(b.cashStatus),
            'الحجز', _statusLabel(b.status)),
      ]),
      const SizedBox(height: 40),
    ]);
  }

  // ── Shared widgets ──────────────────────────────────────────
  Widget _card({required List<Widget> children}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.kBorder),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children),
      );

  Widget _sectionTitle(String label, IconData icon, Color color) => Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color)),
      ]);

  Widget _label(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              TextSpan(
                  text: '$k: ',
                  style: TextStyle(
                      fontSize: 12,
                      color: context.kSub,
                      fontWeight: FontWeight.w600)),
              TextSpan(
                  text: v,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: context.kText)),
            ],
          ),
        ),
      );

  Widget _copyRow(String k, String v) => GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: v));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم نسخ $k',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(child: _label(k, v)),
            Icon(Icons.copy_rounded, size: 14, color: context.kSub),
          ]),
        ),
      );

  Widget _row2(String k1, String v1, String k2, String v2) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(child: _label(k1, v1)),
          Expanded(child: _label(k2, v2)),
        ]),
      );

  Widget _finRow(String label, double amount, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.kSub)),
          ),
          Text(
            '${amount >= 0 ? '' : '-'}${amount.abs().toStringAsFixed(0)} ج.م',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: amount < 0 ? _kRed : color),
          ),
        ]),
      );

  Widget _badgeRow(String code, String status) => Row(children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kOcean.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(code,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: _kOcean)),
        ),
        const SizedBox(width: 8),
        _statusBadge(status, null),
      ]);

  Widget _statusBadge(String status, String? payment) {
    final (label, color) = switch (status) {
      'confirmed' => ('مؤكد', _kGreen),
      'completed' => ('مكتمل', _kGreen),
      'cancelled' => ('ملغى', _kRed),
      'pending' => ('معلق', _kAmber),
      'approved' => ('معتمد', _kGreen),
      'rejected' => ('مرفوض', _kRed),
      _ => (status, _kAmber),
    };
    final isPaid = payment == 'paid';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color)),
      ),
      if (payment != null) ...[
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: (isPaid ? _kGreen : _kAmber).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6)),
          child: Text(isPaid ? 'مدفوع' : 'لم يُدفع',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isPaid ? _kGreen : _kAmber)),
        ),
      ],
    ]);
  }

  Widget _idImages(String? front, String? back) => Row(children: [
        if (front != null)
          Expanded(child: _idImg(front, 'الوجه')),
        if (front != null && back != null)
          const SizedBox(width: 8),
        if (back != null)
          Expanded(child: _idImg(back, 'الظهر')),
      ]);

  Widget _idImg(String url, String label) => Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            height: 100,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 100,
              decoration: BoxDecoration(
                  color: context.kBorder,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.broken_image_rounded,
                  color: context.kSub, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: context.kSub,
                fontWeight: FontWeight.w600)),
      ]);

  String _statusLabel(String s) => switch (s) {
        'confirmed' => 'مؤكد',
        'completed' => 'مكتمل',
        'cancelled' => 'ملغى',
        'pending' => 'معلق',
        _ => s,
      };
  String _paymentLabel(String s) => switch (s) {
        'paid' => 'مدفوع ✅',
        'refunded' => 'مسترد',
        'partially_refunded' => 'مسترد جزئياً',
        _ => 'لم يُدفع',
      };
  String _cashLabel(String s) => switch (s) {
        'not_applicable' => 'غير مطبق',
        'confirmed' => 'مؤكد',
        'disputed' => 'نزاع',
        'no_show' => 'عدم حضور',
        _ => s,
      };
}
