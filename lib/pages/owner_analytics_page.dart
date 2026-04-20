// ═══════════════════════════════════════════════════════════════
//  TALAA — Owner Analytics Page
//  KPIs + monthly revenue chart + top properties + occupancy heatmap.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../models/owner_analytics.dart';
import '../services/analytics_service.dart';
import '../utils/api_client.dart';
import '../utils/error_handler.dart';
import '../widgets/constants.dart';

const _kOcean = Color(0xFF1B4D5C);
const _kGreen = Color(0xFF22C55E);
const _kOrange = Color(0xFFFF6D00);
const _kAmber = Color(0xFFF59E0B);
const _kPurple = Color(0xFF7C3AED);

class OwnerAnalyticsPage extends StatefulWidget {
  const OwnerAnalyticsPage({super.key});

  @override
  State<OwnerAnalyticsPage> createState() => _OwnerAnalyticsPageState();
}

class _OwnerAnalyticsPageState extends State<OwnerAnalyticsPage> {
  String _period = 'month';
  bool _loading = true;
  String? _error;
  OwnerAnalytics? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await AnalyticsService.ownerAnalytics(period: _period);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.getMessage(e);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل البيانات';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text('التحليلات',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.kText, size: 20),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kOcean,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _kOcean));
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.error_outline_rounded,
              color: Colors.red.shade400, size: 48),
          const SizedBox(height: 16),
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.kText)),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('حاول مرة أخرى'),
            ),
          ),
        ],
      );
    }

    final d = _data;
    if (d == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _periodSwitcher(),
        const SizedBox(height: 16),
        _totalsGrid(d.totals),
        const SizedBox(height: 20),
        _revenueChart(d.monthly),
        const SizedBox(height: 20),
        _topProperties(d.topProperties),
        const SizedBox(height: 20),
        _occupancyHeatmap(d.occupancy),
      ],
    );
  }

  // ── period buttons ────────────────────────────────────────
  Widget _periodSwitcher() {
    Widget opt(String value, String label) {
      final active = _period == value;
      return Expanded(
        child: GestureDetector(
          onTap: active
              ? null
              : () {
                  setState(() => _period = value);
                  _load();
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? _kOcean : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : context.kSub,
                  )),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.kBorder),
      ),
      child: Row(children: [
        opt('month', 'شهر'),
        opt('quarter', 'ربع'),
        opt('year', 'سنة'),
      ]),
    );
  }

  // ── KPI grid ──────────────────────────────────────────────
  Widget _totalsGrid(AnalyticsTotals t) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _kpiCard(
          icon: Icons.payments_rounded,
          accent: _kGreen,
          label: 'إجمالي الأرباح',
          value: '${_comma(t.revenueTotal.toStringAsFixed(0))} ج.م',
        ),
        _kpiCard(
          icon: Icons.schedule_rounded,
          accent: _kAmber,
          label: 'أرباح متوقعة',
          value: '${_comma(t.revenuePending.toStringAsFixed(0))} ج.م',
        ),
        _kpiCard(
          icon: Icons.calendar_month_rounded,
          accent: _kOcean,
          label: 'حجوزات',
          value: t.bookingsCount.toString(),
          sub: '${t.bookingsUpcoming} قادمة',
        ),
        _kpiCard(
          icon: Icons.star_rounded,
          accent: _kOrange,
          label: 'التقييم',
          value: t.avgRating.toStringAsFixed(1),
          sub: '${t.reviewsCount} تقييم',
        ),
        _kpiCard(
          icon: Icons.home_work_rounded,
          accent: _kPurple,
          label: 'عقارات',
          value: t.propertiesCount.toString(),
        ),
        _kpiCard(
          icon: Icons.check_circle_rounded,
          accent: _kGreen,
          label: 'مكتملة',
          value: t.bookingsCompleted.toString(),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required IconData icon,
    required Color accent,
    required String label,
    required String value,
    String? sub,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: context.kText)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.kSub)),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(sub,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: accent)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── revenue chart ─────────────────────────────────────────
  Widget _revenueChart(List<MonthlyPoint> monthly) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.trending_up_rounded, color: _kGreen, size: 18),
            const SizedBox(width: 8),
            Text('الأرباح الشهرية',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: context.kText)),
          ]),
          const SizedBox(height: 14),
          if (monthly.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text('لا توجد بيانات بعد',
                    style: TextStyle(color: context.kSub, fontSize: 12)),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: CustomPaint(
                painter: _BarChartPainter(
                  data: monthly,
                  accent: _kGreen,
                  axisColor: context.kSub,
                ),
                child: Container(),
              ),
            ),
        ],
      ),
    );
  }

  // ── top 5 properties ──────────────────────────────────────
  Widget _topProperties(List<TopProperty> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.emoji_events_rounded, color: _kOrange, size: 18),
            const SizedBox(width: 8),
            Text('أفضل العقارات',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: context.kText)),
          ]),
          const SizedBox(height: 12),
          for (int i = 0; i < list.length; i++) _topRow(i + 1, list[i]),
        ],
      ),
    );
  }

  Widget _topRow(int rank, TopProperty p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 26, height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rank == 1
                ? _kAmber.withValues(alpha: 0.18)
                : context.kSand,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(rank.toString(),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: rank == 1 ? _kAmber : context.kSub)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: context.kText)),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.calendar_today_rounded,
                    size: 11, color: context.kSub),
                const SizedBox(width: 3),
                Text('${p.bookings}',
                    style: TextStyle(
                        fontSize: 10, color: context.kSub)),
                const SizedBox(width: 10),
                Icon(Icons.star_rounded, size: 11, color: _kAmber),
                const SizedBox(width: 3),
                Text(p.avgRating.toStringAsFixed(1),
                    style: TextStyle(
                        fontSize: 10, color: context.kSub)),
              ]),
            ],
          ),
        ),
        Text('${_comma(p.revenue.toStringAsFixed(0))} ج.م',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: _kGreen)),
      ]),
    );
  }

  // ── occupancy heatmap (30 days) ───────────────────────────
  Widget _occupancyHeatmap(List<OccupancyPoint> occ) {
    if (occ.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.grid_view_rounded, color: _kPurple, size: 18),
            const SizedBox(width: 8),
            Text('الإشغال — 30 يوم',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: context.kText)),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in occ)
                _heatCell(d),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Text('قليل',
                style: TextStyle(fontSize: 10, color: context.kSub)),
            const SizedBox(width: 6),
            for (final a in [0.15, 0.35, 0.6, 0.85])
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: _kPurple.withValues(alpha: a),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 4),
            Text('ممتلئ',
                style: TextStyle(fontSize: 10, color: context.kSub)),
          ]),
        ],
      ),
    );
  }

  Widget _heatCell(OccupancyPoint p) {
    final alpha = 0.10 + (p.occupancyRate.clamp(0.0, 1.0) * 0.85);
    return Tooltip(
      message:
          '${p.date.day}/${p.date.month} — ${(p.occupancyRate * 100).round()}%',
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kPurple.withValues(alpha: alpha),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(p.date.day.toString(),
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: p.occupancyRate > 0.5
                    ? Colors.white
                    : _kPurple)),
      ),
    );
  }

  String _comma(String n) => n.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ══════════════════════════════════════════════════════════════
//  Custom bar-chart painter
// ══════════════════════════════════════════════════════════════
class _BarChartPainter extends CustomPainter {
  final List<MonthlyPoint> data;
  final Color accent;
  final Color axisColor;

  _BarChartPainter({
    required this.data,
    required this.accent,
    required this.axisColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxRev = data
        .map((e) => e.revenue)
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (maxRev == 0) return;

    const topPad = 8.0;
    const bottomPad = 26.0;
    final chartHeight = size.height - topPad - bottomPad;
    final barSpace = size.width / data.length;
    final barWidth = (barSpace * 0.55).clamp(10.0, 28.0);

    final barPaint = Paint()..color = accent;
    final labelStyle = TextStyle(
      fontSize: 9,
      color: axisColor,
      fontWeight: FontWeight.w700,
    );

    for (int i = 0; i < data.length; i++) {
      final p = data[i];
      final hRatio = p.revenue / maxRev;
      final barH = chartHeight * hRatio;
      final x = i * barSpace + (barSpace - barWidth) / 2;
      final y = topPad + chartHeight - barH;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barH),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, barPaint);

      // Month label (YYYY-MM → MM)
      final monthLabel =
          p.month.contains('-') ? p.month.split('-').last : p.month;
      final tp = TextPainter(
        text: TextSpan(text: monthLabel, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          x + barWidth / 2 - tp.width / 2,
          size.height - bottomPad + 6,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.data != data || old.accent != accent;
}
