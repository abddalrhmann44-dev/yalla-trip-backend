// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Bookings Management  (REST API)
//  List all bookings, confirm / cancel
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/constants.dart';
import '../../models/booking_model.dart';
import '../../services/admin_service.dart';

const _kOcean  = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF4CAF50);
const _kOrange = Color(0xFFFF6D00);
const _kRed    = Color(0xFFEF5350);

class AdminBookingsPage extends StatefulWidget {
  const AdminBookingsPage({super.key});
  @override
  State<AdminBookingsPage> createState() => _AdminBookingsPageState();
}

class _AdminBookingsPageState extends State<AdminBookingsPage> {
  List<BookingModel> _bookings = [];
  bool _loading = true;
  String _filter = 'الكل';

  static const _filters = ['الكل', 'في الانتظار', 'مؤكد', 'ملغي', 'مكتمل'];
  static const _filterMap = {
    'الكل': null,
    'في الانتظار': 'pending',
    'مؤكد': 'confirmed',
    'ملغي': 'cancelled',
    'مكتمل': 'completed',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _bookings = await AdminService.getAllBookings(
        status: _filterMap[_filter],
        limit: 200,
      );
    } catch (e) {
      debugPrint('Admin bookings error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _confirm(BookingModel b) async {
    final ok = await _confirmDialog(
        'تأكيد الحجز؟', 'هيتم تأكيد حجز ${b.bookingCode}', _kGreen);
    if (ok != true) return;
    try {
      await AdminService.confirmBooking(b.id);
      HapticFeedback.mediumImpact();
      _snack('تم تأكيد الحجز', _kGreen);
      _load();
    } catch (_) {
      _snack('حصل خطأ', _kRed);
    }
  }

  Future<void> _cancel(BookingModel b) async {
    final ok = await _confirmDialog(
        'إلغاء الحجز؟', 'هيتم إلغاء حجز ${b.bookingCode}', _kRed);
    if (ok != true) return;
    try {
      await AdminService.cancelBooking(b.id);
      HapticFeedback.mediumImpact();
      _snack('تم إلغاء الحجز', _kRed);
      _load();
    } catch (_) {
      _snack('حصل خطأ', _kRed);
    }
  }

  Future<bool?> _confirmDialog(String title, String body, Color color) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: TextStyle(fontWeight: FontWeight.w900, color: color)),
        content: Text(body, style: TextStyle(color: context.kSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء',
                style: TextStyle(
                    color: context.kSub, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('تأكيد',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
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
        title: Text('إدارة الحجوزات (${_bookings.length})',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        centerTitle: true,
      ),
      body: Column(children: [
        // Filter chips
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            physics: const BouncingScrollPhysics(),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = _filters[i];
              final sel = f == _filter;
              return GestureDetector(
                onTap: () {
                  setState(() => _filter = f);
                  _load();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? _kOcean : context.kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? _kOcean : context.kBorder),
                  ),
                  child: Text(f,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : context.kText)),
                ),
              );
            },
          ),
        ),

        // Bookings list
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _kOcean))
              : _bookings.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.event_busy_rounded,
                            size: 48, color: context.kBorder),
                        const SizedBox(height: 12),
                        Text('لا توجد حجوزات',
                            style: TextStyle(
                                fontSize: 14, color: context.kSub)),
                      ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _kOcean,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics()),
                        itemCount: _bookings.length,
                        itemBuilder: (_, i) => _bookingCard(_bookings[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _bookingCard(BookingModel b) {
    final statusColor = _statusColor(b.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header: code + status
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kOcean.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('#${b.bookingCode}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _kOcean,
                    letterSpacing: 1)),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(b.statusAr,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor)),
          ),
        ]),

        const SizedBox(height: 10),

        // Property name
        Text(b.propertyName.isNotEmpty ? b.propertyName : 'عقار #${b.propertyId}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.kText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),

        const SizedBox(height: 6),

        // Details row
        Row(children: [
          Icon(Icons.person_rounded, size: 13, color: context.kSub),
          const SizedBox(width: 3),
          Text(b.guest?.name ?? 'ضيف #${b.guestId}',
              style: TextStyle(fontSize: 11, color: context.kSub)),
          const SizedBox(width: 12),
          Icon(Icons.calendar_today_rounded, size: 12, color: context.kSub),
          const SizedBox(width: 3),
          Text(
              '${b.checkIn.day}/${b.checkIn.month} → ${b.checkOut.day}/${b.checkOut.month}',
              style: TextStyle(fontSize: 11, color: context.kSub)),
        ]),

        const SizedBox(height: 6),

        // Price + payment
        Row(children: [
          Text(b.formattedTotal,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.kText)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: b.isPaid
                  ? _kGreen.withValues(alpha: 0.1)
                  : _kOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(b.paymentStatusAr,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: b.isPaid ? _kGreen : _kOrange)),
          ),
        ]),

        // Actions (only for pending)
        if (b.isPending) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _confirm(b),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('✅ تأكيد',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _kGreen)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => _cancel(b),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _kRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('❌ إلغاء',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _kRed)),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return _kGreen;
      case 'cancelled':
        return _kRed;
      case 'completed':
        return _kOcean;
      default:
        return _kOrange;
    }
  }
}
