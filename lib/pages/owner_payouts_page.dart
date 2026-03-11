// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Owner Payouts Page
//  المالك يشوف مستحقاته — Airbnb payout model
//  held → released 24h after check-in → paid (3-5 business days)
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

// ── Payout Model ───────────────────────────────────────────────
class _Payout {
  final String id, bookingId, propertyName, guestName,
               checkIn, checkOut, status;
  final int    totalCollected, platformFee, ownerAmount, commissionPct;
  final DateTime payoutRelease, createdAt;

  _Payout.fromFirestore(String docId, Map<String, dynamic> d)
      : id             = docId,
        bookingId      = d['bookingId']      ?? '',
        propertyName   = d['propertyName']   ?? '',
        guestName      = d['guestName']      ?? '',
        checkIn        = d['checkIn']        ?? '',
        checkOut       = d['checkOut']       ?? '',
        status         = d['status']         ?? 'held',
        totalCollected = (d['totalCollected'] ?? 0).toInt(),
        platformFee    = (d['platformFee']    ?? 0).toInt(),
        ownerAmount    = (d['ownerAmount']    ?? 0).toInt(),
        commissionPct  = (d['commissionPct']  ?? 8).toInt(),
        payoutRelease  = (d['payoutRelease'] as Timestamp?)
            ?.toDate() ?? DateTime.now(),
        createdAt      = (d['createdAt'] as Timestamp?)
            ?.toDate() ?? DateTime.now();

  Color get statusColor {
    switch (status) {
      case 'paid':       return _kGreen;
      case 'processing': return _kOrange;
      default:           return _kSub;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'paid':       return Icons.check_circle_rounded;
      case 'processing': return Icons.pending_rounded;
      default:           return Icons.lock_clock_rounded;
    }
  }

  String get statusAr {
    switch (status) {
      case 'paid': return 'تم التحويل ✅';
      case 'processing': return 'جاري التحويل ⏳';
      default:
        final now  = DateTime.now();
        final diff = payoutRelease.difference(now);
        if (diff.isNegative || diff.inSeconds == 0) { return 'جاهز للصرف 🟢'; }
        if (diff.inDays > 0) { return 'بعد ${diff.inDays} يوم ⏳'; }
        return 'بعد ${diff.inHours} ساعة ⏳';
    }
  }
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

  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  List<_Payout> _all = [];
  bool _loading = true;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('payouts')
          .where('ownerId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .get();
      setState(() {
        _all = snap.docs
            .map((d) => _Payout.fromFirestore(d.id, d.data()))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // Totals
  int get _totalPaid =>
      _all.where((p) => p.status == 'paid')
          .fold(0, (s, p) => s + p.ownerAmount);
  int get _totalPending =>
      _all.where((p) => p.status != 'paid')
          .fold(0, (s, p) => s + p.ownerAmount);
  int get _totalCollected =>
      _all.fold(0, (s, p) => s + p.totalCollected);
  int get _totalCommission =>
      _all.fold(0, (s, p) => s + p.platformFee);

  List<_Payout> _filter(String tab) {
    switch (tab) {
      case 'pending': return _all.where((p) =>
          p.status == 'held' || p.status == 'processing').toList();
      case 'paid':    return _all.where((p) => p.status == 'paid').toList();
      default:        return _all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSand,
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
            title: const Text('مستحقاتي',
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
                      const Text('إجمالي ما استلمته',
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

  Widget _card(_Payout p) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _kBorder),
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
            Text(p.propertyName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w900, color: _kText)),
            const SizedBox(height: 2),
            Text('${p.checkIn}  →  ${p.checkOut}',
                style: const TextStyle(fontSize: 12, color: _kSub)),
            if (p.guestName.isNotEmpty)
              Text('الضيف: ${p.guestName}',
                  style: const TextStyle(fontSize: 11, color: _kSub)),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${p.ownerAmount} جنيه',
              style: const TextStyle(fontSize: 20,
                  fontWeight: FontWeight.w900, color: _kOcean)),
          const Text('نصيبك الصافي',
              style: TextStyle(fontSize: 10, color: _kSub)),
        ]),
      ]),
      const Divider(height: 18, color: _kBorder),

      // Breakdown
      _bRow('إجمالي الحجز', '${p.totalCollected} جنيه',
          Colors.grey.shade600),
      _bRow('عمولة المنصة (${p.commissionPct}%)',
          '- ${p.platformFee} جنيه', _kRed),
      _bRow('نصيبك الصافي',
          '${p.ownerAmount} جنيه', _kGreen, bold: true),
      const Divider(height: 14, color: _kBorder),

      // Status + release date
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: p.statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: p.statusColor.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(p.statusIcon, size: 13, color: p.statusColor),
            const SizedBox(width: 5),
            Text(p.statusAr, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: p.statusColor)),
          ]),
        ),
        const Spacer(),
        if (p.status == 'held') ...[
          const Icon(Icons.schedule_rounded, size: 12, color: _kSub),
          const SizedBox(width: 4),
          Text(
            'إصدار: ${p.payoutRelease.day}/'
            '${p.payoutRelease.month}/'
            '${p.payoutRelease.year}',
            style: const TextStyle(fontSize: 11, color: _kSub),
          ),
        ],
      ]),
    ]),
  );

  Widget _bRow(String l, String v, Color vc, {bool bold = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(l, style: TextStyle(
            fontSize: 12, color: _kSub,
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
        style: const TextStyle(fontSize: 15,
            fontWeight: FontWeight.w800, color: _kText),
      ),
      const SizedBox(height: 6),
      const Text('هيظهر هنا بعد أول حجز',
          style: TextStyle(fontSize: 13, color: _kSub)),
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
          const Text('سياسة صرف المستحقات',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w900, color: _kText)),
          const SizedBox(height: 4),
          const Text('مبنية على سياسة Airbnb',
              style: TextStyle(fontSize: 12, color: _kSub)),
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
            Text(title, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: _kText)),
            Text(sub, style: const TextStyle(
                fontSize: 12, color: _kSub)),
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
          style: const TextStyle(fontSize: 12, color: _kSub))),
      Text(value, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800, color: _kOcean)),
    ]),
  );
}
