// ═══════════════════════════════════════════════════════════════
//  TALAA — Host Reservations Page  (Wave 25)
//
//  Lets the host drive the cash-on-arrival handshake from a single
//  list view: each reservation that needs attention surfaces a
//  "تأكيد استلام الكاش" / "إبلاغ عدم وصول" pair of actions.
//
//  We deliberately keep this page narrow in scope — it's not a
//  full reservations CRM (the legacy Bookings page already covers
//  cancellation / completion).  Its only job is to make the cash
//  collection state inescapable for hosts so payouts don't stall.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../widgets/constants.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

const _kOrange = Color(0xFFFF6D00);
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF5350);

class HostReservationsPage extends StatefulWidget {
  const HostReservationsPage({super.key});

  @override
  State<HostReservationsPage> createState() => _HostReservationsPageState();
}

class _HostReservationsPageState extends State<HostReservationsPage> {
  bool _loading = true;
  List<BookingModel> _bookings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await BookingService.getOwnerBookings(limit: 200);
      // Surface only hybrid bookings (the legacy ones don't need any
      // host action here — they go through the existing payouts
      // cycle).  We intentionally keep settled / no-show ones in the
      // list as a read-only audit trail.
      final filtered = list.where((b) => b.isCashOnArrival).toList()
        ..sort((a, b) => b.checkIn.compareTo(a.checkIn));
      if (!mounted) return;
      setState(() {
        _bookings = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر التحميل: $e'),
          backgroundColor: _kRed,
        ),
      );
    }
  }

  // ── Backend guards mirrored client-side ─────────────────────
  // We replicate the rules from the FastAPI endpoints so the host
  // never sees a button that's destined to 4xx.  Any drift between
  // these and the backend should be reconciled before shipping.

  bool _canConfirmCash(BookingModel b) {
    if (!b.isCashOnArrival) return false;
    if (!b.isPaid) return false;
    if (b.cashOwnerConfirmed) return false;
    if (b.cashFullyConfirmed || b.noShowReported) return false;
    final today = DateTime.now();
    return !b.checkIn.isAfter(DateTime(today.year, today.month, today.day));
  }

  bool _canReportNoShow(BookingModel b) {
    if (!b.isCashOnArrival) return false;
    // No-show is only fileable while the guest hasn't confirmed yet.
    if (b.cashGuestConfirmed) return false;
    if (b.cashFullyConfirmed || b.noShowReported) return false;
    final today = DateTime.now();
    return !b.checkIn.isAfter(DateTime(today.year, today.month, today.day));
  }

  // ── Actions ─────────────────────────────────────────────────

  Future<void> _confirmCash(BookingModel b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد استلام الكاش'),
        content: Text(
          'هل استلمت ${b.remainingCashAmount.toStringAsFixed(0)} جنيه كاش '
          'من الضيف؟ بمجرد التأكيد لن تتمكن من الإبلاغ عن عدم الوصول.',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _kGreen),
            child: const Text('نعم، استلمت'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await BookingService.confirmCashReceived(b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تأكيد استلام الكاش'),
          backgroundColor: _kGreen,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر التأكيد: $e'),
          backgroundColor: _kRed,
        ),
      );
    }
  }

  Future<void> _reportNoShow(BookingModel b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إبلاغ عدم وصول'),
        content: const Text(
          'هل تؤكد أن الضيف لم يحضر؟ سيتم احتساب العربون كتعويض لك '
          'مخصومًا منه عمولة ليلة واحدة فقط، ولا يمكن التراجع.',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            child: const Text('أبلِغ'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await BookingService.reportNoShow(b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل البلاغ'),
          backgroundColor: _kRed,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر الإبلاغ: $e'),
          backgroundColor: _kRed,
        ),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        title: const Text('استلام الكاش',
            style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: context.kText,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _kOrange))
          : RefreshIndicator(
              onRefresh: _load,
              color: _kOrange,
              child: _bookings.isEmpty
                  ? ListView(
                      // ListView (rather than Center) keeps the
                      // RefreshIndicator pull-to-refresh gesture alive
                      // even when the empty state is shown.
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'لا توجد حجوزات بدفع جزئى حالياً',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _bookings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _card(_bookings[i]),
                    ),
            ),
    );
  }

  Widget _card(BookingModel b) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
              b.propertyName.isEmpty ? 'حجز #${b.bookingCode}' : b.propertyName,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: context.kText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('#${b.bookingCode}',
              style: TextStyle(fontSize: 11, color: context.kSub)),
        ]),
        const SizedBox(height: 6),
        Text('الضيف: ${b.guest?.name ?? "—"}',
            style: TextStyle(fontSize: 12.5, color: context.kSub)),
        const SizedBox(height: 8),
        _cashStatusPill(b),
        const SizedBox(height: 10),
        _amountsRow(b),
        if (_canConfirmCash(b) || _canReportNoShow(b)) ...[
          const SizedBox(height: 12),
          Row(children: [
            if (_canConfirmCash(b))
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _confirmCash(b),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('استلمت الكاش',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w900)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (_canConfirmCash(b) && _canReportNoShow(b))
              const SizedBox(width: 10),
            if (_canReportNoShow(b))
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reportNoShow(b),
                  icon: const Icon(Icons.person_off_rounded,
                      size: 18, color: _kRed),
                  label: const Text('لم يحضر',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: _kRed)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kRed,
                    side: const BorderSide(color: _kRed, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _cashStatusPill(BookingModel b) {
    final bg = switch (b.cashCollectionStatus) {
      'confirmed' => _kGreen.withValues(alpha: 0.12),
      'no_show' || 'disputed' => _kRed.withValues(alpha: 0.12),
      _ => const Color(0xFFFFF3E0),
    };
    final fg = switch (b.cashCollectionStatus) {
      'confirmed' => _kGreen,
      'no_show' || 'disputed' => _kRed,
      _ => const Color(0xFFEF6C00),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.payments_rounded, size: 14, color: fg),
        const SizedBox(width: 6),
        Text(b.cashStatusAr,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w800, color: fg)),
      ]),
    );
  }

  Widget _amountsRow(BookingModel b) {
    return Row(children: [
      Expanded(
        child: _miniStat(
          'العربون أونلاين',
          '${b.depositAmount.toStringAsFixed(0)} جنيه',
          _kGreen,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _miniStat(
          'كاش عند الوصول',
          '${b.remainingCashAmount.toStringAsFixed(0)} جنيه',
          _kOrange,
        ),
      ),
    ]);
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 10.5, color: context.kSub)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900, color: color)),
      ]),
    );
  }
}
