// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Revenue Detail Page
//  Monthly bar chart + breakdown by property + paid bookings list
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/constants.dart';

const _kOcean = Color(0xFFFF6B35);
const _kGreen = Color(0xFF4CAF50);

// ── Mock Data ─────────────────────────────────────────────────
final _monthlyRevenue = [
  {'month': 'يناير',  'amount': 8500.0},
  {'month': 'فبراير', 'amount': 12300.0},
  {'month': 'مارس',   'amount': 9800.0},
  {'month': 'أبريل',  'amount': 15600.0},
  {'month': 'مايو',   'amount': 18200.0},
  {'month': 'يونيو',  'amount': 22000.0},
];

final _weeklyRevenue = [
  {'month': 'أسبوع 1', 'amount': 4200.0},
  {'month': 'أسبوع 2', 'amount': 5800.0},
  {'month': 'أسبوع 3', 'amount': 6100.0},
  {'month': 'أسبوع 4', 'amount': 5900.0},
];

final _propertyRevenue = [
  {'name': 'شاليه النخيل — الغردقة',  'amount': 6800.0,  'bookings': 8},
  {'name': 'فيلا البحر — شرم الشيخ',  'amount': 5400.0,  'bookings': 6},
  {'name': 'استديو النهر — القاهرة',   'amount': 3200.0,  'bookings': 12},
  {'name': 'شقة الجبل — أسوان',       'amount': 2900.0,  'bookings': 9},
  {'name': 'كوتج الريف — الإسكندرية', 'amount': 1700.0,  'bookings': 5},
];

final _paidBookings = [
  {'code': 'BK-1001', 'guest': 'أحمد محمود',   'property': 'شاليه النخيل', 'checkin': '01/05', 'checkout': '05/05', 'amount': 2400.0},
  {'code': 'BK-1002', 'guest': 'سارة أحمد',    'property': 'فيلا البحر',   'checkin': '03/05', 'checkout': '07/05', 'amount': 3200.0},
  {'code': 'BK-1003', 'guest': 'محمد علي',     'property': 'استديو النهر', 'checkin': '05/05', 'checkout': '06/05', 'amount': 850.0},
  {'code': 'BK-1004', 'guest': 'نورا حسين',    'property': 'شقة الجبل',   'checkin': '08/05', 'checkout': '12/05', 'amount': 1600.0},
  {'code': 'BK-1005', 'guest': 'كريم إبراهيم', 'property': 'شاليه النخيل', 'checkin': '10/05', 'checkout': '14/05', 'amount': 2800.0},
  {'code': 'BK-1006', 'guest': 'منى حسن',      'property': 'كوتج الريف',  'checkin': '12/05', 'checkout': '15/05', 'amount': 1200.0},
  {'code': 'BK-1007', 'guest': 'عمر يوسف',     'property': 'فيلا البحر',  'checkin': '15/05', 'checkout': '20/05', 'amount': 4000.0},
  {'code': 'BK-1008', 'guest': 'ليلى سامي',    'property': 'استديو النهر','checkin': '18/05', 'checkout': '19/05', 'amount': 750.0},
];

class AdminRevenueDetailPage extends StatefulWidget {
  final double totalRevenue;
  const AdminRevenueDetailPage({super.key, this.totalRevenue = 20000});

  @override
  State<AdminRevenueDetailPage> createState() => _AdminRevenueDetailPageState();
}

class _AdminRevenueDetailPageState extends State<AdminRevenueDetailPage> {
  bool _isMonthly = true;

  List<Map<String, dynamic>> get _chartData =>
      _isMonthly ? _monthlyRevenue : _weeklyRevenue;

  double get _maxAmount =>
      _chartData.map((e) => e['amount'] as double).reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: context.kSand,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App Bar ──────────────────────────────────────
            SliverAppBar(
              backgroundColor: _kOcean,
              expandedHeight: 120,
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: const Text('تفاصيل الإيرادات',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE85A24), _kOcean],
                    ),
                  ),
                ),
              ),
            ),

            // ── Total Revenue Hero Card ──────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kOcean, Color(0xFFE85A24)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إجمالي الإيرادات',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.totalRevenue.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      const Text('بيانات تجريبية — للعرض فقط',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),

            // ── Filter Toggle ─────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    _filterBtn('شهري', _isMonthly, () {
                      HapticFeedback.selectionClick();
                      setState(() => _isMonthly = true);
                    }),
                    const SizedBox(width: 8),
                    _filterBtn('أسبوعي', !_isMonthly, () {
                      HapticFeedback.selectionClick();
                      setState(() => _isMonthly = false);
                    }),
                  ],
                ),
              ),
            ),

            // ── Bar Chart ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildBarChart(context),
              ),
            ),

            // ── Revenue by Property ──────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Text('الإيرادات حسب العقار',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: context.kText)),
              ),
            ),

            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => Padding(
                  padding: EdgeInsets.fromLTRB(16, i == 0 ? 10 : 8, 16, 0),
                  child: _propertyRevenueCard(ctx, _propertyRevenue[i]),
                ),
                childCount: _propertyRevenue.length,
              ),
            ),

            // ── Paid Bookings ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Text('الحجوزات المدفوعة',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: context.kText)),
              ),
            ),

            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => Padding(
                  padding: EdgeInsets.fromLTRB(16, i == 0 ? 10 : 8, 16, 0),
                  child: _paidBookingCard(ctx, _paidBookings[i]),
                ),
                childCount: _paidBookings.length,
              ),
            ),

            // ── Summary Footer ───────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
                  ),
                  child: Column(children: [
                    _summaryRow('إجمالي الحجوزات المدفوعة',
                        '${_paidBookings.length} حجز'),
                    const Divider(height: 16),
                    _summaryRow('متوسط قيمة الحجز',
                        '${(_paidBookings.map((b) => b['amount'] as double).reduce((a, b) => a + b) / _paidBookings.length).toStringAsFixed(0)} ج.م'),
                    const Divider(height: 16),
                    _summaryRow('أعلى إيراد — عقار واحد',
                        '${_propertyRevenue.first['amount']} ج.م'),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bar Chart Widget ───────────────────────────────────────
  Widget _buildBarChart(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isMonthly ? 'الإيرادات الشهرية' : 'الإيرادات الأسبوعية',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.kText),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _chartData.map((item) {
                final pct = (item['amount'] as double) / _maxAmount;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${((item['amount'] as double) / 1000).toStringAsFixed(1)}k',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _kOcean),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          height: 100 * pct,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [_kOcean, Color(0xFFFF8A3D)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          (item['month'] as String).substring(0, 3),
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: context.kSub),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Property Revenue Card ──────────────────────────────────
  Widget _propertyRevenueCard(BuildContext context, Map<String, dynamic> prop) {
    final pct = (prop['amount'] as double) /
        (_propertyRevenue
            .map((p) => p['amount'] as double)
            .reduce((a, b) => a + b));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kOcean.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.apartment_rounded, color: _kOcean, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(prop['name'] as String,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.kText)),
              Text('${prop['bookings']} حجز',
                  style: TextStyle(fontSize: 11, color: context.kSub)),
            ]),
          ),
          Text(
            '${prop['amount']} ج.م',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _kOcean),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: _kOcean.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation(_kOcean),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text('${(pct * 100).toStringAsFixed(1)}% من الإجمالي',
            style: TextStyle(fontSize: 10, color: context.kSub)),
      ]),
    );
  }

  // ── Paid Booking Card ──────────────────────────────────────
  Widget _paidBookingCard(BuildContext context, Map<String, dynamic> booking) {
    return Container(
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
            color: _kGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.receipt_long_rounded, color: _kGreen, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(booking['guest'] as String,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.kText)),
            Text(booking['property'] as String,
                style: TextStyle(fontSize: 11, color: context.kSub)),
            Text('${booking['checkin']} → ${booking['checkout']}',
                style: TextStyle(fontSize: 10, color: context.kSub)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '${booking['amount']} ج.م',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _kGreen),
          ),
          Text(booking['code'] as String,
              style: TextStyle(fontSize: 10, color: context.kSub)),
        ]),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────
  Widget _filterBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _kOcean : context.kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _kOcean : context.kBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : context.kSub),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.kSub)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: context.kText)),
      ],
    );
  }
}
