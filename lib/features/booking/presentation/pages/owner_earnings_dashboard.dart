// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Owner Earnings Dashboard
//  Total earnings, date-grouped, search by code, date filter
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../widgets/constants.dart';
import '../../data/models/booking_model.dart';
import '../providers/booking_providers.dart';
import '../widgets/booking_card_widget.dart';

const _kOcean  = Color(0xFF1565C0);
const _kGreen  = Color(0xFF4CAF50);
const _kOrange = Color(0xFFFF6D00);

class OwnerEarningsDashboard extends ConsumerStatefulWidget {
  const OwnerEarningsDashboard({super.key});
  @override
  ConsumerState<OwnerEarningsDashboard> createState() =>
      _OwnerEarningsDashboardState();
}

class _OwnerEarningsDashboardState
    extends ConsumerState<OwnerEarningsDashboard> {
  final _searchCtrl = TextEditingController();
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: _kOcean),
        ),
        child: child!,
      ),
    );
    if (range != null) setState(() => _dateRange = range);
  }

  List<BookingModel> _filterBookings(List<BookingModel> all) {
    var list = all;

    // Date range filter
    if (_dateRange != null) {
      list = list.where((b) {
        return !b.bookingDate.isBefore(_dateRange!.start) &&
            !b.bookingDate.isAfter(
                _dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Search by booking code
    final q = _searchCtrl.text.trim().toUpperCase();
    if (q.isNotEmpty) {
      list = list
          .where((b) => b.bookingCode.toUpperCase().contains(q))
          .toList();
    }

    return list;
  }

  Map<String, List<BookingModel>> _groupByDate(List<BookingModel> list) {
    final map = <String, List<BookingModel>>{};
    for (final b in list) {
      final key = DateFormat('dd MMMM yyyy', 'ar').format(b.bookingDate);
      map.putIfAbsent(key, () => []).add(b);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(ownerBookingsStreamProvider);

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
        title: Text('أرباحي',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
                _dateRange != null
                    ? Icons.filter_alt_rounded
                    : Icons.filter_alt_off_rounded,
                color: _dateRange != null ? _kOcean : context.kSub,
                size: 20),
            onPressed: _pickDateRange,
          ),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.clear_rounded,
                  color: _kOrange, size: 18),
              onPressed: () => setState(() => _dateRange = null),
            ),
        ],
      ),
      body: bookingsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kOcean)),
        error: (e, _) => Center(
            child: Text('خطأ في التحميل',
                style: TextStyle(color: context.kSub))),
        data: (allBookings) {
          final filtered = _filterBookings(allBookings);
          final totalEarnings =
              filtered.fold<double>(0, (s, b) => s + b.ownerEarnings);
          final totalBookings = filtered.length;
          final grouped = _groupByDate(filtered);

          return Column(children: [
            // ── Stats header ──────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                _statCard(context, 'إجمالي الأرباح',
                    '${totalEarnings.toStringAsFixed(0)} جنيه', _kGreen),
                const SizedBox(width: 12),
                _statCard(context, 'عدد الحجوزات',
                    '$totalBookings', _kOcean),
              ]),
            ),

            // ── Search ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'بحث بكود الحجز...',
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: _kOcean),
                  filled: true,
                  fillColor: context.kCard,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.kBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.kBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: _kOcean, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Bookings list ─────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _emptyState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: grouped.length,
                      itemBuilder: (_, i) {
                        final date = grouped.keys.elementAt(i);
                        final items = grouped[date]!;
                        final dayEarnings = items.fold<double>(
                            0, (s, b) => s + b.ownerEarnings);
                        return Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Row(children: [
                                  Text(date,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: context.kText)),
                                  const Spacer(),
                                  Text(
                                      '${dayEarnings.toStringAsFixed(0)} جنيه',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _kGreen)),
                                ]),
                              ),
                              ...items.map((b) => BookingCardWidget(
                                    booking: b,
                                    showOwnerEarnings: true,
                                  )),
                            ]);
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _statCard(
          BuildContext context, String label, String value, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 12, color: context.kSub)),
          ]),
        ),
      );

  Widget _emptyState(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded,
                size: 48, color: context.kBorder),
            const SizedBox(height: 12),
            Text('لا توجد حجوزات',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.kText)),
          ],
        ),
      );
}
