// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Commission Detail Page
//  Total commission + percentage breakdown + monthly chart +
//  transaction list per booking — all from real API.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../models/booking_model.dart';
import '../../services/admin_service.dart';
import '../../widgets/constants.dart';

const _kOcean  = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF4CAF50);
const _kPurple = Color(0xFF7E57C2);

const _arMonths = {
  '01': 'يناير',  '02': 'فبراير', '03': 'مارس',
  '04': 'أبريل',  '05': 'مايو',   '06': 'يونيو',
  '07': 'يوليو',  '08': 'أغسطس',  '09': 'سبتمبر',
  '10': 'أكتوبر', '11': 'نوفمبر', '12': 'ديسمبر',
};

String _fmtMonth(String raw) {
  if (raw.contains('-') && raw.length >= 7) {
    return _arMonths[raw.substring(5, 7)] ?? raw;
  }
  return raw;
}

class AdminCommissionDetailPage extends StatefulWidget {
  final double totalCommission;
  const AdminCommissionDetailPage({super.key, this.totalCommission = 0});

  @override
  State<AdminCommissionDetailPage> createState() =>
      _AdminCommissionDetailPageState();
}

class _AdminCommissionDetailPageState
    extends State<AdminCommissionDetailPage> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _monthlyCommission = [];
  List<BookingModel> _paidBookings = [];
  double _commissionRate = 10.0;

  // Computed totals
  double get _totalBookingRevenue =>
      _paidBookings.fold(0.0, (s, b) => s + b.totalPrice);
  double get _totalCommission =>
      _paidBookings.fold(0.0, (s, b) => s + b.platformFee);
  double get _totalOwnerPayout =>
      _paidBookings.fold(0.0, (s, b) => s + b.ownerPayout);
  double get _displayedCommission =>
      widget.totalCommission > 0 ? widget.totalCommission : _totalCommission;

  double get _maxBar {
    if (_monthlyCommission.isEmpty) return 1;
    return _monthlyCommission
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
        AdminService.getPlatformSettings(),
      ]);

      final financial = results[0] as Map<String, dynamic>;
      final bookings  = results[1] as List<BookingModel>;
      final settings  = results[2] as Map<String, dynamic>;

      // ── Commission rate from settings ──────────────────────
      final rate = (settings['platform_fee_percent'] ??
                    settings['commission_rate'] ??
                    settings['fee_percent'] ??
                    10) as num;

      // ── Monthly commission from financial report ───────────
      final rawMonthly = (financial['monthly_commission'] as List?) ??
                         (financial['monthly_revenue']   as List?) ?? [];
      List<Map<String, dynamic>> monthly =
          rawMonthly.map<Map<String, dynamic>>((e) {
        final m = e as Map<String, dynamic>;
        // Prefer explicit commission key; fallback: revenue × rate/100
        final rev = ((m['revenue'] ?? m['amount'] ?? 0) as num).toDouble();
        final comm = ((m['commission'] ?? m['platform_fee'] ?? rev * rate / 100)
                as num)
            .toDouble();
        return {
          'month': _fmtMonth((m['month'] ?? m['period'] ?? '').toString()),
          'amount': comm,
        };
      }).toList();

      // If API gave no monthly data, compute from bookings by month.
      if (monthly.isEmpty && bookings.isNotEmpty) {
        final map = <String, double>{};
        for (final b in bookings) {
          final key =
              '${b.createdAt.year}-${b.createdAt.month.toString().padLeft(2, '0')}';
          map[key] = (map[key] ?? 0) + b.platformFee;
        }
        final sorted = map.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        monthly = sorted
            .map((e) => {'month': _fmtMonth(e.key), 'amount': e.value})
            .toList();
      }

      setState(() {
        _commissionRate    = rate.toDouble();
        _monthlyCommission = monthly;
        _paidBookings      = bookings;
        _loading           = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
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
              backgroundColor: _kPurple,
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
                title: const Text('تفاصيل عمولة المنصة',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_kPurple.withValues(alpha: 0.8), _kPurple],
                    ),
                  ),
                ),
              ),
            ),

            // ── Loading / Error ───────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: _kPurple),
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
                            color: _kPurple, size: 48),
                        const SizedBox(height: 12),
                        const Text('تعذّر تحميل البيانات',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
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
              // ── Hero Summary Cards ───────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Row(children: [
                    _heroCard(context,
                        label: 'إجمالي العمولة',
                        value:
                            '${_displayedCommission.toStringAsFixed(0)} ج.م',
                        icon: Icons.account_balance_wallet_rounded,
                        color: _kPurple),
                    const SizedBox(width: 12),
                    _heroCard(context,
                        label: 'نسبة العمولة',
                        value: '${_commissionRate.toStringAsFixed(0)}%',
                        icon: Icons.percent_rounded,
                        color: _kOcean),
                  ]),
                ),
              ),

              // ── Monthly Commission Chart ─────────────────────
              if (_monthlyCommission.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildBarChart(context),
                  ),
                ),

              // ── Breakdown Summary ────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _kPurple.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: _kPurple.withValues(alpha: 0.2)),
                    ),
                    child: Column(children: [
                      _breakdownRow(
                        context,
                        'إجمالي إيرادات الحجوزات',
                        '${_totalBookingRevenue.toStringAsFixed(0)} ج.م',
                        _kOcean,
                      ),
                      const Divider(height: 16),
                      _breakdownRow(
                        context,
                        'عمولة المنصة (${_commissionRate.toStringAsFixed(0)}%)',
                        '${_totalCommission.toStringAsFixed(0)} ج.م',
                        _kPurple,
                      ),
                      const Divider(height: 16),
                      _breakdownRow(
                        context,
                        'صافي إيرادات الملاك',
                        '${_totalOwnerPayout.toStringAsFixed(0)} ج.م',
                        _kGreen,
                      ),
                      const Divider(height: 16),
                      _breakdownRow(
                        context,
                        'عدد الحجوزات',
                        '${_paidBookings.length} حجز',
                        null,
                      ),
                      if (_paidBookings.isNotEmpty) ...[
                        const Divider(height: 16),
                        _breakdownRow(
                          context,
                          'متوسط العمولة لكل حجز',
                          '${(_totalCommission / _paidBookings.length).toStringAsFixed(0)} ج.م',
                          null,
                        ),
                      ],
                    ]),
                  ),
                ),
              ),

              // ── Per Booking Transactions ─────────────────────
              if (_paidBookings.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Text('العمولة لكل حجز',
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
                      child: _transactionCard(ctx, _paidBookings[i]),
                    ),
                    childCount: _paidBookings.length,
                  ),
                ),
              ],

              // ── Empty state ──────────────────────────────────
              if (_paidBookings.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(children: [
                      Icon(Icons.bar_chart_rounded,
                          size: 56,
                          color:
                              context.kSub.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text('لا توجد حجوزات مدفوعة بعد',
                          style: TextStyle(
                              fontSize: 14,
                              color: context.kSub,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
          Text('العمولة الشهرية',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.kText)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _monthlyCommission.map((item) {
                final pct = (item['amount'] as double) / _maxBar;
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
                              color: _kPurple),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          height: 100 * pct,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                _kPurple,
                                _kPurple.withValues(alpha: 0.6)
                              ],
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

  // ── Hero Card ─────────────────────────────────────────────
  Widget _heroCard(BuildContext context,
      {required String label,
      required String value,
      required IconData icon,
      required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.kBorder),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: context.kText)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.kSub)),
            ]),
      ),
    );
  }

  // ── Breakdown Row ─────────────────────────────────────────
  Widget _breakdownRow(
      BuildContext context, String label, String value, Color? valueColor) {
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
                color: valueColor ?? context.kText)),
      ],
    );
  }

  // ── Transaction Card ──────────────────────────────────────
  Widget _transactionCard(BuildContext context, BookingModel booking) {
    final effectiveRate = booking.totalPrice > 0
        ? (booking.platformFee / booking.totalPrice * 100)
        : _commissionRate;

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
            color: _kPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.receipt_rounded, color: _kPurple, size: 18),
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
                Text(
                    booking.property?.name ??
                        'عقار #${booking.propertyId}',
                    style:
                        TextStyle(fontSize: 11, color: context.kSub)),
                Text(
                    'إجمالي الحجز: ${booking.totalPrice.toStringAsFixed(0)} ج.م',
                    style:
                        TextStyle(fontSize: 10, color: context.kSub)),
              ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '${booking.platformFee.toStringAsFixed(0)} ج.م',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _kPurple),
          ),
          Container(
            margin: const EdgeInsets.only(top: 3),
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _kPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${effectiveRate.toStringAsFixed(1)}%',
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _kPurple),
            ),
          ),
          Text(booking.bookingCode,
              style: TextStyle(fontSize: 9, color: context.kSub)),
        ]),
      ]),
    );
  }
}
