// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Commission Detail Page
//  Total commission + percentage breakdown + monthly chart +
//  transaction list per booking
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../widgets/constants.dart';

const _kOcean  = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF4CAF50);
const _kPurple = Color(0xFF7E57C2);

// ── Mock Data ─────────────────────────────────────────────────
final _monthlyCommission = [
  {'month': 'يناير',  'amount': 850.0},
  {'month': 'فبراير', 'amount': 1230.0},
  {'month': 'مارس',   'amount': 980.0},
  {'month': 'أبريل',  'amount': 1560.0},
  {'month': 'مايو',   'amount': 1820.0},
  {'month': 'يونيو',  'amount': 2000.0},
];

const _commissionRate = 10.0; // 10%

final _commissionTransactions = [
  {'code': 'BK-1001', 'guest': 'أحمد محمود',   'property': 'شاليه النخيل', 'total': 2400.0, 'commission': 240.0},
  {'code': 'BK-1002', 'guest': 'سارة أحمد',    'property': 'فيلا البحر',   'total': 3200.0, 'commission': 320.0},
  {'code': 'BK-1003', 'guest': 'محمد علي',     'property': 'استديو النهر', 'total': 850.0,  'commission': 85.0},
  {'code': 'BK-1004', 'guest': 'نورا حسين',    'property': 'شقة الجبل',   'total': 1600.0, 'commission': 160.0},
  {'code': 'BK-1005', 'guest': 'كريم إبراهيم', 'property': 'شاليه النخيل', 'total': 2800.0, 'commission': 280.0},
  {'code': 'BK-1006', 'guest': 'منى حسن',      'property': 'كوتج الريف',  'total': 1200.0, 'commission': 120.0},
  {'code': 'BK-1007', 'guest': 'عمر يوسف',     'property': 'فيلا البحر',  'total': 4000.0, 'commission': 400.0},
  {'code': 'BK-1008', 'guest': 'ليلى سامي',    'property': 'استديو النهر','total': 750.0,  'commission': 75.0},
  {'code': 'BK-1009', 'guest': 'هيثم خالد',    'property': 'شاليه النخيل', 'total': 1900.0, 'commission': 190.0},
  {'code': 'BK-1010', 'guest': 'دينا رضا',     'property': 'فيلا البحر',  'total': 2600.0, 'commission': 260.0},
];

class AdminCommissionDetailPage extends StatelessWidget {
  final double totalCommission;
  const AdminCommissionDetailPage({super.key, this.totalCommission = 2000});

  double get _maxAmount => _monthlyCommission
      .map((e) => e['amount'] as double)
      .reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    final totalBookingRevenue = _commissionTransactions
        .map((t) => t['total'] as double)
        .reduce((a, b) => a + b);
    final totalCommissionCalc = _commissionTransactions
        .map((t) => t['commission'] as double)
        .reduce((a, b) => a + b);

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

            // ── Hero Summary Cards ───────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Row(children: [
                  _heroCard(context,
                      label: 'إجمالي العمولة',
                      value: '${totalCommission.toStringAsFixed(0)} ج.م',
                      icon: Icons.account_balance_wallet_rounded,
                      color: _kPurple),
                  const SizedBox(width: 12),
                  _heroCard(context,
                      label: 'نسبة العمولة',
                      value: '$_commissionRate%',
                      icon: Icons.percent_rounded,
                      color: _kOcean),
                ]),
              ),
            ),

            // ── Monthly Commission Chart ─────────────────────
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
                    border: Border.all(color: _kPurple.withValues(alpha: 0.2)),
                  ),
                  child: Column(children: [
                    _breakdownRow(context, 'إجمالي إيرادات الحجوزات',
                        '${totalBookingRevenue.toStringAsFixed(0)} ج.م', _kOcean),
                    const Divider(height: 16),
                    _breakdownRow(context, 'عمولة المنصة (10%)',
                        '${totalCommissionCalc.toStringAsFixed(0)} ج.م', _kPurple),
                    const Divider(height: 16),
                    _breakdownRow(context, 'صافي إيرادات الملاك',
                        '${(totalBookingRevenue - totalCommissionCalc).toStringAsFixed(0)} ج.م',
                        _kGreen),
                    const Divider(height: 16),
                    _breakdownRow(context, 'عدد الحجوزات',
                        '${_commissionTransactions.length} حجز', null),
                  ]),
                ),
              ),
            ),

            // ── Commission Per Booking ───────────────────────
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
                  padding: EdgeInsets.fromLTRB(16, i == 0 ? 10 : 8, 16, 0),
                  child: _transactionCard(ctx, _commissionTransactions[i]),
                ),
                childCount: _commissionTransactions.length,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
                              color: _kPurple),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 100 * pct,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [_kPurple, _kPurple.withValues(alpha: 0.6)],
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
  Widget _transactionCard(
      BuildContext context, Map<String, dynamic> txn) {
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(txn['guest'] as String,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.kText)),
            Text(txn['property'] as String,
                style: TextStyle(fontSize: 11, color: context.kSub)),
            Text('إجمالي الحجز: ${txn['total']} ج.م',
                style: TextStyle(fontSize: 10, color: context.kSub)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '${txn['commission']} ج.م',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _kPurple),
          ),
          Container(
            margin: const EdgeInsets.only(top: 3),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _kPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$_commissionRate%',
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _kPurple)),
          ),
        ]),
      ]),
    );
  }
}
