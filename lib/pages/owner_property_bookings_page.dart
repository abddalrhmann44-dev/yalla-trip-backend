// ═══════════════════════════════════════════════════════════════
//  TALAA — Owner Property Bookings Page
//
//  المالك يشوف كل عقاراته مع الحجوزات التفصيلية:
//  • كود كل عقار (PROP-XXXXXX)
//  • كل حجز: اسم الضيف، تاريخ، الفلوس بالتفصيل الكامل
//  • فلتر بالحالة (الكل / مؤكد / ملغى / مكتمل)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/api_client.dart';
import '../utils/error_handler.dart';
import '../widgets/constants.dart';

const _kOcean  = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF4CAF50);
const _kRed    = Color(0xFFEF5350);
const _kAmber  = Color(0xFFFFA726);
const _kPurple = Color(0xFF7E57C2);

// ── Models ──────────────────────────────────────────────────────
class _OwnerBookingItem {
  final int bookingId;
  final String bookingCode;
  final String? guestName, guestPhone;
  final String checkIn, checkOut;
  final int guestsCount;
  final double totalPrice, platformFee, adminFee, ownerPayout;
  final double depositAmount, remainingCash;
  final double promoDiscount, walletDiscount;
  final String status, paymentStatus, payoutStatus, cashStatus;
  final String createdAt;

  _OwnerBookingItem.fromJson(Map<String, dynamic> j)
      : bookingId = j['booking_id'] as int,
        bookingCode = j['booking_code'] as String,
        guestName = j['guest_name'] as String?,
        guestPhone = j['guest_phone'] as String?,
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
        status = j['status'] as String,
        paymentStatus = j['payment_status'] as String,
        payoutStatus = j['payout_status'] as String,
        cashStatus = j['cash_collection_status'] as String,
        createdAt = j['created_at'] as String;
}

class _OwnerPropertyGroup {
  final int propertyId;
  final String? propertyCode;
  final String propertyName, area, category, status;
  final double pricePerNight;
  final List<_OwnerBookingItem> bookings;

  _OwnerPropertyGroup.fromJson(Map<String, dynamic> j)
      : propertyId = j['property_id'] as int,
        propertyCode = j['property_code'] as String?,
        propertyName = j['property_name'] as String,
        area = j['area'] as String,
        category = j['category'] as String,
        status = j['status'] as String,
        pricePerNight = (j['price_per_night'] as num).toDouble(),
        bookings = (j['bookings'] as List)
            .map((e) => _OwnerBookingItem.fromJson(e as Map<String, dynamic>))
            .toList();
}

// ── Page ────────────────────────────────────────────────────────
class OwnerPropertyBookingsPage extends StatefulWidget {
  const OwnerPropertyBookingsPage({super.key});
  @override
  State<OwnerPropertyBookingsPage> createState() =>
      _OwnerPropertyBookingsPageState();
}

enum _StatusFilter { all, confirmed, completed, cancelled, pending }

class _OwnerPropertyBookingsPageState
    extends State<OwnerPropertyBookingsPage> {
  final _api = ApiClient();
  bool _loading = true;
  List<_OwnerPropertyGroup> _groups = [];
  _StatusFilter _filter = _StatusFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      String url = '/bookings/owner/by-property';
      if (_filter != _StatusFilter.all) {
        url += '?status_filter=${_filter.name}';
      }
      final data = await _api.get(url) as List;
      setState(() {
        _groups = data
            .map((e) => _OwnerPropertyGroup.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التحميل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  int get _totalBookings =>
      _groups.fold(0, (s, g) => s + g.bookings.length);

  double get _totalRevenue => _groups.fold(
      0.0, (s, g) => s + g.bookings.fold(0.0, (s2, b) => s2 + b.ownerPayout));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('حجوزات عقاراتي',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(children: [
        // ── Stats strip ────────────────────────────────────────
        if (!_loading)
          Container(
            color: _kOcean,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(children: [
              _statChip(
                  '${_groups.length}',
                  'عقار',
                  Icons.apartment_rounded),
              const SizedBox(width: 8),
              _statChip(
                  '$_totalBookings',
                  'حجز',
                  Icons.calendar_month_rounded),
              const SizedBox(width: 8),
              _statChip(
                  '${_totalRevenue.toStringAsFixed(0)} ج.م',
                  'مستحقاتك',
                  Icons.payments_rounded),
            ]),
          ),

        // ── Filter chips ───────────────────────────────────────
        Container(
          color: _loading ? _kOcean : Colors.transparent,
          padding: _loading
              ? const EdgeInsets.fromLTRB(12, 0, 12, 12)
              : const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _filterChip('الكل', _StatusFilter.all),
              const SizedBox(width: 8),
              _filterChip('مؤكد', _StatusFilter.confirmed),
              const SizedBox(width: 8),
              _filterChip('مكتمل', _StatusFilter.completed),
              const SizedBox(width: 8),
              _filterChip('ملغى', _StatusFilter.cancelled),
              const SizedBox(width: 8),
              _filterChip('معلق', _StatusFilter.pending),
            ]),
          ),
        ),

        // ── List ──────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _kOcean))
              : _groups.isEmpty
                  ? Center(
                      child: Text('لا توجد عقارات',
                          style: TextStyle(
                              color: context.kSub,
                              fontWeight: FontWeight.w600)))
                  : RefreshIndicator(
                      color: _kOcean,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(14, 4, 14, 30),
                        itemCount: _groups.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 14),
                        itemBuilder: (_, i) =>
                            _propertyGroup(_groups[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _statChip(String value, String label, IconData icon) => Expanded(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      );

  Widget _filterChip(String label, _StatusFilter value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        _load();
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _kOcean : context.kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? _kOcean : context.kBorder),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : context.kSub)),
      ),
    );
  }

  // ── Property group card ─────────────────────────────────────
  Widget _propertyGroup(_OwnerPropertyGroup g) {
    final paidCount = g.bookings
        .where((b) => b.paymentStatus == 'paid')
        .length;
    final totalOwnerPayout = g.bookings.fold(
        0.0, (s, b) => s + b.ownerPayout);

    return Container(
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Expanded(
                child: Text(g.propertyName,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: context.kText)),
              ),
              _propStatusBadge(g.status),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.location_on_rounded,
                  size: 13, color: context.kSub),
              const SizedBox(width: 3),
              Text('${g.area}  •  ${g.category}',
                  style: TextStyle(
                      fontSize: 11,
                      color: context.kSub,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            // Code + price row
            Row(children: [
              if (g.propertyCode != null)
                GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(
                        ClipboardData(text: g.propertyCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('تم نسخ الكود',
                            style: TextStyle(
                                fontWeight: FontWeight.w700)),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kOcean.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      const Icon(Icons.qr_code_rounded,
                          size: 12, color: _kOcean),
                      const SizedBox(width: 4),
                      Text(g.propertyCode!,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: _kOcean)),
                    ]),
                  ),
                ),
              const Spacer(),
              Text('${g.pricePerNight.toStringAsFixed(0)} ج.م / ليلة',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.kSub)),
            ]),
            const SizedBox(height: 8),
            // Summary numbers
            Row(children: [
              _miniStat(
                  '${g.bookings.length}',
                  'حجز',
                  Icons.calendar_today_rounded,
                  _kOcean),
              const SizedBox(width: 8),
              _miniStat(
                  '$paidCount',
                  'مدفوع',
                  Icons.check_circle_rounded,
                  _kGreen),
              const SizedBox(width: 8),
              _miniStat(
                  '${totalOwnerPayout.toStringAsFixed(0)} ج.م',
                  'مستحقاتك',
                  Icons.payments_rounded,
                  _kAmber),
            ]),
          ]),
        ),

        // Divider
        if (g.bookings.isNotEmpty)
          Divider(height: 1, color: context.kBorder),

        // Bookings
        if (g.bookings.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Text('لا توجد حجوزات',
                style: TextStyle(
                    color: context.kSub,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          )
        else
          ...g.bookings.map((b) => _bookingRow(b, isLast: b == g.bookings.last)),
      ]),
    );
  }

  Widget _bookingRow(_OwnerBookingItem b, {required bool isLast}) {
    final isPaid = b.paymentStatus == 'paid';
    final nights = DateTime.parse(b.checkOut)
        .difference(DateTime.parse(b.checkIn))
        .inDays;

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom:
                    BorderSide(color: context.kBorder, width: 0.6)),
      ),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding:
            const EdgeInsets.fromLTRB(14, 0, 14, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kOcean.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(b.bookingCode,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: _kOcean)),
                ),
                const SizedBox(width: 6),
                _bookingStatusBadge(b.status, b.paymentStatus),
              ]),
              const SizedBox(height: 4),
              Text(
                '${b.guestName ?? 'ضيف غير معروف'}  •  $nights ليلة',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.kText),
              ),
              Text(
                '${b.checkIn} → ${b.checkOut}',
                style: TextStyle(
                    fontSize: 11,
                    color: context.kSub,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              '${b.ownerPayout.toStringAsFixed(0)} ج.م',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: isPaid ? _kGreen : context.kText),
            ),
            Text('مستحقاتك',
                style: TextStyle(
                    fontSize: 10,
                    color: context.kSub,
                    fontWeight: FontWeight.w600)),
          ]),
        ]),
        children: [
          // Guest contact
          if (b.guestPhone != null && b.paymentStatus == 'paid')
            _infoRow(Icons.phone_rounded, 'هاتف الضيف', b.guestPhone!,
                copyable: true)
          else if (b.guestPhone == null && b.paymentStatus == 'paid')
            _infoRow(Icons.phone_disabled_rounded, 'هاتف الضيف',
                'لم يُدخل الضيف رقمه'),
          const SizedBox(height: 10),
          // Financial breakdown
          const Text('التفاصيل المالية',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _kOcean)),
          const SizedBox(height: 8),
          _finRow('إجمالي الحجز', b.totalPrice, _kOcean),
          _finRow('عمولة المنصة', b.platformFee, _kRed),
          if (b.adminFee > 0)
            _finRow('مصاريف إدارية (ع الضيف)', b.adminFee, _kPurple),
          _finRow('مستحقاتك', b.ownerPayout,
              isPaid ? _kGreen : _kAmber),
          if (b.depositAmount > 0 && b.remainingCash > 0) ...[
            const Divider(height: 14),
            _finRow('عربون أونلاين', b.depositAmount, _kOcean),
            _finRow('نقدي عند الوصول', b.remainingCash, _kAmber),
          ],
          if (b.promoDiscount > 0)
            _finRow('خصم بروموشن', -b.promoDiscount, _kRed),
          if (b.walletDiscount > 0)
            _finRow('خصم محفظة', -b.walletDiscount, _kRed),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _infoRow(
                  Icons.people_rounded, 'ضيوف', '${b.guestsCount} شخص'),
            ),
            Expanded(
              child: _infoRow(
                  Icons.account_balance_wallet_rounded,
                  'حالة الصرف',
                  _payoutLabel(b.payoutStatus)),
            ),
          ]),
          if (b.cashStatus != 'not_applicable')
            _infoRow(Icons.payments_outlined, 'نقدي عند الوصول',
                _cashLabel(b.cashStatus)),
        ],
      ),
    );
  }

  // ── helpers ─────────────────────────────────────────────────
  Widget _miniStat(String v, String label, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(v,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: color)),
                Text(label,
                    style: TextStyle(
                        fontSize: 9,
                        color: context.kSub,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
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
                    color: context.kSub,
                    fontWeight: FontWeight.w600)),
          ),
          Text(
            '${amount >= 0 ? '' : '- '}${amount.abs().toStringAsFixed(0)} ج.م',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: amount < 0 ? _kRed : color),
          ),
        ]),
      );

  Widget _infoRow(IconData icon, String label, String value,
      {bool copyable = false}) {
    final row = Row(children: [
      Icon(icon, size: 13, color: context.kSub),
      const SizedBox(width: 5),
      Text('$label: ',
          style: TextStyle(
              fontSize: 11,
              color: context.kSub,
              fontWeight: FontWeight.w600)),
      Flexible(
        child: Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: context.kText)),
      ),
      if (copyable) ...[
        const SizedBox(width: 4),
        Icon(Icons.copy_rounded, size: 11, color: context.kSub),
      ],
    ]);
    if (!copyable) return Padding(padding: const EdgeInsets.only(bottom: 4), child: row);
    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم نسخ $label',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      },
      child: Padding(padding: const EdgeInsets.only(bottom: 4), child: row),
    );
  }

  Widget _propStatusBadge(String status) {
    final (label, color) = switch (status) {
      'approved' => ('معتمد', _kGreen),
      'pending' => ('معلق', _kAmber),
      'rejected' => ('مرفوض', _kRed),
      'needs_edit' => ('يحتاج تعديل', _kAmber),
      _ => (status, _kAmber),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }

  Widget _bookingStatusBadge(String status, String payment) {
    final (label, color) = switch (status) {
      'confirmed' => ('مؤكد', _kGreen),
      'completed' => ('مكتمل', _kGreen),
      'cancelled' => ('ملغى', _kRed),
      'pending' => ('معلق', _kAmber),
      _ => (status, _kAmber),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(5)),
        child: Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color)),
      ),
      const SizedBox(width: 4),
      if (payment == 'paid')
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5)),
          child: const Text('مدفوع',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _kGreen)),
        ),
    ]);
  }

  String _payoutLabel(String s) => switch (s) {
        'paid' => 'تم الصرف ✅',
        'processing' => 'جاري...',
        'unpaid' => 'لم يُصرف',
        _ => s,
      };
  String _cashLabel(String s) => switch (s) {
        'not_applicable' => 'غير مطبق',
        'pending' => 'في الانتظار',
        'confirmed' => 'مؤكد',
        'owner_confirmed' => 'أكدت الاستلام',
        'guest_confirmed' => 'الضيف أكد الدفع',
        'disputed' => 'نزاع',
        'no_show' => 'لم يحضر',
        _ => s,
      };
}
