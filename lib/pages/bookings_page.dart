// ═══════════════════════════════════════════════════════════════
//  TALAA — Bookings Page  (REST API)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../main.dart' show appSettings;
import '../utils/app_strings.dart';
import '../utils/auth_guard.dart';
import '../widgets/cancel_booking_sheet.dart';
import '../widgets/constants.dart';
import '../models/booking_model.dart';
import '../models/review_model.dart';
import '../services/booking_service.dart';
import '../services/review_service.dart';
import 'write_review_page.dart';

// Accent colors (same in light & dark)
// Bookings page is themed orange (was ocean blue). The const name is
// kept as `_kOcean` locally so the broad `context.kSand` / area colour
// logic below continues to work; its VALUE is now orange.
const _kOcean  = Color(0xFFFF6D00); // brand orange
const _kOrange = Color(0xFFFF6D00);
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF5350);

// ── Helpers ────────────────────────────────────────────────────
String _categoryEmoji(String category) {
  switch (category) {
    case 'شاليه':     return '🏡';
    case 'فيلا':      return '🏖️';
    case 'فندق':      return '🏨';
    case 'منتجع':     return '🌺';
    case 'أكوا بارك': return '🌊';
    case 'رحلة يوم واحد':  return '☀️';
    default:          return '🏠';
  }
}

Color _areaColor(String area) {
  if (area == 'عين السخنة')     return const Color(0xFFFF8C42);
  if (area == 'الساحل الشمالي') return const Color(0xFFE85A24);
  if (area == 'الجونة')         return const Color(0xFFE65100);
  if (area == 'الغردقة')        return const Color(0xFF00695C);
  if (area == 'شرم الشيخ')      return const Color(0xFF6A1B9A);
  if (area == 'رأس سدر')        return const Color(0xFF00897B);
  return _kOcean;
}

String _fmtDate(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

/// Map API status to display group
String _statusGroup(String status) {
  switch (status) {
    case 'pending':
    case 'confirmed':
      return 'upcoming';
    case 'completed':
      return 'past';
    case 'cancelled':
      return 'cancelled';
    default:
      return 'upcoming';
  }
}

// ══════════════════════════════════════════════════════════════
//  PAGE
// ══════════════════════════════════════════════════════════════
class BookingsPage extends StatefulWidget {
  final bool embedded;
  const BookingsPage({super.key, this.embedded = false});
  @override State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage>
    with SingleTickerProviderStateMixin {

  late TabController _tabCtrl;
  List<BookingModel> _bookings = [];
  // Booking ids that the user can still post a review for.
  Set<int> _pendingReviewIds = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // When opened directly (deep-link, /bookings route, push notification),
    // bounce guests through the login prompt before we hit the API.
    if (!widget.embedded) {
      AuthGuard.requireOrPop(context, feature: 'تشوف حجوزاتك');
    }
    appSettings.addListener(_onLangChange);
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadBookings();
  }

  void _onLangChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange); _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadBookings() async {
    try {
      final results = await Future.wait([
        BookingService.getMyBookings(),
        ReviewService.myPending(),
      ]);
      final list = results[0] as List<BookingModel>;
      final pending = results[1] as List<PendingReview>;
      if (mounted) {
        setState(() {
          _bookings = list;
          _pendingReviewIds = pending.map((p) => p.bookingId).toSet();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  PendingReview _asPending(BookingModel b) => PendingReview(
        bookingId: b.id,
        bookingCode: b.bookingCode,
        propertyId: b.propertyId,
        propertyName: b.propertyName,
        propertyImage: b.propertyImage.isNotEmpty ? b.propertyImage : null,
        checkIn: b.checkIn,
        checkOut: b.checkOut,
        completedAt: b.updatedAt,
      );

  Future<void> _rate(BookingModel b) async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WriteReviewPage(pending: _asPending(b)),
      ),
    );
    if (submitted == true) _loadBookings();
  }

  Future<void> _cancel(BookingModel b) async {
    final updated = await showCancelBookingSheet(context, b);
    if (updated != null) _loadBookings();
  }

  /// Wave 25 — guest confirms they arrived and paid the cash leg.
  ///
  /// Wraps the network call in an explicit confirm dialog so a
  /// fat-finger tap doesn't prematurely release the host's payout
  /// (which we'd then have to chase if the cash never actually
  /// changed hands).
  Future<void> _confirmArrival(BookingModel b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الوصول والدفع'),
        content: Text(
          'هل وصلت العقار ودفعت ${b.remainingCashAmount.toStringAsFixed(0)} '
          'جنيه كاش للمضيف؟ بمجرد التأكيد لا يمكن التراجع.',
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
            child: const Text('نعم، أكد'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await BookingService.confirmArrival(b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تأكيد وصولك. شكراً!'),
          backgroundColor: _kGreen,
        ),
      );
      _loadBookings();
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

  /// True when the guest can still file an arrival confirmation.
  /// Mirrors the backend guards in ``confirm_arrival`` so we never
  /// bother the user with a button that's about to 4xx.
  bool _canConfirmArrival(BookingModel b) {
    if (!b.isCashOnArrival) return false;
    if (!b.isPaid) return false;
    if (b.cashGuestConfirmed) return false;
    if (b.cashFullyConfirmed || b.noShowReported) return false;
    final today = DateTime.now();
    return !b.checkIn.isAfter(DateTime(today.year, today.month, today.day));
  }

  /// Compact pill summarising where the cash-on-arrival handshake
  /// stands.  Colour-coded so the guest sees green = settled,
  /// amber = waiting, red = trouble at a glance.
  Widget _cashStatusBadge(BookingModel b) {
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
    final icon = switch (b.cashCollectionStatus) {
      'confirmed' => Icons.verified_rounded,
      'no_show' => Icons.person_off_rounded,
      'disputed' => Icons.gavel_rounded,
      _ => Icons.payments_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            b.cashStatusAr,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w800, color: fg),
          ),
          if (b.remainingCashAmount > 0 &&
              !b.cashFullyConfirmed &&
              !b.noShowReported) ...[
            const SizedBox(width: 6),
            Text('· ${b.remainingCashAmount.toStringAsFixed(0)} جنيه',
                style: TextStyle(fontSize: 11, color: fg)),
          ],
        ],
      ),
    );
  }

  List<BookingModel> _byStatus(String s) =>
      _bookings.where((b) => _statusGroup(b.status) == s).toList();

  String _comma(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _kOcean))
              : RefreshIndicator(
                  onRefresh: _loadBookings,
                  color: _kOcean,
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildList('upcoming'),
                      _buildList('past'),
                      _buildList('cancelled'),
                    ],
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    final upcoming = _byStatus('upcoming').length;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomCenter,
          colors: [Color(0xFFB54414), Color(0xFFFF6B35), Color(0xFFFF8A3D)],
        ),
      ),
      child: SafeArea(bottom: false, child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(children: [
            if (!widget.embedded) ...[
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(S.myBookingsTitle,
                style: TextStyle(color: Colors.white,
                    fontSize: 20, fontWeight: FontWeight.w900))),
            if (upcoming > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kOrange, borderRadius: BorderRadius.circular(20)),
                child: Text('$upcoming قادمة',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.w800)),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800),
          tabs: [
            Tab(text: '📅 القادمة (${_byStatus("upcoming").length})'),
            Tab(text: '✅ المنتهية (${_byStatus("past").length})'),
            Tab(text: '❌ الملغية (${_byStatus("cancelled").length})'),
          ],
        ),
      ])),
    );
  }

  Widget _buildList(String status) {
    final list = _byStatus(status);
    if (list.isEmpty) return _emptyState(status);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (_, i) => _bookingCard(list[i]),
    );
  }

  Widget _emptyState(String status) {
    final data = {
      'upcoming':  ('📅', 'مفيش حجوزات قادمة',   'ابحث عن شاليه وأحجز رحلتك الجاية'),
      'past':      ('🏖️', 'مفيش حجوزات منتهية',  'حجوزاتك السابقة هتظهر هنا'),
      'cancelled': ('✅', 'مفيش حجوزات ملغية',    'الحمد لله 😄'),
    };
    final (emoji, title, sub) = data[status]!;
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text(title, style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.w800, color: context.kText)),
        const SizedBox(height: 6),
        Text(sub, style: TextStyle(fontSize: 13, color: context.kSub)),
      ],
    ));
  }

  Widget _bookingCard(BookingModel b) {
    final group = _statusGroup(b.status);
    final isUpcoming  = group == 'upcoming';
    final isCancelled = group == 'cancelled';
    return GestureDetector(
      onTap: () => _showDetail(b),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: context.kCard, borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: Column(children: [
          // Image header
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22)),
            child: SizedBox(
              height: 115, width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                b.propertyImage.isNotEmpty
                    ? Image.network(b.propertyImage, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _gradientBg(b.propertyArea, b.property?.category ?? '', isCancelled))
                    : _gradientBg(b.propertyArea, b.property?.category ?? '', isCancelled),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent,
                          Colors.black.withValues(alpha: 0.45)],
                    ),
                  ),
                ),
                Positioned(top: 10, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isCancelled ? _kRed
                          : isUpcoming   ? _kGreen
                          : Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      isCancelled ? '❌ ملغي'
                          : isUpcoming ? '📅 قادم' : '✅ منتهي',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 10, fontWeight: FontWeight.w800)),
                  )),
                Positioned(top: 10, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(
                        '#${b.bookingCode.isNotEmpty ? b.bookingCode : b.id.toString()}',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 9, fontWeight: FontWeight.w700)),
                  )),
                if (isUpcoming)
                  Positioned(bottom: 8, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Row(children: [
                        Icon(Icons.qr_code_rounded,
                            size: 12, color: _kOcean),
                        SizedBox(width: 4),
                        Text('QR كود', style: TextStyle(fontSize: 10,
                            color: _kOcean,
                            fontWeight: FontWeight.w700)),
                      ]),
                    )),
              ]),
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.propertyName,
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w900, color: context.kText),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.location_on_rounded,
                          size: 11, color: _areaColor(b.propertyArea)),
                      const SizedBox(width: 2),
                      Text(b.propertyArea,
                          style: TextStyle(fontSize: 10,
                              color: _areaColor(b.propertyArea),
                              fontWeight: FontWeight.w600)),
                    ]),
                  ])),
                if ((b.property?.rating ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFC107), size: 13),
                      Text(' ${b.property!.rating}',
                          style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: context.kText)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 10),
              Divider(height: 1, color: context.kBorder),
              const SizedBox(height: 10),
              Row(children: [
                _infoChip(Icons.login_rounded,  'وصول',   _fmtDate(b.checkIn)),
                Icon(Icons.arrow_forward_rounded,
                    size: 14, color: context.kSub),
                _infoChip(Icons.logout_rounded, 'مغادرة', _fmtDate(b.checkOut)),
                const Spacer(),
                _infoChip(Icons.nights_stay_rounded,
                    'ليالي', '${b.nights}'),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Text(b.statusAr, style: TextStyle(
                    fontSize: 11, color: context.kSub)),
                const Spacer(),
                Text('EGP ${_comma(b.totalPrice.toInt())}',
                    style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w900, color: context.kText)),
              ]),
              // ── Wave 25 — cash-on-arrival status + action ─────
              // Render a status pill for hybrid bookings, plus the
              // "confirm arrival" button when it's the guest's turn
              // to act and the check-in date has arrived.  This is
              // the single most-used action of the new flow, so we
              // surface it inline rather than burying it behind a
              // tap into a details sheet.
              if (b.isCashOnArrival) ...[
                const SizedBox(height: 10),
                _cashStatusBadge(b),
                if (_canConfirmArrival(b)) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: FilledButton.icon(
                      onPressed: () => _confirmArrival(b),
                      icon: const Icon(Icons.check_circle_rounded,
                          size: 18),
                      label: Text(
                        'أكد وصولك ودفعك '
                        '(${b.remainingCashAmount.toStringAsFixed(0)} جنيه كاش)',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w900),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
              if (b.isCompleted && _pendingReviewIds.contains(b.id)) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () => _rate(b),
                    icon: const Icon(Icons.star_rounded,
                        size: 16, color: Color(0xFFF59E0B)),
                    label: const Text('قيّم إقامتك',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      side: const BorderSide(
                          color: Color(0xFFF59E0B), width: 1.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ] else if (isUpcoming) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancel(b),
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: _kRed),
                    label: const Text('إلغاء الحجز',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kRed,
                      side: const BorderSide(color: _kRed, width: 1.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _gradientBg(String area, String category, bool cancelled) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: cancelled
            ? [Colors.grey.shade400, Colors.grey.shade300]
            : [_areaColor(area), _areaColor(area).withValues(alpha: 0.6)],
      ),
    ),
    child: Center(child: Text(_categoryEmoji(category),
        style: TextStyle(fontSize: 48,
            color: cancelled
                ? Colors.white.withValues(alpha: 0.5) : null))),
  );

  Widget _infoChip(IconData icon, String label, String val) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: context.kSub),
      const SizedBox(width: 3),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, color: context.kSub)),
        Text(val, style: TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700, color: context.kText)),
      ]),
      const SizedBox(width: 10),
    ]);

  void _showDetail(BookingModel b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(b: b, comma: _comma),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  DETAIL SHEET
// ══════════════════════════════════════════════════════════════
class _DetailSheet extends StatelessWidget {
  final BookingModel b;
  final String Function(int) comma;
  const _DetailSheet({required this.b, required this.comma});

  @override
  Widget build(BuildContext context) {
    final ac = _areaColor(b.propertyArea);
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: context.kBorder, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 170, width: double.infinity,
              child: b.propertyImage.isNotEmpty
                  ? Image.network(b.propertyImage, fit: BoxFit.cover)
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          ac,
                          ac.withValues(alpha: 0.6)
                        ]),
                      ),
                      child: Center(child: Text(
                          _categoryEmoji(b.property?.category ?? ''),
                          style: const TextStyle(fontSize: 64))),
                    ),
            ),
          ),
        ),
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Text(b.propertyName,
                style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w900, color: context.kText)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.location_on_rounded,
                  size: 13, color: ac),
              Text(' ${b.propertyArea}',
                  style: TextStyle(fontSize: 12, color: ac,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.kSand, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                _row(context, '📋 كود الحجز',
                    '#${b.bookingCode.isNotEmpty ? b.bookingCode : b.id.toString()}'),
                _row(context, '📅 تاريخ الوصول',    _fmtDate(b.checkIn)),
                _row(context, '🚪 تاريخ المغادرة',  _fmtDate(b.checkOut)),
                _row(context, '🌙 عدد الليالي',      '${b.nights} ليالي'),
                _row(context, '💳 حالة الدفع',      b.paymentStatusAr),
                _row(context, '💰 إجمالي المدفوع',
                    'EGP ${comma(b.totalPrice.toInt())}', highlight: true),
              ]),
            ),
            if (_statusGroup(b.status) == 'upcoming') ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _kOcean.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _kOcean.withValues(alpha: 0.2))),
                child: Column(children: [
                  const Icon(Icons.qr_code_2_rounded,
                      size: 80, color: _kOcean),
                  const SizedBox(height: 8),
                  Text('QR كود الدخول',
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w800, color: context.kText)),
                  const SizedBox(height: 4),
                  Text('اعرض الكود ده عند الوصول',
                      style: TextStyle(fontSize: 12, color: context.kSub)),
                ]),
              ),
            ],
          ],
        )),
      ]),
    );
  }

  Widget _row(BuildContext context, String label, String val, {bool highlight = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label, style: TextStyle(fontSize: 13, color: context.kSub)),
        const Spacer(),
        Text(val, style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.w800,
            color: highlight ? _kOcean : context.kText)),
      ]),
    );
}
