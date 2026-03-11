// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — World-Class Home Page
//  Senior Flutter UI/UX Engineer Level
//  Airbnb + Booking.com quality for Egyptian tourism market
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'explore_page.dart';
import 'bookings_page.dart';
import 'profile_page.dart';

// ────────────────────────────────────────────────────────────────
//  MODELS
// ────────────────────────────────────────────────────────────────


// ────────────────────────────────────────────────────────────────
//  SHIMMER WIDGET
// ────────────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double width, height, radius;
  const _ShimmerBox({required this.width, required this.height,
      this.radius = 12});
  @override State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: const [
              Color(0xFFEEEEEE), Color(0xFFF8F8F8),
              Color(0xFFEEEEEE),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//  PAINTERS
// ────────────────────────────────────────────────────────────────




// ────────────────────────────────────────────────────────────────
//  STATIC DATA
// ────────────────────────────────────────────────────────────────

const _kHeroes = [
  _Hero('Luxury Chalets\nin Ain Sokhna',
      'From EGP 850 / night — Up to 40% OFF',
      '🌊', '40% OFF',
      [Color(0xFF0277BD), Color(0xFF01579B), Color(0xFF003D6B)],
      'assets/images/hero/hero_1.jpg'),
  _Hero('Sea View Resorts\nin Hurghada',
      'Crystal water & coral reefs',
      '🐠', 'TRENDING',
      [Color(0xFF00695C), Color(0xFF004D40), Color(0xFF00372B)],
      'assets/images/hero/hero_2.jpg'),
  _Hero('North Coast\nSummer Deals',
      'White sand beaches from EGP 1,200',
      '🏖️', 'HOT DEAL',
      [Color(0xFF1565C0), Color(0xFF0D47A1), Color(0xFF082F7C)],
      'assets/images/hero/hero_3.jpg'),
  _Hero('Sharm El Sheikh\nLuxury Hotels',
      'World-class diving paradise',
      '🦈', 'NEW',
      [Color(0xFF6A1B9A), Color(0xFF4A148C), Color(0xFF310A6A)],
      'assets/images/hero/hero_4.jpg'),
];

const _kCategories = [
  _Cat('Chalets',    '🏡', Color(0xFF1565C0), Icons.cottage_rounded,    'assets/images/categories/cat_chalets.jpg'),
  _Cat('Hotels',     '🏨', Color(0xFF7B1FA2), Icons.hotel_rounded,      'assets/images/categories/cat_hotels.jpg'),
  _Cat('Beach',      '🌊', Color(0xFF0097A7), Icons.beach_access_rounded,'assets/images/categories/cat_beach.jpg'),
  _Cat('Aqua Park',  '🎢', Color(0xFFE65100), Icons.pool_rounded,        'assets/images/categories/cat_aquapark.jpg'),
  _Cat('Sea Sports', '⛵', Color(0xFF2E7D32), Icons.sailing_rounded,     'assets/images/categories/cat_seasports.jpg'),
  _Cat('Resorts',    '🌴', Color(0xFF6D4C41), Icons.villa_rounded,       'assets/images/categories/cat_resorts.jpg'),
];

// Destinations — count loaded dynamically from Firestore
const _kDestinations = [
  _Dest('عين السخنة',      '🏖️', [Color(0xFF0288D1), Color(0xFF015F86)], 'assets/images/destinations/ain_sokhna.jpg'),
  _Dest('الساحل الشمالي',  '🌴', [Color(0xFF1976D2), Color(0xFF0D47A1)], 'assets/images/destinations/north_coast.jpg'),
  _Dest('الجونة',           '⛵', [Color(0xFFE65100), Color(0xFFBF360C)], 'assets/images/destinations/gouna.jpg'),
  _Dest('الغردقة',          '🐠', [Color(0xFF00695C), Color(0xFF004D40)], 'assets/images/destinations/hurghada.jpg'),
  _Dest('شرم الشيخ',        '🦈', [Color(0xFF6A1B9A), Color(0xFF4A148C)], 'assets/images/destinations/sharm.jpg'),
  _Dest('رأس سدر',          '🌬️', [Color(0xFF00897B), Color(0xFF00574B)], 'assets/images/destinations/ras_sedr.jpg'),
];



// immutable helper models
class _Hero {
  final String title, subtitle, emoji, badge, imagePath;
  final List<Color> grad;
  const _Hero(this.title, this.subtitle, this.emoji, this.badge, this.grad, this.imagePath);
}
class _Cat {
  final String label, emoji, imagePath; final Color color; final IconData icon;
  const _Cat(this.label, this.emoji, this.color, this.icon, this.imagePath);
}
class _Dest {
  final String name, emoji, imagePath; final List<Color> grad;
  const _Dest(this.name, this.emoji, this.grad, this.imagePath);
}

// ────────────────────────────────────────────────────────────────
//  HOME PAGE
// ────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {

  // controllers
  final PageController  _heroCtrl   = PageController(viewportFraction: 0.92);
  final ScrollController _scroll    = ScrollController();
  int    _heroIdx  = 0;
  int    _navIdx   = 0;
  int    _catIdx   = -1;
  bool   _isLoading = true;
  Map<String, int> _areaCounts = {}; // counts from Firestore

  // ── Filter State ───────────────────────────────────
  String _filterArea      = 'الكل';
  RangeValues _filterPrice = const RangeValues(0, 10000);
  int    _filterGuests    = 1;
  int    _filterRooms     = 1;
  String _filterType      = 'الكل';
  bool   _filterPool      = false;
  bool   _filterBeach     = false;
  bool   _filterInstant   = false;
  bool   _filterOnline    = false;
  bool   _filterWifi      = false;
  bool   _filterParking   = false;
  double _filterMinRating = 0;
  bool   _filterActive    = false; // هل في filter مفعّل

  static const _kAreas = ['الكل','عين السخنة','الساحل الشمالي','الجونة','الغردقة','شرم الشيخ','رأس سدر'];
  static const _kTypes = ['الكل','شاليه','فيلا','فندق','منتجع','بيت شاطئ','أكوا بارك'];

  // favorites
  // flash deals (mutable — countdown changes)
  // timers
  Timer? _heroTimer;

  // fade animation
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  // ── Init ───────────────────────────────────────────
  @override
  void initState() {
    super.initState();


    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Simulate loading
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _isLoading = false);
      _fadeCtrl.forward();
      _loadAreaCounts();
    });

    // Hero auto-scroll every 4s
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_heroCtrl.hasClients) return;
      _heroIdx = (_heroIdx + 1) % _kHeroes.length;
      _heroCtrl.animateToPage(_heroIdx,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _fadeCtrl.dispose();
    _heroCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────


  // ── Load area property counts ───────────────────
  Future<void> _loadAreaCounts() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('properties')
          .where('available', isEqualTo: true)
          .get();
      final counts = <String, int>{};
      for (final doc in snap.docs) {
        final area = (doc.data()['area'] ?? '') as String;
        if (area.isNotEmpty) counts[area] = (counts[area] ?? 0) + 1;
      }
      if (mounted) setState(() => _areaCounts = counts);
    } catch (_) {}
  }

  // ════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5FA),
        extendBody: true,
        bottomNavigationBar: _buildNavBar(),
        body: _isLoading ? _buildShimmerScreen() : _buildContent(),
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  SHIMMER LOADING SCREEN
  // ════════════════════════════════════════════════

  Widget _buildShimmerScreen() {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header shimmer
            Row(children: [
              const _ShimmerBox(width: 80, height: 36, radius: 20),
              const Spacer(),
              const _ShimmerBox(width: 36, height: 36, radius: 12),
              const SizedBox(width: 8),
              const _ShimmerBox(width: 36, height: 36, radius: 12),
            ]),
            const SizedBox(height: 14),
            const _ShimmerBox(width: double.infinity, height: 52, radius: 16),
            const SizedBox(height: 20),
            const _ShimmerBox(width: double.infinity, height: 190, radius: 22),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (_) =>
                  const _ShimmerBox(width: 50, height: 68, radius: 16))),
            const SizedBox(height: 24),
            const _ShimmerBox(width: 180, height: 22, radius: 8),
            const SizedBox(height: 12),
            Row(children: [
              const _ShimmerBox(width: 145, height: 130, radius: 20),
              const SizedBox(width: 12),
              const _ShimmerBox(width: 145, height: 130, radius: 20),
            ]),
            const SizedBox(height: 24),
            const _ShimmerBox(width: 200, height: 22, radius: 8),
            const SizedBox(height: 12),
            const _ShimmerBox(width: double.infinity, height: 220, radius: 22),
          ]),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  MAIN CONTENT
  // ════════════════════════════════════════════════

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: CustomScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildHeroSlider()),
          SliverToBoxAdapter(child: _buildCategories()),
          SliverToBoxAdapter(child: _buildDestinations()),
          SliverToBoxAdapter(child: _buildOffersSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  1. SMART HEADER
  // ════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/images/hero/hero_3.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            const Color(0xFF0A2463).withValues(alpha: 0.70),
            BlendMode.darken,
          ),
          onError: (_, __) {},
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A2463), Color(0xFF1565C0), Color(0xFF1E88E5),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(children: [
        // Decorative diagonal stripes

        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(children: [

              // ── Row 1: flag + greeting + icons ──────
              Row(children: [
                // Egypt flag dropdown
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22)),
                    ),
                    child: const Row(children: [
                      Text('🇪🇬', style: TextStyle(fontSize: 17)),
                      SizedBox(width: 6),
                      Text('Egypt',
                          style: TextStyle(color: Colors.white,
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      SizedBox(width: 4),
                      Icon(Icons.expand_more_rounded,
                          color: Colors.white70, size: 17),
                    ]),
                  ),
                ),

                const Spacer(),

                // Greeting
                Column(crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                  Text(_getGreeting(),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11)),
                  Text('${_getUserName()} 👋',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 15, fontWeight: FontWeight.w800)),
                ]),

                const SizedBox(width: 14),

                // Action icons
                _hdrIcon(Icons.notifications_outlined, notif: true),
                const SizedBox(width: 8),
                _hdrIcon(Icons.chat_bubble_outline_rounded),
                const SizedBox(width: 8),
                _hdrIcon(Icons.favorite_border_rounded),
              ]),

              const SizedBox(height: 16),

              // ── Search bar ───────────────────────────
              Container(
                height: 54,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24, offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.search_rounded,
                      color: Color(0xFF1565C0), size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Search chalets, resorts, or beaches…',
                      style: TextStyle(
                          color: Color(0xFFBBBBBB), fontSize: 14),
                    ),
                  ),
                  // Filter pill
                  GestureDetector(
                    onTap: _openFilter,
                    child: Stack(children: [
                      Container(
                        margin: const EdgeInsets.all(7),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _filterActive
                              ? const Color(0xFFFF6D00)
                              : const Color(0xFF1565C0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(children: [
                          Icon(Icons.tune_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Filter',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      if (_filterActive)
                        Positioned(top: 4, right: 4,
                          child: Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle),
                          )),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════
  //  FILTER BOTTOM SHEET
  // ══════════════════════════════════════════════════
  void _openFilter() {
    // نسخة مؤقتة للـ filter
    String      tmpArea     = _filterArea;
    RangeValues tmpPrice    = _filterPrice;
    int         tmpGuests   = _filterGuests;
    int         tmpRooms    = _filterRooms;
    String      tmpType     = _filterType;
    bool        tmpPool     = _filterPool;
    bool        tmpBeach    = _filterBeach;
    bool        tmpInstant  = _filterInstant;
    bool        tmpOnline   = _filterOnline;
    bool        tmpWifi     = _filterWifi;
    bool        tmpParking  = _filterParking;
    double      tmpRating   = _filterMinRating;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(children: [
            // ── Handle ─────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
            ),
            // ── Header ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                const Text('تصفية النتائج',
                    style: TextStyle(fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0D1B2A))),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setSheet(() {
                      tmpArea    = 'الكل';
                      tmpPrice   = const RangeValues(0, 10000);
                      tmpGuests  = 1;
                      tmpRooms   = 1;
                      tmpType    = 'الكل';
                      tmpPool    = false;
                      tmpBeach   = false;
                      tmpInstant = false;
                      tmpOnline  = false;
                      tmpWifi    = false;
                      tmpParking = false;
                      tmpRating  = 0;
                    });
                  },
                  child: const Text('مسح الكل',
                      style: TextStyle(color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            const Divider(height: 1),

            // ── Body ────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                  // ① المنطقة
                  _fSection('📍 المنطقة'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8,
                    children: _kAreas.map((a) => GestureDetector(
                      onTap: () => setSheet(() => tmpArea = a),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: tmpArea == a
                              ? const Color(0xFF1565C0)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: tmpArea == a
                                ? const Color(0xFF1565C0)
                                : Colors.transparent),
                        ),
                        child: Text(a,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tmpArea == a
                                ? Colors.white
                                : const Color(0xFF555555))),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ② نوع الوحدة
                  _fSection('🏠 نوع الوحدة'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8,
                    children: _kTypes.map((t) => GestureDetector(
                      onTap: () => setSheet(() => tmpType = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: tmpType == t
                              ? const Color(0xFFFF6D00)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: tmpType == t
                                ? const Color(0xFFFF6D00)
                                : Colors.transparent),
                        ),
                        child: Text(t,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tmpType == t
                                ? Colors.white
                                : const Color(0xFF555555))),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ③ نطاق السعر
                  _fSection('💰 السعر في الليلة (EGP)'),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _priceChip('${tmpPrice.start.round()} ج'),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 16, color: Colors.grey),
                      _priceChip('${tmpPrice.end.round()} ج'),
                    ],
                  ),
                  RangeSlider(
                    values: tmpPrice,
                    min: 0, max: 10000,
                    divisions: 100,
                    activeColor: const Color(0xFF1565C0),
                    inactiveColor: const Color(0xFFDDE3F0),
                    onChanged: (v) => setSheet(() => tmpPrice = v),
                  ),
                  const SizedBox(height: 16),

                  // ④ عدد الأشخاص
                  _fSection('👥 عدد الأشخاص'),
                  const SizedBox(height: 10),
                  _counterRow(
                    label: 'ضيوف',
                    value: tmpGuests,
                    onDec: () { if (tmpGuests > 1) setSheet(() => tmpGuests--); },
                    onInc: () { if (tmpGuests < 20) setSheet(() => tmpGuests++); },
                  ),
                  const SizedBox(height: 10),
                  _counterRow(
                    label: 'غرف',
                    value: tmpRooms,
                    onDec: () { if (tmpRooms > 1) setSheet(() => tmpRooms--); },
                    onInc: () { if (tmpRooms < 10) setSheet(() => tmpRooms++); },
                  ),
                  const SizedBox(height: 20),

                  // ⑤ الحد الأدنى للتقييم
                  _fSection('⭐ الحد الأدنى للتقييم'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [0.0, 3.0, 3.5, 4.0, 4.5, 5.0].map((r) =>
                      GestureDetector(
                        onTap: () => setSheet(() => tmpRating = r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: tmpRating == r
                                ? const Color(0xFFFFC107)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            r == 0 ? 'الكل' : '$r+',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: tmpRating == r
                                  ? Colors.white
                                  : const Color(0xFF555555)),
                          ),
                        ),
                      ),
                    ).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ⑥ مميزات
                  _fSection('✨ مميزات'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _featureChip('🏊 مسبح', tmpPool,
                        () => setSheet(() => tmpPool = !tmpPool)),
                    _featureChip('🏖️ شاطئ خاص', tmpBeach,
                        () => setSheet(() => tmpBeach = !tmpBeach)),
                    _featureChip('⚡ حجز فوري', tmpInstant,
                        () => setSheet(() => tmpInstant = !tmpInstant)),
                    _featureChip('🟢 أونلاين الآن', tmpOnline,
                        () => setSheet(() => tmpOnline = !tmpOnline)),
                    _featureChip('📶 واي فاي', tmpWifi,
                        () => setSheet(() => tmpWifi = !tmpWifi)),
                    _featureChip('🚗 موقف سيارات', tmpParking,
                        () => setSheet(() => tmpParking = !tmpParking)),
                  ]),

                  const SizedBox(height: 30),
                ]),
              ),
            ),

            // ── Apply Button ────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16, offset: const Offset(0, -4)),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    setState(() {
                      _filterArea     = tmpArea;
                      _filterPrice    = tmpPrice;
                      _filterGuests   = tmpGuests;
                      _filterRooms    = tmpRooms;
                      _filterType     = tmpType;
                      _filterPool     = tmpPool;
                      _filterBeach    = tmpBeach;
                      _filterInstant  = tmpInstant;
                      _filterOnline   = tmpOnline;
                      _filterWifi     = tmpWifi;
                      _filterParking  = tmpParking;
                      _filterMinRating = tmpRating;
                      _filterActive   = tmpArea != 'الكل' ||
                          tmpPrice != const RangeValues(0, 10000) ||
                          tmpGuests > 1 || tmpRooms > 1 ||
                          tmpType != 'الكل' || tmpPool || tmpBeach ||
                          tmpInstant || tmpOnline || tmpWifi ||
                          tmpParking || tmpRating > 0;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('عرض النتائج',
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // Filter helper widgets
  Widget _fSection(String title) => Text(title,
      style: const TextStyle(fontSize: 15,
          fontWeight: FontWeight.w800, color: Color(0xFF0D1B2A)));

  Widget _priceChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF2FF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
    ),
    child: Text(label, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700,
        color: Color(0xFF1565C0))),
  );

  Widget _counterRow({
    required String label,
    required int value,
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) => Row(children: [
    Text(label, style: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: Color(0xFF555555))),
    const Spacer(),
    GestureDetector(
      onTap: onDec,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.remove_rounded,
            size: 18, color: Color(0xFF1565C0)),
      ),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text('$value',
          style: const TextStyle(fontSize: 16,
              fontWeight: FontWeight.w800, color: Color(0xFF0D1B2A))),
    ),
    GestureDetector(
      onTap: onInc,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.add_rounded,
            size: 18, color: Colors.white),
      ),
    ),
  ]);

  Widget _featureChip(String label, bool selected, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1565C0)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF1565C0)
                : Colors.transparent),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF555555))),
      ),
    );

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير ☀️';
    if (h < 17) return 'مساء الخير 🌤️';
    return 'مساء النور 🌙';
  }

  String _getUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'ضيفنا';
    if (user.isAnonymous) return 'ضيفنا';
    final name = user.displayName ?? user.email ?? 'ضيفنا';
    return name.split(' ').first;
  }

  Widget _hdrIcon(IconData icon, {bool notif = false}) {
    return Stack(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
      if (notif)
        Positioned(top: 7, right: 7,
          child: Container(
            width: 9, height: 9,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6D00),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF1565C0), width: 1.5),
            ),
          )),
    ]);
  }

  // ════════════════════════════════════════════════
  //  2. HERO SLIDER
  // ════════════════════════════════════════════════

  Widget _buildHeroSlider() {
    return Column(children: [
      SizedBox(
        height: 210,
        child: PageView.builder(
          controller: _heroCtrl,
          onPageChanged: (i) => setState(() => _heroIdx = i),
          itemCount: _kHeroes.length,
          itemBuilder: (_, i) => _heroCard(_kHeroes[i]),
        ),
      ),

      // Dot indicators
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_kHeroes.length, (i) {
            final sel = _heroIdx == i;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: sel ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: sel
                    ? const Color(0xFF1565C0)
                    : const Color(0xFFCCCCCC),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ),
    ]);
  }

  Widget _heroCard(_Hero h) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: h.grad[0].withValues(alpha: 0.50),
              blurRadius: 22, offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(children: [
            // ── صورة حقيقية ───────────────────────────
            Positioned.fill(
              child: Image.asset(
                h.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: h.grad,
                    ),
                  ),
                ),
              ),
            ),
            // ── Gradient overlay ──────────────────────
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
            ),

          // Content
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFFF6D00).withValues(alpha: 0.5),
                        blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Text(h.badge,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6)),
              ),

              Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(h.title,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w900, height: 1.2,
                      letterSpacing: -0.5,
                      shadows: [Shadow(color: Colors.black26,
                          blurRadius: 8)],
                    )),
                const SizedBox(height: 5),
                Text(h.subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12.5)),
                const SizedBox(height: 14),
                Row(children: [
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(children: [
                        Text('Book Now',
                            style: TextStyle(
                              color: h.grad[0],
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            )),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 14, color: h.grad[0]),
                      ]),
                    ),
                  ),
                ]),
              ]),
            ]),
          ),
        ]),
      ),
    ),
    );
  }

  // ════════════════════════════════════════════════
  //  3. CATEGORIES
  // ════════════════════════════════════════════════

  Widget _buildCategories() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        _secTitle('Explore by Type', action: ''),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_kCategories.length, (i) {
            final c   = _kCategories[i];
            final sel = _catIdx == i;
            return GestureDetector(
              onTap: () => setState(() => _catIdx = sel ? -1 : i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: 54,
                height: 70,
                decoration: BoxDecoration(
                  color: sel ? c.color : Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [
                    BoxShadow(
                      color: sel
                          ? c.color.withValues(alpha: 0.45)
                          : Colors.black.withValues(alpha: 0.07),
                      blurRadius: sel ? 14 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  // ── صورة Category ──────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 36, height: 36,
                      child: Image.asset(
                        c.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            color: sel
                                ? Colors.white.withValues(alpha: 0.25)
                                : c.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(c.icon, size: 18,
                              color: sel ? Colors.white : c.color),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(c.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: sel
                            ? Colors.white
                            : const Color(0xFF555555),
                      )),
                ]),
              ),
            );
          }),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════
  //  4. DESTINATIONS
  // ════════════════════════════════════════════════

  Widget _buildDestinations() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
        child: _secTitle('Explore Beach Destinations',
            action: 'See All'),
      ),

      SizedBox(height: 145,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _kDestinations.length,
          itemBuilder: (_, i) => _destCard(_kDestinations[i]),
        )),
    ]);
  }

  Widget _destCard(_Dest d) {
    return Container(
      width: 155,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: d.grad[0].withValues(alpha: 0.4),
              blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(children: [
          // ── صورة حقيقية ─────────────────────────────
          Positioned.fill(
            child: Image.asset(
              d.imagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: d.grad,
                  ),
                ),
              ),
            ),
          ),
          // ── Gradient overlay للنص ─────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
          ),
          // ── Content ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const Spacer(),
              Text(d.name,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w900, height: 1.2,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                  )),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Text(
                    (_areaCounts[d.name] ?? 0) > 0
                        ? '${_areaCounts[d.name]} عقار'
                        : 'قريباً',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  5. FLASH DEALS ⚡
  // ════════════════════════════════════════════════


  // ════════════════════════════════════════════════
  //  OFFERS — سيُضاف لاحقاً من Firebase
  // ════════════════════════════════════════════════

  Widget _buildOffersSection() {
    // عرض placeholder حتى يتم إضافة عروض حقيقية من Firebase
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF1565C0).withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_offer_outlined,
                color: Color(0xFF1565C0), size: 32),
          ),
          const SizedBox(height: 16),
          const Text('لا توجد عروض حالياً',
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: Color(0xFF0D1B2A),
              )),
          const SizedBox(height: 6),
          Text('ستظهر العروض والخصومات هنا فور إضافتها',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13,
                  color: Colors.grey.shade500)),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  BOTTOM NAV
  // ════════════════════════════════════════════════

  Widget _buildNavBar() {
    const items = [
      {'i': Icons.home_rounded,               'l': 'Home'},
      {'i': Icons.explore_rounded,            'l': 'Explore'},
      {'i': Icons.calendar_today_rounded,     'l': 'Bookings'},
      {'i': Icons.chat_bubble_outline_rounded,'l': 'Messages'},
      {'i': Icons.person_outline_rounded,     'l': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.09),
              blurRadius: 28, offset: const Offset(0, -8)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final sel = _navIdx == i;
              return GestureDetector(
                onTap: () {
                  setState(() => _navIdx = i);
                  switch (i) {
                    case 0: break; // Home — already here
                    case 1:
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const ExplorePage()));
                      break;
                    case 2:
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const BookingsPage()));
                      break;
                    case 3:
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Row(children: [
                          Icon(Icons.chat_bubble_rounded,
                              color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text('Messages — ابدأ حجز للدردشة مع المالك',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                        backgroundColor: const Color(0xFF1565C0),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 3),
                      ));
                      break;
                    case 4:
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const ProfilePage()));
                      break;
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF1565C0).withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min,
                    children: [
                    Icon(items[i]['i'] as IconData,
                        size: 24,
                        color: sel
                            ? const Color(0xFF1565C0)
                            : const Color(0xFFAAAAAA),
                        shadows: sel ? const [
                          Shadow(color: Color(0x661565C0), blurRadius: 10),
                        ] : null),
                    const SizedBox(height: 3),
                    Text(items[i]['l'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: sel
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: sel
                              ? const Color(0xFF1565C0)
                              : const Color(0xFFAAAAAA),
                        )),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  REUSABLE WIDGETS
  // ════════════════════════════════════════════════

  Widget _secTitle(String title, {required String action}) {
    return Row(children: [
      Expanded(child: Text(title,
          style: const TextStyle(
              fontSize: 19, fontWeight: FontWeight.w900,
              color: Color(0xFF0D1B2A), letterSpacing: -0.4))),
      if (action.isNotEmpty) _seeAll(action),
    ]);
  }

  Widget _seeAll(String label) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: Color(0xFF1565C0))),
      ),
    );
  }

}
