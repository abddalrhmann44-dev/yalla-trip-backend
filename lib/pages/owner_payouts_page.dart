// ═══════════════════════════════════════════════════════════════
//  TALAA — Owner Payouts Page  (REST API)
//  المالك يشوف مستحقاته — Airbnb payout model
//  held → released 24h after check-in → paid (3-5 business days)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../main.dart' show appSettings;
import '../utils/app_strings.dart';
import '../widgets/constants.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

// Accent colors (same in light & dark)
const _kOcean  = Color(0xFF1565C0);
const _kOrange = Color(0xFFFF6D00);
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF5350);

// ── Payout helpers (derived from BookingModel) ─────────────
String _fmtDate(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

/// Map booking status to payout status.
String _payoutStatus(BookingModel b) {
  if (b.isCompleted) return 'paid';
  if (b.isConfirmed) {
    final release = b.checkIn.add(const Duration(hours: 24));
    return DateTime.now().isAfter(release) ? 'processing' : 'held';
  }
  return 'held';
}

Color _payoutStatusColor(String status) {
  switch (status) {
    case 'paid':       return _kGreen;
    case 'processing': return _kOrange;
    default:           return const Color(0xFF6B7280);
  }
}

IconData _payoutStatusIcon(String status) {
  switch (status) {
    case 'paid':       return Icons.check_circle_rounded;
    case 'processing': return Icons.pending_rounded;
    default:           return Icons.lock_clock_rounded;
  }
}

String _payoutStatusAr(BookingModel b) {
  final st = _payoutStatus(b);
  if (st == 'paid') return S.paid;
  if (st == 'processing') return S.processing;
  final release = b.checkIn.add(const Duration(hours: 24));
  final diff = release.difference(DateTime.now());
  if (diff.isNegative || diff.inSeconds == 0) return S.readyToPay;
  if (diff.inDays > 0) return 'بعد ${diff.inDays} يوم ⏳';
  return 'بعد ${diff.inHours} ساعة ⏳';
}

// ══════════════════════════════════════════════════════════════
//  PAGE
// ══════════════════════════════════════════════════════════════
class OwnerPayoutsPage extends StatefulWidget {
  const OwnerPayoutsPage({super.key});
  @override State<OwnerPayoutsPage> createState() =>
      _OwnerPayoutsPageState();
}

class _OwnerPayoutsPageState extends State<OwnerPayoutsPage>
    with SingleTickerProviderStateMixin {

  List<BookingModel> _all = [];
  bool _loading = true;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  void _onLangChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange); _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      // Get all owner bookings that have financial data
      final list = await BookingService.getOwnerBookings();
      // Only show bookings with confirmed/completed status (have payout implications)
      final relevant = list.where((b) =>
          b.isConfirmed || b.isCompleted).toList();
      if (mounted) setState(() { _all = relevant; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Totals
  int get _totalPaid =>
      _all.where((b) => _payoutStatus(b) == 'paid')
          .fold(0, (s, b) => s + b.ownerPayout.toInt());
  int get _totalPending =>
      _all.where((b) => _payoutStatus(b) != 'paid')
          .fold(0, (s, b) => s + b.ownerPayout.toInt());
  int get _totalCollected =>
      _all.fold(0, (s, b) => s + b.totalPrice.toInt());
  int get _totalCommission =>
      _all.fold(0, (s, b) => s + b.platformFee.toInt());

  List<BookingModel> _filter(String tab) {
    switch (tab) {
      case 'pending': return _all.where((b) {
          final st = _payoutStatus(b);
          return st == 'held' || st == 'processing';
        }).toList();
      case 'paid': return _all.where((b) =>
          _payoutStatus(b) == 'paid').toList();
      default: return _all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: _kOcean,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(S.myPayouts,
                style: TextStyle(fontSize: 17,
                    fontWeight: FontWeight.w900, color: Colors.white)),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline_rounded,
                    color: Colors.white70, size: 20),
                onPressed: _showPayoutPolicy,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D47A1), Color(0xFF1565C0),
                             Color(0xFF1E88E5)],
                  ),
                ),
                child: SafeArea(child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
                  child: Column(children: [
                    const SizedBox(height: 12),
                    // Big number
                    Column(children: [
                      Text('$_totalPaid جنيه',
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                      Text(S.totalRevenue,
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ]),
                    const SizedBox(height: 16),
                    // Stats row
                    Row(children: [
                      _sStat('قيد الصرف',
                          '$_totalPending جنيه', _kOrange),
                      _sDivider(),
                      _sStat('إجمالي المحصّل',
                          '$_totalCollected جنيه',
                          Colors.white),
                      _sDivider(),
                      _sStat('عمولة المنصة',
                          '$_totalCommission جنيه',
                          Colors.white60),
                    ]),
                    const SizedBox(height: 8),
                    // Policy line
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Icon(Icons.info_outline_rounded,
                            size: 12, color: Colors.white70),
                        SizedBox(width: 5),
                        Text(
                          'يُحوَّل نصيبك 24h بعد دخول الضيف · 8% عمولة',
                          style: TextStyle(
                              fontSize: 11, color: Colors.white70),
                        ),
                      ]),
                    ),
                  ]),
                )),
              ),
            ),
            bottom: TabBar(
              controller: _tabs,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800),
              tabs: const [
                Tab(text: 'الكل'),
                Tab(text: 'قيد الانتظار'),
                Tab(text: 'تم التحويل'),
              ],
            ),
          ),
        ],
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _kOcean))
            : TabBarView(
                controller: _tabs,
                children: [
                  _listView('all'),
                  _listView('pending'),
                  _listView('paid'),
                ],
              ),
      ),
    );
  }

  Widget _sStat(String label, String val, Color color) =>
    Expanded(child: Column(children: [
      Text(val, style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: const TextStyle(
          fontSize: 10, color: Colors.white60)),
    ]));

  Widget _sDivider() => Container(
    width: 1, height: 32,
    color: Colors.white.withValues(alpha: 0.25));

  // ── List ──────────────────────────────────────────────────────
  Widget _listView(String tab) {
    final items = _filter(tab);
    if (items.isEmpty) return _empty(tab);
    return RefreshIndicator(
      color: _kOcean,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) => _card(items[i]),
      ),
    );
  }

  Widget _card(BookingModel b) {
    final st = _payoutStatus(b);
    final sc = _payoutStatusColor(st);
    final si = _payoutStatusIcon(st);
    final sa = _payoutStatusAr(b);
    final release = b.checkIn.add(const Duration(hours: 24));
    final guestName = b.guest?.name ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.kBorder),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // Header
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.propertyName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w900, color: context.kText)),
              const SizedBox(height: 2),
              Text('${_fmtDate(b.checkIn)}  →  ${_fmtDate(b.checkOut)}',
                  style: TextStyle(fontSize: 12, color: context.kSub)),
              if (guestName.isNotEmpty)
                Text('الضيف: $guestName',
                    style: TextStyle(fontSize: 11, color: context.kSub)),
            ],
          )),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${b.ownerPayout.toInt()} جنيه',
                style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w900, color: _kOcean)),
            Text('نصيبك الصافي',
                style: TextStyle(fontSize: 10, color: context.kSub)),
          ]),
        ]),
        Divider(height: 18, color: context.kBorder),

        // Breakdown
        _bRow('إجمالي الحجز', '${b.totalPrice.toInt()} جنيه',
            Colors.grey.shade600),
        _bRow('عمولة المنصة (8%)',
            '- ${b.platformFee.toInt()} جنيه', _kRed),
        _bRow('نصيبك الصافي',
            '${b.ownerPayout.toInt()} جنيه', _kGreen, bold: true),
        Divider(height: 14, color: context.kBorder),

        // Status + release date
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: sc.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: sc.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(si, size: 13, color: sc),
              const SizedBox(width: 5),
              Text(sa, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: sc)),
            ]),
          ),
          const Spacer(),
          if (st == 'held') ...[
            Icon(Icons.schedule_rounded, size: 12, color: context.kSub),
            const SizedBox(width: 4),
            Text(
              'إصدار: ${release.day}/${release.month}/${release.year}',
              style: TextStyle(fontSize: 11, color: context.kSub),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _bRow(String l, String v, Color vc, {bool bold = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(l, style: TextStyle(
            fontSize: 12, color: context.kSub,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
        Text(v, style: TextStyle(
            fontSize: bold ? 14 : 13,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: vc)),
      ]),
    );

  Widget _empty(String tab) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: _kOcean.withValues(alpha: 0.08),
          shape: BoxShape.circle),
        child: Icon(Icons.payments_outlined,
            size: 40, color: _kOcean.withValues(alpha: 0.4)),
      ),
      const SizedBox(height: 16),
      Text(
        tab == 'paid'
            ? 'مفيش مدفوعات مكتملة لحد دلوقتي'
            : 'مفيش مستحقات لحد دلوقتي',
        style: TextStyle(fontSize: 15,
            fontWeight: FontWeight.w800, color: context.kText),
      ),
      const SizedBox(height: 6),
      Text('هيظهر هنا بعد أول حجز',
          style: TextStyle(fontSize: 13, color: context.kSub)),
    ]),
  );

  // ── Payout Policy Dialog ──────────────────────────────────────
  void _showPayoutPolicy() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24,
            MediaQuery.of(context).padding.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 20),
          Text('سياسة صرف المستحقات',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w900, color: context.kText)),
          const SizedBox(height: 4),
          Text('مبنية على سياسة Airbnb',
              style: TextStyle(fontSize: 12, color: context.kSub)),
          const SizedBox(height: 20),
          _pStep('1', '💳', 'العميل يدفع',
              'فلوسه محجوزة في Escrow آمن'),
          _pStep('2', '🏠', 'العميل يدخل العقار',
              'يوم الـ check-in'),
          _pStep('3', '✅', 'بعد 24 ساعة',
              'بنتأكد إن كل حاجة تمام ونفرج عن الفلوس'),
          _pStep('4', '💰', 'نصيبك بيتحول',
              '92% من الحجز — بيوصل خلال 3-5 أيام عمل'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kOcean.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _kOcean.withValues(alpha: 0.2)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ملخص العمولة',
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w900, color: _kOcean)),
                SizedBox(height: 8),
                _CommRow('نسبة عمولة المنصة', '8%'),
                _CommRow('نصيبك الصافي', '92%'),
                _CommRow('موعد التحويل',
                    '+24h من الدخول'),
                _CommRow('وصول الفلوس', '3-5 أيام عمل'),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pStep(String num, String emoji, String title, String sub) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _kOcean.withValues(alpha: 0.1),
            shape: BoxShape.circle),
          child: Center(child: Text(num,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900,
                  color: _kOcean))),
        ),
        const SizedBox(width: 12),
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: context.kText)),
            Text(sub, style: TextStyle(
                fontSize: 12, color: context.kSub)),
          ],
        )),
      ]),
    );
}

class _CommRow extends StatelessWidget {
  final String label, value;
  const _CommRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [
      Expanded(child: Text(label,
          style: TextStyle(fontSize: 12, color: context.kSub))),
      Text(value, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800, color: _kOcean)),
    ]),
  );
}
