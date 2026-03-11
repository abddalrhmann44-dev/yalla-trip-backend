// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Bookings Page  (Firebase)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const _kOcean  = Color(0xFF1565C0);
const _kOrange = Color(0xFFFF6D00);
const _kSand   = Color(0xFFF5F3EE);
const _kCard   = Colors.white;
const _kText   = Color(0xFF0D1B2A);
const _kSub    = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF5350);

// ── Model ──────────────────────────────────────────────────────
class _Booking {
  final String id, propertyName, area, location, category,
               checkIn, checkOut, status, payMethod, propertyImage;
  final int    nights, totalPaid;
  final double rating;

  _Booking.fromFirestore(String docId, Map<String, dynamic> d)
      : id            = docId,
        propertyName  = d['propertyName']  ?? '',
        area          = d['area']          ?? '',
        location      = d['location']      ?? '',
        category      = d['category']      ?? '',
        checkIn       = d['checkIn']       ?? '',
        checkOut      = d['checkOut']      ?? '',
        status        = d['status']        ?? 'upcoming',
        payMethod     = d['payMethod']     ?? '',
        propertyImage = d['propertyImage'] ?? '',
        nights        = (d['nights']       ?? 1).toInt(),
        totalPaid     = (d['totalPaid']    ?? 0).toInt(),
        rating        = (d['rating']       ?? 0.0).toDouble();

  String get categoryEmoji {
    switch (category) {
      case 'شاليه':     return '🏡';
      case 'فيلا':      return '🏖️';
      case 'فندق':      return '🏨';
      case 'منتجع':     return '🌺';
      case 'أكوا بارك': return '🌊';
      case 'بيت شاطئ':  return '🏄';
      default:          return '🏠';
    }
  }

  Color get areaColor {
    switch (area) {
      case 'عين السخنة':     return const Color(0xFF0288D1);
      case 'الساحل الشمالي': return const Color(0xFF1976D2);
      case 'الجونة':         return const Color(0xFFE65100);
      case 'الغردقة':        return const Color(0xFF00695C);
      case 'شرم الشيخ':      return const Color(0xFF6A1B9A);
      case 'رأس سدر':        return const Color(0xFF00897B);
      default:               return _kOcean;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  PAGE
// ══════════════════════════════════════════════════════════════
class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});
  @override State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage>
    with SingleTickerProviderStateMixin {

  late TabController _tabCtrl;
  List<_Booking> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadBookings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();
      final list = snap.docs
          .map((d) => _Booking.fromFirestore(d.id, d.data()))
          .toList();
      if (mounted) setState(() { _bookings = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Booking> _byStatus(String s) =>
      _bookings.where((b) => b.status == s).toList();

  String _comma(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSand,
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
          colors: [Color(0xFF0A2463), Color(0xFF1565C0), Color(0xFF1E88E5)],
        ),
      ),
      child: SafeArea(bottom: false, child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(children: [
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
            const Expanded(child: Text('حجوزاتي',
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
        Text(title, style: const TextStyle(fontSize: 18,
            fontWeight: FontWeight.w800, color: _kText)),
        const SizedBox(height: 6),
        Text(sub, style: const TextStyle(fontSize: 13, color: _kSub)),
      ],
    ));
  }

  Widget _bookingCard(_Booking b) {
    final isUpcoming  = b.status == 'upcoming';
    final isCancelled = b.status == 'cancelled';
    return GestureDetector(
      onTap: () => _showDetail(b),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(22),
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
                            _gradientBg(b, isCancelled))
                    : _gradientBg(b, isCancelled),
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
                        '#${b.id.substring(0, 8).toUpperCase()}',
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
                        style: const TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w900, color: _kText),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.location_on_rounded,
                          size: 11, color: b.areaColor),
                      const SizedBox(width: 2),
                      Text('${b.area} · ${b.location}',
                          style: TextStyle(fontSize: 10,
                              color: b.areaColor,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ])),
                if (b.rating > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFC107), size: 13),
                      Text(' ${b.rating}',
                          style: const TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _kText)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 10),
              const Divider(height: 1, color: _kBorder),
              const SizedBox(height: 10),
              Row(children: [
                _infoChip(Icons.login_rounded,  'وصول',   b.checkIn),
                const Icon(Icons.arrow_forward_rounded,
                    size: 14, color: _kSub),
                _infoChip(Icons.logout_rounded, 'مغادرة', b.checkOut),
                const Spacer(),
                _infoChip(Icons.nights_stay_rounded,
                    'ليالي', '${b.nights}'),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Text(b.payMethod, style: const TextStyle(
                    fontSize: 11, color: _kSub)),
                const Spacer(),
                Text('EGP ${_comma(b.totalPaid)}',
                    style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w900, color: _kText)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _gradientBg(_Booking b, bool cancelled) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: cancelled
            ? [Colors.grey.shade400, Colors.grey.shade300]
            : [b.areaColor, b.areaColor.withValues(alpha: 0.6)],
      ),
    ),
    child: Center(child: Text(b.categoryEmoji,
        style: TextStyle(fontSize: 48,
            color: cancelled
                ? Colors.white.withValues(alpha: 0.5) : null))),
  );

  Widget _infoChip(IconData icon, String label, String val) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: _kSub),
      const SizedBox(width: 3),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: _kSub)),
        Text(val, style: const TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700, color: _kText)),
      ]),
      const SizedBox(width: 10),
    ]);

  void _showDetail(_Booking b) {
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
  final _Booking b;
  final String Function(int) comma;
  const _DetailSheet({required this.b, required this.comma});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: _kBorder, borderRadius: BorderRadius.circular(2)),
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
                          b.areaColor,
                          b.areaColor.withValues(alpha: 0.6)
                        ]),
                      ),
                      child: Center(child: Text(b.categoryEmoji,
                          style: const TextStyle(fontSize: 64))),
                    ),
            ),
          ),
        ),
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Text(b.propertyName,
                style: const TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w900, color: _kText)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.location_on_rounded,
                  size: 13, color: b.areaColor),
              Text(' ${b.area} · ${b.location}',
                  style: TextStyle(fontSize: 12, color: b.areaColor,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kSand, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                _row('📋 كود الحجز',
                    '#${b.id.substring(0, 8).toUpperCase()}'),
                _row('📅 تاريخ الوصول',    b.checkIn),
                _row('🚪 تاريخ المغادرة',  b.checkOut),
                _row('🌙 عدد الليالي',      '${b.nights} ليالي'),
                _row('💳 طريقة الدفع',     b.payMethod),
                _row('💰 إجمالي المدفوع',
                    'EGP ${comma(b.totalPaid)}', highlight: true),
              ]),
            ),
            if (b.status == 'upcoming') ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _kOcean.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _kOcean.withValues(alpha: 0.2))),
                child: const Column(children: [
                  Icon(Icons.qr_code_2_rounded,
                      size: 80, color: _kOcean),
                  SizedBox(height: 8),
                  Text('QR كود الدخول',
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w800, color: _kText)),
                  SizedBox(height: 4),
                  Text('اعرض الكود ده عند الوصول',
                      style: TextStyle(fontSize: 12, color: _kSub)),
                ]),
              ),
            ],
          ],
        )),
      ]),
    );
  }

  Widget _row(String label, String val, {bool highlight = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _kSub)),
        const Spacer(),
        Text(val, style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.w800,
            color: highlight ? _kOcean : _kText)),
      ]),
    );
}
