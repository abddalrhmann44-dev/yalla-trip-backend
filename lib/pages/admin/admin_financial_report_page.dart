// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Financial Report Page
//
//  • Summary cards: إجمالي الإيرادات، عمولة المنصة، المصاريف الإدارية،
//    مستحقات الملاك، الخصومات، الاسترداد
//  • Monthly revenue table for the last 12 months
//  • Top 5 earning properties
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../services/admin_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';

const _kOcean  = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF4CAF50);
const _kRed    = Color(0xFFEF5350);
const _kPurple = Color(0xFF7E57C2);
const _kOrange = Color(0xFFFF6D00);

class AdminFinancialReportPage extends StatefulWidget {
  const AdminFinancialReportPage({super.key});
  @override
  State<AdminFinancialReportPage> createState() =>
      _AdminFinancialReportPageState();
}

class _AdminFinancialReportPageState
    extends State<AdminFinancialReportPage> {
  bool _loading = true;
  int _months = 12;

  // Summary
  double _totalRevenue = 0;
  double _platformFees = 0;
  double _adminFees = 0;
  double _ownerPayouts = 0;
  double _promoDiscounts = 0;
  double _walletDiscounts = 0;
  double _refunds = 0;
  int _paidBookings = 0;

  // Monthly rows
  List<Map<String, dynamic>> _monthly = [];

  // Top properties
  List<Map<String, dynamic>> _topProps = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data =
          await AdminService.getFinancialReport(months: _months);
      final summary = data['summary'] as Map<String, dynamic>;
      setState(() {
        _totalRevenue    = (summary['total_revenue'] as num).toDouble();
        _platformFees    = (summary['total_platform_fees'] as num).toDouble();
        _adminFees       = (summary['total_admin_fees'] as num).toDouble();
        _ownerPayouts    = (summary['total_owner_payouts'] as num).toDouble();
        _promoDiscounts  = (summary['total_promo_discounts'] as num).toDouble();
        _walletDiscounts = (summary['total_wallet_discounts'] as num).toDouble();
        _refunds         = (summary['total_refunds'] as num).toDouble();
        _paidBookings    = (summary['total_paid_bookings'] as num).toInt();
        _monthly  = List<Map<String, dynamic>>.from(data['monthly'] as List);
        _topProps = List<Map<String, dynamic>>.from(data['top_properties'] as List);
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

  String _fmt(double v) => v.toStringAsFixed(0);

  // Convert "2025-03" → "مارس 2025" (abbreviated)
  String _monthLabel(String iso) {
    final parts = iso.split('-');
    if (parts.length < 2) return iso;
    const names = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    final m = int.tryParse(parts[1]) ?? 0;
    return '${names[m]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('التقرير المالي',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOcean))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Period selector ────────────────────────────
                _periodSelector(),
                const SizedBox(height: 16),

                // ── Summary cards ──────────────────────────────
                _sectionHeader('ملخص الإيرادات'),
                const SizedBox(height: 10),
                Row(children: [
                  _summaryCard('إجمالي الإيرادات',
                      '${_fmt(_totalRevenue)} ج.م',
                      Icons.payments_rounded, _kOcean),
                  const SizedBox(width: 10),
                  _summaryCard('عمولة المنصة',
                      '${_fmt(_platformFees)} ج.م',
                      Icons.account_balance_rounded, _kGreen),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _summaryCard('المصاريف الإدارية',
                      '${_fmt(_adminFees)} ج.م',
                      Icons.receipt_long_rounded, _kPurple),
                  const SizedBox(width: 10),
                  _summaryCard('مستحقات الملاك',
                      '${_fmt(_ownerPayouts)} ج.م',
                      Icons.home_work_rounded, _kOrange),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _summaryCard('خصومات البروموشن',
                      '${_fmt(_promoDiscounts)} ج.م',
                      Icons.local_offer_rounded, _kGreen),
                  const SizedBox(width: 10),
                  _summaryCard('خصومات المحفظة',
                      '${_fmt(_walletDiscounts)} ج.م',
                      Icons.savings_rounded, _kPurple),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _summaryCard('الاستردادات',
                      '${_fmt(_refunds)} ج.م',
                      Icons.undo_rounded, _kRed),
                  const SizedBox(width: 10),
                  _summaryCard('حجوزات مدفوعة',
                      '$_paidBookings',
                      Icons.check_circle_rounded, _kGreen),
                ]),
                const SizedBox(height: 24),

                // ── Monthly table ──────────────────────────────
                _sectionHeader('التفاصيل الشهرية'),
                const SizedBox(height: 10),
                _monthlyTable(),
                const SizedBox(height: 24),

                // ── Top properties ─────────────────────────────
                if (_topProps.isNotEmpty) ...[
                  _sectionHeader('أعلى ٥ عقارات إيراداً'),
                  const SizedBox(height: 10),
                  ..._topProps.asMap().entries.map(
                    (e) => _propTile(e.key + 1, e.value),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _periodSelector() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.kBorder),
        ),
        child: Row(children: [
          Icon(Icons.date_range_rounded, color: _kOcean, size: 18),
          const SizedBox(width: 8),
          Text('عرض آخر',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.kText)),
          const Spacer(),
          DropdownButton<int>(
            value: _months,
            underline: const SizedBox(),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.kText),
            items: const [
              DropdownMenuItem(value: 3, child: Text('3 أشهر')),
              DropdownMenuItem(value: 6, child: Text('6 أشهر')),
              DropdownMenuItem(value: 12, child: Text('12 شهر')),
              DropdownMenuItem(value: 24, child: Text('24 شهر')),
            ],
            onChanged: (v) {
              if (v != null && v != _months) {
                setState(() => _months = v);
                _load();
              }
            },
          ),
        ]),
      );

  Widget _sectionHeader(String label) => Text(
        label,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: _kOcean),
      );

  Widget _summaryCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: context.kText)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: context.kSub,
                  height: 1.3)),
        ]),
      ),
    );
  }

  Widget _monthlyTable() {
    if (_monthly.isEmpty) {
      return Center(
        child: Text('لا توجد بيانات',
            style: TextStyle(color: context.kSub, fontSize: 13)),
      );
    }

    // find max revenue for mini bar scaling
    final maxRev = _monthly
        .map((r) => (r['revenue'] as num).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        children: _monthly.reversed.map((row) {
          final rev = (row['revenue'] as num).toDouble();
          final fee = (row['platform_fee'] as num).toDouble();
          final adminFee = (row['admin_fee'] as num).toDouble();
          final bookings = (row['bookings'] as num).toInt();
          final barFraction = maxRev > 0 ? rev / maxRev : 0.0;
          final isFirst = row == _monthly.last;
          final isLast = row == _monthly.first;

          return Container(
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                          color: context.kBorder, width: 0.7)),
              borderRadius: isFirst
                  ? const BorderRadius.vertical(top: Radius.circular(16))
                  : isLast
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(16))
                      : null,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      _monthLabel(row['month'] as String),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: context.kText),
                    ),
                  ),
                  Text('$bookings حجز',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.kSub)),
                ]),
                const SizedBox(height: 6),
                // mini bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: barFraction.toDouble(),
                    minHeight: 6,
                    backgroundColor:
                        _kOcean.withValues(alpha: 0.1),
                    color: _kOcean,
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  _miniStat('إيرادات', '${_fmt(rev)} ج.م', _kOcean),
                  const SizedBox(width: 14),
                  _miniStat('عمولة', '${_fmt(fee)} ج.م', _kGreen),
                  const SizedBox(width: 14),
                  _miniStat('إدارية', '${_fmt(adminFee)} ج.م',
                      _kPurple),
                ]),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text('$label: ',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: context.kSub)),
          Text(value,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: context.kText)),
        ],
      );

  Widget _propTile(int rank, Map<String, dynamic> prop) {
    final name = (prop['property_name'] as String?) ?? 'عقار #${prop['property_id']}';
    final rev = (prop['revenue'] as num).toDouble();
    final bookings = (prop['bookings'] as num).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.kBorder),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _kOcean.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text('$rank',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _kOcean)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.kText)),
            const SizedBox(height: 2),
            Text('$bookings حجز',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.kSub)),
          ]),
        ),
        Text('${_fmt(rev)} ج.م',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _kGreen)),
      ]),
    );
  }
}
