// ═══════════════════════════════════════════════════════════════
//  TALAA — Availability Calendar Editor
//  Visual per-day calendar for hosts to manage pricing overrides,
//  minimum-stay rules, and closed dates.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/availability_service.dart';
import '../widgets/constants.dart';

// Accent colours (same light & dark)
const _kOcean = Color(0xFFFF6B35);
const _kOrange = Color(0xFFFF6D00);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);

class AvailabilityCalendarPage extends StatefulWidget {
  final int propertyId;
  final String propertyName;

  const AvailabilityCalendarPage({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  @override
  State<AvailabilityCalendarPage> createState() =>
      _AvailabilityCalendarPageState();
}

class _AvailabilityCalendarPageState extends State<AvailabilityCalendarPage> {
  final _svc = AvailabilityService();

  late DateTime _focusMonth;
  List<DayDetail> _days = [];
  List<AvailabilityRule> _rules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusMonth = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final start = _focusMonth;
      final end = DateTime(start.year, start.month + 2, 1);
      final results = await Future.wait([
        _svc.getCalendarGrid(widget.propertyId, start: start, end: end),
        _svc.getRules(widget.propertyId, fromDate: start, toDate: end),
      ]);
      if (mounted) {
        setState(() {
          _days = results[0] as List<DayDetail>;
          _rules = results[1] as List<AvailabilityRule>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل التقويم: $e')),
        );
      }
    }
  }

  void _prevMonth() {
    setState(() {
      _focusMonth = DateTime(_focusMonth.year, _focusMonth.month - 1);
    });
    _load();
  }

  void _nextMonth() {
    setState(() {
      _focusMonth = DateTime(_focusMonth.year, _focusMonth.month + 1);
    });
    _load();
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: const Color(0xFFB54414),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إدارة التقويم',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(widget.propertyName,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7))),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showRulesList,
            icon: const Icon(Icons.list_alt_rounded),
            tooltip: 'كل القواعد',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOcean))
          : RefreshIndicator(
              onRefresh: _load,
              color: _kOcean,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  _buildMonthNavigation(),
                  const SizedBox(height: 12),
                  _buildLegend(),
                  const SizedBox(height: 12),
                  _buildCalendarGrid(),
                  const SizedBox(height: 20),
                  _buildRulesSummary(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRuleSheet,
        backgroundColor: _kOcean,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('قاعدة جديدة',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── Month Navigation ────────────────────────────────────────

  Widget _buildMonthNavigation() {
    final label = DateFormat.yMMMM('ar').format(_focusMonth);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _prevMonth,
          icon: const Icon(Icons.chevron_right_rounded, size: 28),
        ),
        Text(label,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.kText)),
        IconButton(
          onPressed: _nextMonth,
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
        ),
      ],
    );
  }

  // ── Legend ────────────────────────────────────────────────────

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _legendDot(Colors.grey.shade300, 'متاح'),
        _legendDot(_kOrange, 'سعر مخصص'),
        _legendDot(_kRed, 'مغلق'),
        _legendDot(_kOcean, 'محجوز'),
        _legendDot(Colors.purple.shade300, 'محظور (iCal)'),
      ],
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontSize: 11, color: context.kSub)),
    ]);
  }

  // ── Calendar Grid ────────────────────────────────────────────

  Widget _buildCalendarGrid() {
    // Build day cells for the focus month
    final daysInMonth =
        DateTime(_focusMonth.year, _focusMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_focusMonth.year, _focusMonth.month, 1).weekday % 7;

    // Day headers (Sat-Fri for Arabic locale)
    const dayNames = ['س', 'أ', 'إ', 'ث', 'أ', 'خ', 'ج'];

    return Container(
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        // Header row
        Row(
          children: dayNames
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.kSub)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        // Day cells
        ...List.generate(
          ((firstWeekday + daysInMonth + 6) ~/ 7),
          (week) => Row(
            children: List.generate(7, (col) {
              final dayIndex = week * 7 + col - firstWeekday + 1;
              if (dayIndex < 1 || dayIndex > daysInMonth) {
                return const Expanded(child: SizedBox(height: 56));
              }
              final dayDate =
                  DateTime(_focusMonth.year, _focusMonth.month, dayIndex);
              return Expanded(child: _buildDayCell(dayDate));
            }),
          ),
        ),
      ]),
    );
  }

  Widget _buildDayCell(DateTime dayDate) {
    // Find the matching DayDetail
    final detail = _days.cast<DayDetail?>().firstWhere(
      (d) =>
          d!.date.year == dayDate.year &&
          d.date.month == dayDate.month &&
          d.date.day == dayDate.day,
      orElse: () => null,
    );

    Color bgColor = Colors.grey.shade100;
    Color textColor = context.kText;
    String? priceLabel;

    if (detail != null) {
      if (detail.isClosed) {
        bgColor = _kRed.withValues(alpha: 0.15);
        textColor = _kRed;
      } else if (detail.isBooked) {
        bgColor = _kOcean.withValues(alpha: 0.15);
        textColor = _kOcean;
      } else if (detail.isBlocked) {
        bgColor = Colors.purple.shade100;
        textColor = Colors.purple.shade700;
      } else if (detail.effectivePrice != detail.basePrice) {
        bgColor = _kOrange.withValues(alpha: 0.12);
        textColor = _kOrange;
        priceLabel = detail.effectivePrice.toInt().toString();
      } else {
        priceLabel = detail.basePrice.toInt().toString();
      }
    }

    final isToday = dayDate.year == DateTime.now().year &&
        dayDate.month == DateTime.now().month &&
        dayDate.day == DateTime.now().day;

    return GestureDetector(
      onTap: () => _onDayTapped(dayDate, detail),
      child: Container(
        height: 56,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: _kOcean, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${dayDate.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            if (priceLabel != null)
              Text(
                priceLabel,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            if (detail != null && detail.minNights > 1)
              Text(
                '≥${detail.minNights}',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: _kGreen,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Day tap → quick actions sheet ───────────────────────────

  void _onDayTapped(DateTime day, DayDetail? detail) {
    final dayStr = DateFormat.yMMMd('ar').format(day);
    showModalBottomSheet(
      context: context,
      backgroundColor: context.kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(dayStr,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.kText)),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                'السعر: ${detail.effectivePrice.toInt()} ج.م  '
                '${detail.isClosed ? '(مغلق)' : ''}'
                '${detail.isBooked ? '(محجوز)' : ''}'
                '${detail.isBlocked ? '(محظور)' : ''}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.kSub),
              ),
            ],
            const SizedBox(height: 16),
            _sheetAction(
              icon: Icons.attach_money_rounded,
              label: 'تسعير مخصص',
              color: _kOrange,
              onTap: () {
                Navigator.pop(context);
                _showPricingDialog(day);
              },
            ),
            _sheetAction(
              icon: Icons.nights_stay_rounded,
              label: 'حد أدنى للإقامة',
              color: _kGreen,
              onTap: () {
                Navigator.pop(context);
                _showMinStayDialog(day);
              },
            ),
            _sheetAction(
              icon: Icons.block_rounded,
              label: 'إغلاق اليوم',
              color: _kRed,
              onTap: () {
                Navigator.pop(context);
                _closeDays(day, day.add(const Duration(days: 1)));
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sheetAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Pricing dialog ──────────────────────────────────────────

  void _showPricingDialog(DateTime day) {
    final ctrl = TextEditingController();
    final endDay = day.add(const Duration(days: 1));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تسعير مخصص',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat.yMMMd('ar').format(day),
              style: TextStyle(color: context.kSub, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'السعر (ج.م)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(color: context.kSub)),
          ),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(ctrl.text);
              if (price == null || price <= 0) return;
              Navigator.pop(context);
              await _svc.createRule(
                widget.propertyId,
                ruleType: RuleType.pricing,
                startDate: day,
                endDate: endDay,
                priceOverride: price,
              );
              _load();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // ── Min-stay dialog ─────────────────────────────────────────

  void _showMinStayDialog(DateTime day) {
    final ctrl = TextEditingController();
    final endDay = day.add(const Duration(days: 7));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حد أدنى للإقامة',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'من ${DateFormat.yMMMd('ar').format(day)} '
              'إلى ${DateFormat.yMMMd('ar').format(endDay)}',
              style: TextStyle(color: context.kSub, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'عدد الليالي',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(color: context.kSub)),
          ),
          ElevatedButton(
            onPressed: () async {
              final nights = int.tryParse(ctrl.text);
              if (nights == null || nights < 1) return;
              Navigator.pop(context);
              await _svc.createRule(
                widget.propertyId,
                ruleType: RuleType.minStay,
                startDate: day,
                endDate: endDay,
                minNights: nights,
              );
              _load();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // ── Close days ──────────────────────────────────────────────

  Future<void> _closeDays(DateTime start, DateTime end) async {
    try {
      await _svc.createRule(
        widget.propertyId,
        ruleType: RuleType.closed,
        startDate: start,
        endDate: end,
        label: 'مغلق يدوياً',
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل: $e')),
        );
      }
    }
  }

  // ── Rules summary ────────────────────────────────────────────

  Widget _buildRulesSummary() {
    if (_rules.isEmpty) {
      return Center(
        child: Text('لا توجد قواعد حالياً',
            style: TextStyle(color: context.kSub, fontSize: 13)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('القواعد النشطة',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.kText)),
        const SizedBox(height: 8),
        ..._rules.map((r) => _ruleCard(r)),
      ],
    );
  }

  Widget _ruleCard(AvailabilityRule r) {
    Color color;
    IconData icon;
    String subtitle;
    switch (r.ruleType) {
      case RuleType.pricing:
        color = _kOrange;
        icon = Icons.attach_money_rounded;
        subtitle = '${r.priceOverride?.toInt()} ج.م / ليلة';
        break;
      case RuleType.minStay:
        color = _kGreen;
        icon = Icons.nights_stay_rounded;
        subtitle = 'حد أدنى ${r.minNights} ليالي';
        break;
      case RuleType.closed:
        color = _kRed;
        icon = Icons.block_rounded;
        subtitle = 'مغلق';
        break;
      case RuleType.note:
        color = Colors.grey;
        icon = Icons.note_rounded;
        subtitle = r.note ?? '';
        break;
    }

    final from = DateFormat.MMMd('ar').format(r.startDate);
    final to = DateFormat.MMMd('ar').format(r.endDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          r.label ?? ruleTypeLabelAr(r.ruleType),
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13, color: context.kText),
        ),
        subtitle: Text('$from – $to  •  $subtitle',
            style: TextStyle(fontSize: 11, color: context.kSub)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
          color: _kRed,
          onPressed: () => _deleteRule(r),
        ),
      ),
    );
  }

  Future<void> _deleteRule(AvailabilityRule r) async {
    try {
      await _svc.deleteRule(widget.propertyId, r.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: $e')),
        );
      }
    }
  }

  // ── Add rule sheet ──────────────────────────────────────────

  void _showAddRuleSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('إضافة قاعدة جديدة',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.kText)),
            const SizedBox(height: 16),
            _sheetAction(
              icon: Icons.attach_money_rounded,
              label: 'تسعير مخصص',
              color: _kOrange,
              onTap: () {
                Navigator.pop(context);
                _showPricingDialog(DateTime.now().add(const Duration(days: 7)));
              },
            ),
            _sheetAction(
              icon: Icons.nights_stay_rounded,
              label: 'حد أدنى للإقامة',
              color: _kGreen,
              onTap: () {
                Navigator.pop(context);
                _showMinStayDialog(DateTime.now().add(const Duration(days: 7)));
              },
            ),
            _sheetAction(
              icon: Icons.block_rounded,
              label: 'إغلاق فترة',
              color: _kRed,
              onTap: () {
                Navigator.pop(context);
                final start = DateTime.now().add(const Duration(days: 7));
                _closeDays(start, start.add(const Duration(days: 3)));
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Rules list overlay ──────────────────────────────────────

  void _showRulesList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Text('كل القواعد',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.kText)),
            const SizedBox(height: 16),
            if (_rules.isEmpty)
              Center(
                child: Text('لا توجد قواعد',
                    style: TextStyle(color: context.kSub)),
              )
            else
              ..._rules.map((r) => _ruleCard(r)),
          ],
        ),
      ),
    );
  }
}
