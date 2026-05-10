// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Analytics Dashboard  (Wave 30)
//
//  Single-screen overview for the ops team:
//    • Headline KPIs  (revenue, fees, bookings, users…)
//    • 6-month revenue + bookings bar chart (no extra deps —
//      drawn with a CustomPainter so the page works even without
//      a charts package).
//    • Top 5 areas leaderboard
//    • Top 10 properties (revenue ranked)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../services/admin_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';

const _kOcean = Color(0xFFFF6B35);
const _kGreen = Color(0xFF4CAF50);
const _kOrange = Color(0xFFFF6D00);
const _kPurple = Color(0xFF7E57C2);
const _kRed = Color(0xFFEF5350);

class AdminAnalyticsDashboardPage extends StatefulWidget {
  const AdminAnalyticsDashboardPage({super.key});
  @override
  State<AdminAnalyticsDashboardPage> createState() =>
      _AdminAnalyticsDashboardPageState();
}

class _AdminAnalyticsDashboardPageState
    extends State<AdminAnalyticsDashboardPage> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  String? _error;

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
      _data = await AdminService.getAdvancedAnalytics();
    } on ApiException catch (e) {
      _error = ErrorHandler.getMessage(e);
    } catch (e) {
      _error = '$e';
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
        title: const Text('التحليلات المتقدمة',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOcean))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 48,
                            color: _kRed.withValues(alpha: 0.7)),
                        const SizedBox(height: 12),
                        Text('فشل التحميل\n$_error',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: context.kSub, fontSize: 13)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _kOcean),
                          child: const Text('إعادة المحاولة',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : _data == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      color: _kOcean,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _kpiGrid(_data!),
                          const SizedBox(height: 16),
                          _section('الإيرادات الشهرية'),
                          _MonthlyChart(
                            points: (_data!['monthly'] as List? ?? [])
                                .cast<Map<String, dynamic>>(),
                          ),
                          const SizedBox(height: 16),
                          _section('أعلى المناطق نشاطاً'),
                          _topAreas(_data!['top_areas'] as List? ?? []),
                          const SizedBox(height: 16),
                          _section('أعلى 10 عقارات بالإيرادات'),
                          _topProperties(
                              _data!['top_properties'] as List? ?? []),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: context.kText)),
      );

  Widget _kpiGrid(Map<String, dynamic> d) {
    final fmt = intl.NumberFormat('#,##0');
    return Column(children: [
      Row(children: [
        _kpiCard(
          label: 'إجمالي الإيرادات',
          value: '${fmt.format(d['total_revenue'] ?? 0)} ج.م',
          icon: Icons.payments_rounded,
          color: _kOrange,
        ),
        const SizedBox(width: 10),
        _kpiCard(
          label: 'عمولة المنصة',
          value: '${fmt.format(d['total_platform_fees'] ?? 0)} ج.م',
          icon: Icons.account_balance_wallet_rounded,
          color: _kGreen,
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _kpiCard(
          label: 'مجموع الحجوزات',
          value: '${d['total_bookings'] ?? 0}',
          icon: Icons.calendar_month_rounded,
          color: _kOcean,
        ),
        const SizedBox(width: 10),
        _kpiCard(
          label: 'حجوزات مدفوعة',
          value: '${d['paid_bookings'] ?? 0}',
          icon: Icons.check_circle_rounded,
          color: _kGreen,
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _kpiCard(
          label: 'حجوزات ملغاة',
          value: '${d['cancelled_bookings'] ?? 0}',
          icon: Icons.cancel_rounded,
          color: _kRed,
        ),
        const SizedBox(width: 10),
        _kpiCard(
          label: 'مستخدمون جدد (٣٠ ي)',
          value: '${d['new_users_30d'] ?? 0}',
          icon: Icons.person_add_rounded,
          color: _kPurple,
        ),
      ]),
    ]);
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: context.kText)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: context.kSub,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _topAreas(List rows) {
    if (rows.isEmpty) {
      return _emptyState('لا توجد بيانات بعد', Icons.location_on_rounded);
    }
    final fmt = intl.NumberFormat('#,##0');
    return Container(
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        children: List.generate(rows.length, (i) {
          final r = rows[i] as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _kOcean.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _kOcean,
                          fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(r['area'] as String? ?? '—',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: context.kText)),
              ),
              Text('${fmt.format(r['bookings'] ?? 0)} حجز',
                  style: TextStyle(
                      fontSize: 11,
                      color: context.kSub,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('${fmt.format(r['revenue'] ?? 0)} ج.م',
                  style: const TextStyle(
                      color: _kGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ]),
          );
        }),
      ),
    );
  }

  Widget _topProperties(List rows) {
    if (rows.isEmpty) {
      return _emptyState('لا توجد بيانات بعد', Icons.apartment_rounded);
    }
    final fmt = intl.NumberFormat('#,##0');
    return Container(
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        children: List.generate(rows.length, (i) {
          final r = rows[i] as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _kOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _kOrange,
                          fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['property_name'] as String? ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: context.kText)),
                    Text('#${r['property_id']} • ${fmt.format(r['bookings'] ?? 0)} حجز',
                        style: TextStyle(
                            fontSize: 10,
                            color: context.kSub,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Text('${fmt.format(r['revenue'] ?? 0)} ج.م',
                  style: const TextStyle(
                      color: _kGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ]),
          );
        }),
      ),
    );
  }

  Widget _emptyState(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(children: [
        Icon(icon, size: 48, color: context.kSub.withValues(alpha: 0.4)),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                color: context.kSub,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Monthly bar chart — pure CustomPainter, no extra deps.
// ═══════════════════════════════════════════════════════════════
class _MonthlyChart extends StatelessWidget {
  final List<Map<String, dynamic>> points;
  const _MonthlyChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.kBorder),
        ),
        child: Column(children: [
          Icon(Icons.bar_chart_rounded,
              size: 48,
              color: context.kSub.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text('لا توجد بيانات شهرية بعد',
              style: TextStyle(
                  color: context.kSub,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      );
    }
    final maxRev = points.fold<double>(
        0, (m, p) => (p['revenue'] as num).toDouble() > m
            ? (p['revenue'] as num).toDouble()
            : m);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
      ),
      child: SizedBox(
        height: 200,
        child: CustomPaint(
          painter: _BarChartPainter(
            points: points,
            maxRevenue: maxRev <= 0 ? 1 : maxRev,
            barColor: _kOcean,
            textColor: Theme.of(context).textTheme.bodySmall?.color ??
                Colors.black54,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> points;
  final double maxRevenue;
  final Color barColor;
  final Color textColor;

  _BarChartPainter({
    required this.points,
    required this.maxRevenue,
    required this.barColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const padBottom = 28.0;
    const padTop = 20.0;
    final usableH = size.height - padBottom - padTop;
    final barW = (size.width - 12) / points.length - 6;
    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;
    final textStyle = TextStyle(
      color: textColor.withValues(alpha: 0.7),
      fontSize: 9,
      fontWeight: FontWeight.w700,
    );

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final rev = (p['revenue'] as num).toDouble();
      final h = (rev / maxRevenue) * usableH;
      final x = 6 + i * (barW + 6);
      final y = size.height - padBottom - h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barW, h),
          const Radius.circular(6),
        ),
        paint,
      );
      // Month label.
      final monthLabel = _shortMonth(p['month'] as String? ?? '');
      final tp = TextPainter(
        text: TextSpan(text: monthLabel, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(x + (barW - tp.width) / 2, size.height - padBottom + 6),
      );
      // Value label on top of bar (only if there's room).
      if (h > 24) {
        final shortRev = rev >= 1000
            ? '${(rev / 1000).toStringAsFixed(rev >= 10000 ? 0 : 1)}k'
            : rev.toStringAsFixed(0);
        final vp = TextPainter(
          text: TextSpan(
              text: shortRev,
              style: textStyle.copyWith(
                  color: textColor.withValues(alpha: 0.9))),
          textDirection: TextDirection.ltr,
        )..layout();
        vp.paint(canvas, Offset(x + (barW - vp.width) / 2, y - 14));
      }
    }
  }

  /// Convert ``YYYY-MM`` to ``MMM`` (English short month) for the
  /// x-axis label.  We keep it ASCII so the layout doesn't shift
  /// between Arabic / English locales.
  String _shortMonth(String iso) {
    if (iso.length < 7) return iso;
    final m = int.tryParse(iso.substring(5, 7)) ?? 0;
    const names = [
      '',
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return m >= 1 && m <= 12 ? '${names[m]}-${iso.substring(2, 4)}' : iso;
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.points != points || old.maxRevenue != maxRevenue;
}
