// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Revenue Detail Page
//  Monthly bar chart + breakdown by property + paid bookings list
//  Data sourced from real API — no mock data.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../models/booking_model.dart';
import '../../services/admin_service.dart';
import '../../widgets/constants.dart';

const _kOcean = Color(0xFFFF6B35);
const _kGreen = Color(0xFF4CAF50);

// Arabic month abbreviations for "YYYY-MM" formatted strings from API.
const _arMonths = {
  '01': 'يناير',  '02': 'فبراير', '03': 'مارس',
  '04': 'أبريل',  '05': 'مايو',   '06': 'يونيو',
  '07': 'يوليو',  '08': 'أغسطس',  '09': 'سبتمبر',
  '10': 'أكتوبر', '11': 'نوفمبر', '12': 'ديسمبر',
};

String _fmtMonth(String raw) {
  // Handles "2026-05" → "مايو", or already-readable labels pass through.
  if (raw.contains('-') && raw.length >= 7) {
    final mm = raw.substring(5, 7);
    return _arMonths[mm] ?? raw;
  }
  return raw;
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

class AdminRevenueDetailPage extends StatefulWidget {
  final double totalRevenue;
  const AdminRevenueDetailPage({super.key, this.totalRevenue = 0});

  @override
  State<AdminRevenueDetailPage> createState() => _AdminRevenueDetailPageState();
}

class _AdminRevenueDetailPageState extends State<AdminRevenueDetailPage> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _monthlyRevenue = [];
  List<Map<String, dynamic>> _propertyRevenue = [];
  List<BookingModel> _paidBookings = [];

  double get _displayedTotal {
    if (widget.totalRevenue > 0) return widget.totalRevenue;
    if (_monthlyRevenue.isEmpty) return 0;
    return _monthlyRevenue
        .map((e) => e['amount'] as double)
        .fold(0.0, (a, b) => a + b);
  }

  List<Map<String, dynamic>> get _chartData => _monthlyRevenue;

  double get _maxAmount {
    if (_chartData.isEmpty) return 1;
    return _chartData
        .map((e) => e['amount'] as double)
        .reduce((a, b) => a > b ? a : b);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        AdminService.getFinancialReport(months: 6),
        AdminService.getAllBookings(paymentStatus: 'paid', limit: 100),
      ]);

      final financial = results[0] as Map<String, dynamic>;
      final bookings  = results[1] as List<BookingModel>;

      // ── Monthly revenue ────────────────────────────────────
      final rawMonthly = (financial['monthly_revenue'] as List?) ?? [];
      final monthly = rawMonthly.map<Map<String, dynamic>>((e) {
        final m = e as Map<String, dynamic>;
        return {
          'month': _fmtMonth(
              (m['month'] ?? m['period'] ?? '').toString()),
          'amount': ((m['revenue'] ?? m['amount'] ?? m['total'] ?? 0) as num)
              .toDouble(),
        };
      }).toList();

      // ── Revenue by property ────────────────────────────────
      // Try financial report first, then advanced analytics key
      final rawProps =
          (financial['by_property'] as List?) ??
          (financial['revenue_by_property'] as List?) ??
          [];
      List<Map<String, dynamic>> props = rawProps.map<Map<String, dynamic>>((e) {
        final m = e as Map<String, dynamic>;
        return {
          'name': (m['property_name'] ?? m['name'] ?? '').toString(),
          'amount': ((m['revenue'] ?? m['amount'] ?? 0) as num).toDouble(),
          'bookings': ((m['bookings_count'] ?? m['bookings'] ?? 0) as num).toInt(),
        };
      }).toList();

      // If API doesn't return by-property breakdown, compute from bookings.
      if (props.isEmpty && bookings.isNotEmpty) {
        final map = <String, Map<String, dynamic>>{};
        for (final b in bookings) {
          final name = b.property?.name ?? 'عقار #${b.propertyId}';
          if (!map.containsKey(name)) {
            map[name] = {'name': name, 'amount': 0.0, 'bookings': 0};
          }
          map[name]!['amount'] =
              (map[name]!['amount'] as double) + b.totalPrice;
          map[name]!['bookings'] =
              (map[name]!['bookings'] as int) + 1;
        }
        props = map.values.toList()
          ..sort((a, b) =>
              (b['amount'] as double).compareTo(a['amount'] as double));
      }

      setState(() {
        _monthlyRevenue = monthly;
        _propertyRevenue = props;
        _paidBookings    = bookings;
        _loading         = false;
      });
    } catch (e) {
      setState(() {
        _error   = e.toString();
        _loading = false;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════
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
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 20),
                  onPressed: _loading ? null : _loadData,
                  tooltip: 'تحديث',
                ),
              ],
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

            // ── Loading / Error ───────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: _kOcean),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            color: _kOcean, size: 48),
                        const SizedBox(height: 12),
                        const Text('تعذّر تحميل البيانات',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              // ── Total Revenue Hero Card ────────────────────
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
                          '${_displayedTotal.toStringAsFixed(0)} ج.م',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'آخر 6 شهور — ${_paidBookings.length} حجز مدفوع',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bar Chart ──────────────────────────────────
              if (_monthlyRevenue.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildBarChart(context),
                  ),
                ),
              ],

              // ── Revenue by Property ────────────────────────
              if (_propertyRevenue.isNotEmpty) ...[
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
                      padding:
                          EdgeInsets.fromLTRB(16, i == 0 ? 10 : 8, 16, 0),
                      child: _propertyRevenueCard(ctx, _propertyRevenue[i]),
                    ),
                    childCount: _propertyRevenue.length,
                  ),
                ),
              ],

              // ── Paid Bookings ──────────────────────────────
              if (_paidBookings.isNotEmpty) ...[
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
                      padding:
                          EdgeInsets.fromLTRB(16, i == 0 ? 10 : 8, 16, 0),
                      child: _paidBookingCard(ctx, _paidBookings[i]),
                    ),
                    childCount: _paidBookings.length,
                  ),
                ),
              ],

              // ── Summary Footer ─────────────────────────────
              if (_paidBookings.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _kGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _kGreen.withValues(alpha: 0.2)),
                      ),
                      child: Column(children: [
                        _summaryRow('إجمالي الحجوزات المدفوعة',
                            '${_paidBookings.length} حجز'),
                        const Divider(height: 16),
                        _summaryRow(
                          'متوسط قيمة الحجز',
                          '${(_paidBookings.map((b) => b.totalPrice).fold(0.0, (a, b) => a + b) / _paidBookings.length).toStringAsFixed(0)} ج.م',
                        ),
                        if (_propertyRevenue.isNotEmpty) ...[
                          const Divider(height: 16),
                          _summaryRow(
                            'أعلى إيراد — عقار واحد',
                            '${(_propertyRevenue.first['amount'] as double).toStringAsFixed(0)} ج.م',
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),

              // ── Empty state ────────────────────────────────
              if (_paidBookings.isEmpty && _propertyRevenue.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        Icon(Icons.bar_chart_rounded,
                            size: 56,
                            color: context.kSub.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text('لا توجد بيانات إيرادات بعد',
                            style: TextStyle(
                                fontSize: 14,
                                color: context.kSub,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Bar Chart ──────────────────────────────────────────────
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
            'الإيرادات الشهرية',
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
                          (item['month'] as String).length > 3
                              ? (item['month'] as String).substring(0, 3)
                              : (item['month'] as String),
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
  Widget _propertyRevenueCard(
      BuildContext context, Map<String, dynamic> prop) {
    final totalPropRevenue = _propertyRevenue
        .map((p) => p['amount'] as double)
        .fold(0.0, (a, b) => a + b);
    final pct = totalPropRevenue > 0
        ? (prop['amount'] as double) / totalPropRevenue
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kOcean.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.apartment_rounded,
                    color: _kOcean, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prop['name'] as String,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.kText)),
                      Text('${prop['bookings']} حجز',
                          style: TextStyle(
                              fontSize: 11, color: context.kSub)),
                    ]),
              ),
              Text(
                '${(prop['amount'] as double).toStringAsFixed(0)} ج.م',
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
  Widget _paidBookingCard(BuildContext context, BookingModel booking) {
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
          child: const Icon(Icons.receipt_long_rounded,
              color: _kGreen, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.guest?.name ?? 'ضيف',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.kText)),
                Text(booking.property?.name ?? 'عقار #${booking.propertyId}',
                    style: TextStyle(fontSize: 11, color: context.kSub)),
                Text(
                    '${_fmtDate(booking.checkIn)} → ${_fmtDate(booking.checkOut)}',
                    style: TextStyle(fontSize: 10, color: context.kSub)),
              ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '${booking.totalPrice.toStringAsFixed(0)} ج.م',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _kGreen),
          ),
          Text(booking.bookingCode,
              style: TextStyle(fontSize: 10, color: context.kSub)),
        ]),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────
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
