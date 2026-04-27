// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — World-Class Home Page
//  Senior Flutter UI/UX Engineer Level
//  Airbnb + Booking.com quality for Egyptian tourism market
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart' show appSettings, userProvider;
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import '../widgets/constants.dart';
import 'explore_page.dart';
import 'area_results_page.dart';
import '../utils/app_strings.dart';
import '../utils/auth_guard.dart';
import 'best_trip_page.dart';
import 'profile_page.dart';
import 'property_details_page.dart';
import '../models/property_model_api.dart';
import '../services/property_service.dart';
import 'chat_inbox_page.dart';
import 'favorites_page.dart';
import 'notifications_page.dart';

// ────────────────────────────────────────────────────────────────
//  MODELS
// ────────────────────────────────────────────────────────────────

// ────────────────────────────────────────────────────────────────
//  SHIMMER WIDGET
// ────────────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double width, height, radius;
  const _ShimmerBox(
      {required this.width, required this.height, this.radius = 12});
  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _anim = Tween<double>(begin: -2, end: 2)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: context.isDark
                ? const [
                    Color(0xFF1E2530),
                    Color(0xFF283040),
                    Color(0xFF1E2530),
                  ]
                : const [
                    Color(0xFFEEEEEE),
                    Color(0xFFF8F8F8),
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
  _Hero('عين السخنة', 'ainSokhna', '40% OFF', 'assets/images/hero/hero_1.jpg',
      'عين السخنة'),
  _Hero('الغردقة', 'hurghada', 'TRENDING', 'assets/images/hero/hero_2.jpg',
      'الغردقة'),
  _Hero('الساحل الشمالي', 'northCoast', 'HOT DEAL',
      'assets/images/hero/hero_3.jpg', 'الساحل الشمالي'),
  _Hero('شرم الشيخ', 'sharm', 'NEW', 'assets/images/hero/hero_4.jpg',
      'شرم الشيخ'),
];

// Destinations — count loaded dynamically from API
const _kDestinations = [
  _Dest('القاهرة', '🏛️', [Color(0xFFBF360C), Color(0xFF8D1C06)],
      'assets/images/destinations/cairo.jpg'),
  _Dest('سهل حشيش', '🏝️', [Color(0xFF00838F), Color(0xFF004D57)],
      'assets/images/destinations/shal_hashesh.jpg'),
  _Dest('مرسى علم', '🐬', [Color(0xFFFF6B35), Color(0xFF0D3B6F)],
      'assets/images/destinations/marsa_alam.jpg'),
  _Dest('اسكندرية', '🌊', [Color(0xFF283593), Color(0xFF1A237E)],
      'assets/images/destinations/alex.jpg'),
  _Dest('عين السخنة', '🏖️', [Color(0xFFFF8C42), Color(0xFF015F86)],
      'assets/images/destinations/ain_sokhna.jpg'),
  _Dest('الساحل الشمالي', '🌴', [Color(0xFFE85A24), Color(0xFFE85A24)],
      'assets/images/destinations/north_coast.jpg'),
  _Dest('الجونة', '⛵', [Color(0xFFE65100), Color(0xFFBF360C)],
      'assets/images/destinations/gouna.jpg'),
  _Dest('الغردقة', '🐠', [Color(0xFF00695C), Color(0xFF004D40)],
      'assets/images/destinations/hurghada.jpg'),
  _Dest('شرم الشيخ', '🦈', [Color(0xFF6A1B9A), Color(0xFF4A148C)],
      'assets/images/destinations/sharm.jpg'),
  _Dest('رأس سدر', '🌬️', [Color(0xFF00897B), Color(0xFF00574B)],
      'assets/images/destinations/ras_sedr.jpg'),
];

// immutable helper models
class _Hero {
  final String title, areaKey, badge, imagePath, area;
  const _Hero(this.title, this.areaKey, this.badge, this.imagePath, this.area);
  String get displayTitle => S.areaName(title);
  String get displaySubtitle {
    switch (areaKey) {
      case 'ainSokhna':
        return S.ainSokhnaSub;
      case 'hurghada':
        return S.hurghadaSub;
      case 'northCoast':
        return S.northCoastSub;
      case 'sharm':
        return S.sharmSub;
      default:
        return '';
    }
  }

  List<String> get categories {
    switch (areaKey) {
      case 'ainSokhna':
        return S.ainSokhnaCategories;
      case 'hurghada':
        return S.hurghadaCategories;
      case 'northCoast':
        return S.northCoastCategories;
      case 'sharm':
        return S.sharmCategories;
      default:
        return [];
    }
  }
}

class _Dest {
  final String name, emoji, imagePath;
  final List<Color> grad;
  const _Dest(this.name, this.emoji, this.grad, this.imagePath);
}

// ────────────────────────────────────────────────────────────────
//  HOME PAGE
// ────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // controllers
  final PageController _heroCtrl = PageController(viewportFraction: 0.92);
  final ScrollController _scroll = ScrollController();
  int _heroIdx = 0;
  int _navIdx = 0;
  bool _isLoading = true;
  Map<String, int> _areaCounts = {}; // counts from API

  // ── Filter State ───────────────────────────────────
  String _filterArea = 'الكل';
  RangeValues _filterPrice = const RangeValues(0, 10000);
  int _filterGuests = 1;
  int _filterRooms = 1;
  String _filterType = 'الكل';
  bool _filterPool = false;
  bool _filterBeach = false;
  bool _filterInstant = false;
  bool _filterOnline = false;
  bool _filterWifi = false;
  bool _filterParking = false;
  double _filterMinRating = 0;
  bool _filterActive = false; // هل في filter مفعّل

  static const _kAreas = [
    'الكل',
    'عين السخنة',
    'الساحل الشمالي',
    'الجونة',
    'الغردقة',
    'شرم الشيخ',
    'رأس سدر'
  ];
  static const _kTypes = [
    'الكل',
    'شاليه',
    'فيلا',
    'فندق',
    'منتجع',
    'شواطئ',
  
    'أكوا بارك'
  ];

  // recent searches
  final List<String> _recentSearches = [];
  // timers
  Timer? _heroTimer;

  // fade animation
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── Init ───────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
    userProvider.addListener(_onUserChanged);

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Simulate loading
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _isLoading = false);
      _fadeCtrl.forward();
      _loadAreaCounts();
      _loadOffers();
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

  void _onLangChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _onUserChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }


  @override
  void dispose() {
    appSettings.removeListener(_onLangChange);
    userProvider.removeListener(_onUserChanged);
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
      final props = await PropertyService.getProperties();
      final counts = <String, int>{};
      for (final p in props) {
        if (p.area.isNotEmpty) counts[p.area] = (counts[p.area] ?? 0) + 1;
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
      value: _navIdx == 0 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.kSand,
        extendBody: _navIdx == 0,
        bottomNavigationBar: _buildNavBar(),
        // ``GestureDetector`` on the Scaffold body dismisses the
        // search-bar keyboard the moment the user taps anywhere
        // outside the field.  Fixes the "field stays focused after
        // I lift my finger" bug without removing the inline
        // ``TextField`` UX the user prefers on the home page.
        // ``HitTestBehavior.translucent`` lets taps still reach
        // the children below (cards, hero slider, etc.).
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: IndexedStack(
            index: _navIdx,
            children: [
              _isLoading ? _buildShimmerScreen() : _buildContent(),
              const BestTripPage(embedded: true),
              const ChatInboxPage(embedded: true),
              const ProfilePage(embedded: true),
            ],
          ),
        ),
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header shimmer
            const Row(children: [
              _ShimmerBox(width: 80, height: 36, radius: 20),
              Spacer(),
              _ShimmerBox(width: 36, height: 36, radius: 12),
              SizedBox(width: 8),
              _ShimmerBox(width: 36, height: 36, radius: 12),
            ]),
            const SizedBox(height: 14),
            const _ShimmerBox(width: double.infinity, height: 52, radius: 16),
            const SizedBox(height: 20),
            const _ShimmerBox(width: double.infinity, height: 190, radius: 22),
            const SizedBox(height: 20),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                    6,
                    (_) =>
                        const _ShimmerBox(width: 50, height: 68, radius: 16))),
            const SizedBox(height: 24),
            const _ShimmerBox(width: 180, height: 22, radius: 8),
            const SizedBox(height: 12),
            const Row(children: [
              _ShimmerBox(width: 145, height: 130, radius: 20),
              SizedBox(width: 12),
              _ShimmerBox(width: 145, height: 130, radius: 20),
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
      // Clean white background.  The waves Lottie rides on top so
      // the colour palette of the animation is the only "colour"
      // visible in the header — gives the home a calm, premium feel
      // (vs. the loud orange wash we had before).
      color: context.kCard,
      child: Stack(children: [
        // ── Background animation ──────────────────────────────
        // ``Positioned.fill`` makes the Lottie cover the whole
        // header the same way ``BoxFit.cover`` would for an image.
        // Bumped to opacity 0.85 (was 0.35) now that the gradient
        // base is white — the waves are the visual centrepiece
        // here, not a texture.
        Positioned.fill(
          child: Opacity(
            opacity: 0.85,
            child: Lottie.asset(
              'assets/animations/waves.json',
              fit: BoxFit.cover,
              // ``frameRate: FrameRate.max`` matches Flutter's
              // refresh rate so the wave loop is smooth on 90/120Hz
              // devices.  At the default rate the motion looks
              // visibly choppy on Pixel-class hardware.
              frameRate: FrameRate.max,
              // Quietly fall back to the plain background if the
              // asset ever fails to load (e.g. file removed in a
              // future cleanup) — never crash the home screen.
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),

        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(children: [
              // ── Row 1: greeting + icons ──────
              Row(children: [
                // Greeting — start side
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_getGreeting(),
                        style: TextStyle(
                            color: context.kSub,
                            fontSize: 11)),
                    Text('${_getUserName()} 👋',
                        style: TextStyle(
                            color: context.kText,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),

                // Action icons — end side.  All three require an
                // authenticated session; guests get the login prompt
                // instead of an opaque 401/empty screen.
                _hdrIcon(Icons.favorite_border_rounded, onTap: () async {
                  if (!await AuthGuard.require(context,
                      feature: 'تشوف عقاراتك المفضلة')) {
                    return;
                  }
                  if (!mounted) return;
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const FavoritesPage()));
                }),
                const SizedBox(width: 8),
                _hdrIcon(Icons.chat_bubble_outline_rounded, onTap: () async {
                  if (!await AuthGuard.require(context,
                      feature: 'تتواصل مع الملاك')) {
                    return;
                  }
                  if (!mounted) return;
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const ChatInboxPage()));
                }),
                const SizedBox(width: 8),
                _hdrIcon(Icons.notifications_outlined, notif: true,
                    onTap: () async {
                  if (!await AuthGuard.require(context,
                      feature: 'تشوف إشعاراتك')) {
                    return;
                  }
                  if (!mounted) return;
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const NotificationsPage()));
                }),
              ]),

              const SizedBox(height: 16),

              // ── Search bar (inline, animated) ──────────
              _HomeSearchBar(
                filterActive: _filterActive,
                onFilterTap: _openFilter,
                onSubmit: (q) {
                  setState(() {
                    if (!_recentSearches.contains(q)) {
                      _recentSearches.insert(0, q);
                      if (_recentSearches.length > 6) {
                        _recentSearches.removeLast();
                      }
                    }
                  });
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExplorePage(initialSearch: q),
                    ),
                  );
                },
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
    String tmpArea = _filterArea;
    RangeValues tmpPrice = _filterPrice;
    int tmpGuests = _filterGuests;
    int tmpRooms = _filterRooms;
    String tmpType = _filterType;
    bool tmpPool = _filterPool;
    bool tmpBeach = _filterBeach;
    bool tmpInstant = _filterInstant;
    bool tmpOnline = _filterOnline;
    bool tmpWifi = _filterWifi;
    bool tmpParking = _filterParking;
    double tmpRating = _filterMinRating;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: context.kSheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(children: [
            // ── Handle ─────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: context.kBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
            // ── Header ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Text(S.filterTitle,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: context.kText)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setSheet(() {
                      tmpArea = S.all;
                      tmpPrice = const RangeValues(0, 10000);
                      tmpGuests = 1;
                      tmpRooms = 1;
                      tmpType = S.all;
                      tmpPool = false;
                      tmpBeach = false;
                      tmpInstant = false;
                      tmpOnline = false;
                      tmpWifi = false;
                      tmpParking = false;
                      tmpRating = 0;
                    });
                  },
                  child: Text(S.clearAll,
                      style: const TextStyle(
                          color: Color(0xFFFF6B35),
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _kAreas
                            .map((a) => GestureDetector(
                                  onTap: () => setSheet(() => tmpArea = a),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: tmpArea == a
                                          ? const Color(0xFFFF6B35)
                                          : context.kChipBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: tmpArea == a
                                              ? const Color(0xFFFF6B35)
                                              : context.kBorder),
                                    ),
                                    child: Text(a,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: tmpArea == a
                                                ? Colors.white
                                                : context.kSub)),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 20),

                      // ② نوع الوحدة
                      _fSection('🏠 نوع الوحدة'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _kTypes
                            .map((t) => GestureDetector(
                                  onTap: () => setSheet(() => tmpType = t),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: tmpType == t
                                          ? const Color(0xFFFF6D00)
                                          : context.kChipBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: tmpType == t
                                              ? const Color(0xFFFF6D00)
                                              : context.kBorder),
                                    ),
                                    child: Text(t,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: tmpType == t
                                                ? Colors.white
                                                : context.kSub)),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 20),

                      // ③ نطاق السعر
                      _fSection('💰 السعر في الليلة (EGP)'),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _priceChip('${tmpPrice.start.round()} ج'),
                          Icon(Icons.arrow_forward_rounded,
                              size: 16, color: context.kSub),
                          _priceChip('${tmpPrice.end.round()} ج'),
                        ],
                      ),
                      RangeSlider(
                        values: tmpPrice,
                        min: 0,
                        max: 10000,
                        divisions: 100,
                        activeColor: const Color(0xFFFF6B35),
                        inactiveColor: context.kBorder,
                        onChanged: (v) => setSheet(() => tmpPrice = v),
                      ),
                      const SizedBox(height: 16),

                      // ④ عدد الأشخاص
                      _fSection('👥 عدد الأشخاص'),
                      const SizedBox(height: 10),
                      _counterRow(
                        label: 'ضيوف',
                        value: tmpGuests,
                        onDec: () {
                          if (tmpGuests > 1) setSheet(() => tmpGuests--);
                        },
                        onInc: () {
                          if (tmpGuests < 20) setSheet(() => tmpGuests++);
                        },
                      ),
                      const SizedBox(height: 10),
                      _counterRow(
                        label: 'غرف',
                        value: tmpRooms,
                        onDec: () {
                          if (tmpRooms > 1) setSheet(() => tmpRooms--);
                        },
                        onInc: () {
                          if (tmpRooms < 10) setSheet(() => tmpRooms++);
                        },
                      ),
                      const SizedBox(height: 20),

                      // ⑤ الحد الأدنى للتقييم
                      _fSection('⭐ الحد الأدنى للتقييم'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [0.0, 3.0, 3.5, 4.0, 4.5, 5.0]
                            .map(
                              (r) => GestureDetector(
                                onTap: () => setSheet(() => tmpRating = r),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: tmpRating == r
                                        ? const Color(0xFFFFC107)
                                        : context.kChipBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    r == 0 ? S.all : '$r+',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: tmpRating == r
                                            ? Colors.white
                                            : context.kSub),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
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
                color: context.kSheetBg,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, -4)),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    setState(() {
                      _filterArea = tmpArea;
                      _filterPrice = tmpPrice;
                      _filterGuests = tmpGuests;
                      _filterRooms = tmpRooms;
                      _filterType = tmpType;
                      _filterPool = tmpPool;
                      _filterBeach = tmpBeach;
                      _filterInstant = tmpInstant;
                      _filterOnline = tmpOnline;
                      _filterWifi = tmpWifi;
                      _filterParking = tmpParking;
                      _filterMinRating = tmpRating;
                      _filterActive = tmpArea != S.all ||
                          tmpPrice != const RangeValues(0, 10000) ||
                          tmpGuests > 1 ||
                          tmpRooms > 1 ||
                          tmpType != S.all ||
                          tmpPool ||
                          tmpBeach ||
                          tmpInstant ||
                          tmpOnline ||
                          tmpWifi ||
                          tmpParking ||
                          tmpRating > 0;
                    });
                    Navigator.pop(context);
                  },
                  child: Text(S.showResults,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
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
      style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w800, color: context.kText));

  Widget _priceChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.kChipBg,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFF6B35))),
      );

  Widget _counterRow({
    required String label,
    required int value,
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) =>
      Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.kSub)),
        const Spacer(),
        GestureDetector(
          onTap: onDec,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.kChipBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.remove_rounded,
                size: 18, color: const Color(0xFFFF6B35)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('$value',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.kText)),
        ),
        GestureDetector(
          onTap: onInc,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
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
            color: selected ? const Color(0xFFFF6B35) : context.kChipBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? const Color(0xFFFF6B35) : context.kBorder),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : context.kSub)),
        ),
      );

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير ☀️';
    if (h < 17) return 'مساء الخير 🌤️';
    return 'مساء النور 🌙';
  }

  String _getUserName() {
    if (userProvider.hasUser && userProvider.name.isNotEmpty) {
      return userProvider.name.split(' ').first;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'ضيفنا';
    if (user.isAnonymous) return 'ضيفنا';
    final name = user.displayName ?? user.email ?? 'ضيفنا';
    return name.split(' ').first;
  }

  Widget _hdrIcon(IconData icon, {bool notif = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: context.kText, size: 19),
      ),
      if (notif)
        PositionedDirectional(
            top: 7,
            end: 7,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6D00),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFF6B35), width: 1.5),
              ),
            )),
    ]),
    );
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_kHeroes.length, (i) {
            final sel = _heroIdx == i;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: sel ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: sel ? const Color(0xFFFF6B35) : context.kBorder,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ),
    ]);
  }

  void _openAreaResults(String area) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AreaResultsPage(area: area),
        ));
  }

  Widget _heroCard(_Hero h) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: () => _openAreaResults(h.area),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 210,
            child: Stack(children: [
              // ── صورة كاملة بدون أي شريط ─────────────
              Positioned.fill(
                child: Image.asset(
                  h.imagePath,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFF1A2540)),
                ),
              ),

              // ── gradient خفيف من الأسفل بس ──────────
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.35, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Badge فوق يسار ───────────────────────
              PositionedDirectional(
                top: 14,
                start: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6D00),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(h.badge,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5)),
                ),
              ),

              // ── المحتوى تحت ─────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // اسم المنطقة كبير فوق
                      Text(h.displayTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.1,
                          )),

                      const SizedBox(height: 4),

                      // subtitle
                      Text(h.displaySubtitle,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),

                      const SizedBox(height: 10),

                      // الأماكن المتاحة — chips بدون إيموجي
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: h.categories
                            .map(
                              (cat) => GestureDetector(
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => AreaResultsPage(
                                            area: h.area, initialType: cat))),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.35)),
                                  ),
                                  child: Text(cat,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  3. DESTINATIONS
  // ════════════════════════════════════════════════

  Widget _buildDestinations() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
        child: _secTitle(S.destinations, action: S.seeAll, onAction: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => const ExplorePage(),
          ));
        }),
      ),
      SizedBox(
          height: 145,
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
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AreaResultsPage(area: d.name),
          )),
      child: Container(
        width: 155,
        margin: const EdgeInsetsDirectional.only(end: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 5)),
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
                    Text(S.areaName(d.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 6)
                          ],
                        )),
                    // Show the count badge only when the area has live
                    // listings.  Empty areas render no badge at all
                    // (no placeholder copy) so destinations the user
                    // is actively browsing always look "open".
                    if ((_areaCounts[d.name] ?? 0) > 0) ...[
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
                            '${_areaCounts[d.name]} عقار',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  5. FLASH DEALS ⚡
  // ════════════════════════════════════════════════

  // ════════════════════════════════════════════════
  //  OFFERS — Live Firebase stream
  // ════════════════════════════════════════════════

  List<PropertyApi>? _featuredOffers;
  bool _offersLoading = true;

  Future<void> _loadOffers() async {
    try {
      final props = await PropertyService.getProperties();
      final featured = props.where((p) => p.isFeatured).toList();
      if (mounted) setState(() { _featuredOffers = featured; _offersLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _offersLoading = false);
    }
  }

  Widget _buildOffersSection() {
    if (_offersLoading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 0, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ShimmerBox(width: 200, height: 22, radius: 8),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: const _ShimmerBox(width: double.infinity, height: 225, radius: 22)),
              const SizedBox(width: 12),
              Expanded(child: const _ShimmerBox(width: double.infinity, height: 225, radius: 22)),
            ]),
          ],
        ),
      );
    }

    final offers = _featuredOffers ?? [];
    if (offers.isEmpty) return _buildOffersPlaceholder();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
          child: _secTitle(
            appSettings.arabic ? '🔥 العروض الحصرية' : '🔥 Exclusive Deals',
            action: '',
          ),
        ),
        SizedBox(
          height: 225,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: offers.length,
            itemBuilder: (_, i) => _offerCard(offers[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildOffersPlaceholder() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: context.kText.withValues(alpha: 0.12), width: 1.5),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_offer_outlined,
                color: Color(0xFFFF6B35), size: 32),
          ),
          const SizedBox(height: 16),
          Text('لا توجد عروض حالياً',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: context.kText)),
          const SizedBox(height: 6),
          Text('ستظهر العروض والخصومات هنا فور إضافتها',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.kSub)),
        ]),
      ),
    );
  }

  Widget _offerCard(PropertyApi p) {
    final areaColor     = p.areaColor;
    final priceInt      = p.pricePerNight.toStringAsFixed(0);

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PropertyDetailsPage(propertyApi: p))),
      child: Container(
        width: 195,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(
              color: areaColor.withValues(alpha: 0.22),
              blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [areaColor, areaColor.withValues(alpha: 0.65)],
                ),
              ),
            ),
            // Property image overlay
            if (p.firstImage.isNotEmpty)
              Positioned.fill(
                child: Image.network(p.firstImage, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox()),
              ),
            // Dark gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.74),
                    ],
                  ),
                ),
              ),
            ),
            // Card content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Area chip + discount badge
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(p.area,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                    const Spacer(),
                    if (p.isFeatured)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6D00),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('⭐ مميز',
                            style: TextStyle(color: Colors.white,
                                fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                  ]),
                  const Spacer(),
                  // Property name
                  Text(p.name,
                      style: const TextStyle(color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.w900, height: 1.2),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  // Prices
                  Row(children: [
                    Text('EGP $priceInt',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 16, fontWeight: FontWeight.w900)),
                  ]),
                  const SizedBox(height: 5),
                  // Rating
                  if (p.rating > 0)
                    Row(children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFC107), size: 12),
                      const SizedBox(width: 4),
                      Text(p.rating.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white70,
                              fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  BOTTOM NAV
  // ════════════════════════════════════════════════

  Widget _buildNavBar() {
    final items = [
      {'a': Icons.home_rounded, 'o': Icons.home_outlined, 'l': appSettings.arabic ? 'الرئيسية' : 'Home'},
      {'a': Icons.travel_explore_rounded, 'o': Icons.travel_explore_outlined, 'l': appSettings.arabic ? 'أحلى رحلة' : 'Best Trip'},
      {'a': Icons.chat_rounded, 'o': Icons.chat_bubble_outline_rounded, 'l': appSettings.arabic ? 'رسائل' : 'Messages'},
      {'a': Icons.person_rounded, 'o': Icons.person_outline_rounded, 'l': appSettings.arabic ? 'حسابي' : 'Profile'},
    ];

    const accent = Color(0xFFFF6D00); // orange for active tab

    return Container(
      decoration: BoxDecoration(
        color: context.kCard,
        border: Border(top: BorderSide(color: context.kBorder.withValues(alpha: 0.3), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final sel = _navIdx == i;
              final inactiveColor = context.kSub;
              return GestureDetector(
                onTap: () async {
                  if (_navIdx == i) return;
                  // Tabs 1..3 (Bookings / Chat / Profile) all need
                  // a logged-in user — bounce guests to login first.
                  if (i != 0) {
                    final feature = i == 1
                        ? 'تشوف حجوزاتك'
                        : i == 2
                            ? 'تتواصل مع الملاك'
                            : 'تدخل على ملفك';
                    if (!await AuthGuard.require(context,
                        feature: feature)) {
                      return;
                    }
                    if (!mounted) return;
                  }
                  setState(() => _navIdx = i);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        sel
                            ? items[i]['a'] as IconData
                            : items[i]['o'] as IconData,
                        size: 24,
                        color: sel ? accent : inactiveColor),
                    const SizedBox(height: 3),
                    Text(items[i]['l'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                          color: sel ? accent : inactiveColor,
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

  Widget _secTitle(String title, {required String action, VoidCallback? onAction}) {
    return Row(children: [
      Expanded(
          child: Text(title,
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: context.kText,
                  letterSpacing: -0.4))),
      if (action.isNotEmpty) _seeAll(action, onTap: onAction),
    ]);
  }

  Widget _seeAll(String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B35).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFF6B35))),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SEARCH SHEET — اقتراحات ذكية
// ══════════════════════════════════════════════════════════════
class _SearchSheet extends StatefulWidget {
  final List<String> recentSearches;
  final void Function(String query, {String? area, String? type}) onSearch;
  const _SearchSheet({required this.recentSearches, required this.onSearch});
  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  static const _suggestions = [
    {
      'label': 'شاليهات عين السخنة',
      'icon': '🌊',
      'area': 'عين السخنة',
      'type': ''
    },
    {
      'label': 'فيلات الساحل الشمالي',
      'icon': '🏖️',
      'area': 'الساحل الشمالي',
      'type': ''
    },
    {'label': 'منتجعات الغردقة', 'icon': '🐠', 'area': 'الغردقة', 'type': ''},
    {'label': 'فنادق شرم الشيخ', 'icon': '🦈', 'area': 'شرم الشيخ', 'type': ''},
    {'label': 'شاليهات الجونة', 'icon': '⛵', 'area': 'الجونة', 'type': ''},
    {'label': 'عروض رأس سدر', 'icon': '🌬️', 'area': 'رأس سدر', 'type': ''},
    {'label': 'أكوا بارك', 'icon': '🎢', 'area': '', 'type': 'أكوا بارك'},
    {'label': 'شاليهات بحمام سباحة', 'icon': '🏊', 'area': '', 'type': 'شاليه'},
  ];

  List<Map<String, String>> get _filtered {
    if (_query.isEmpty) return List<Map<String, String>>.from(_suggestions);
    return _suggestions
        .where((s) =>
            s['label']!.contains(_query) ||
            (s['area'] ?? '').contains(_query) ||
            (s['type'] ?? '').contains(_query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
    Future.delayed(
        const Duration(milliseconds: 200), () => _focus.requestFocus());
  }

  void _onLangChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: context.kSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: context.kBorder, borderRadius: BorderRadius.circular(2)),
        ),

        // Search input
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: context.kInputFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              const SizedBox(width: 14),
              const Icon(Icons.search_rounded,
                  color: Color(0xFFFF6B35), size: 22),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) widget.onSearch(v.trim());
                },
                decoration: InputDecoration(
                  hintText: 'ابحث عن وجهة، نوع، أو اسم عقار…',
                  hintStyle: TextStyle(color: context.kSub, fontSize: 14),
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                style: TextStyle(fontSize: 15, color: context.kText),
              )),
              if (_query.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _ctrl.clear();
                    setState(() => _query = '');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.close_rounded,
                        color: context.kSub, size: 20),
                  ),
                ),
            ]),
          ),
        ),

        const SizedBox(height: 20),

        // Recent searches
        if (_query.isEmpty && widget.recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(children: [
              Icon(Icons.history_rounded,
                  size: 16, color: context.kSub),
              const SizedBox(width: 6),
              Text(S.recentSearch,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.kSub)),
            ]),
          ),
          ...widget.recentSearches.take(3).map((r) => ListTile(
                dense: true,
                leading: Icon(Icons.history_rounded,
                    color: context.kBorder, size: 18),
                title: Text(r,
                    style: TextStyle(
                        fontSize: 14, color: context.kText)),
                onTap: () => widget.onSearch(r),
              )),
          const Divider(height: 24, indent: 20, endIndent: 20),
        ],

        // Suggestions label
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(children: [
            Icon(_query.isEmpty ? Icons.bolt_rounded : Icons.search_rounded,
                size: 16, color: const Color(0xFFFF6B35)),
            const SizedBox(width: 6),
            Text(_query.isEmpty ? S.suggestions : S.searchHint,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF6B35))),
          ]),
        ),

        // Suggestions list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final s = _filtered[i];
              return ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                      child: Text(s['icon']!,
                          style: const TextStyle(fontSize: 20))),
                ),
                title: Text(s['label']!,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.kText)),
                subtitle: Text(
                  s['area']!.isNotEmpty ? s['area']! : s['type']!,
                  style:
                      TextStyle(fontSize: 12, color: context.kSub),
                ),
                trailing: Icon(Icons.arrow_forward_ios_rounded,
                    size: 13, color: context.kBorder),
                onTap: () => widget.onSearch(
                  s['label']!,
                  area: s['area']!.isNotEmpty ? s['area'] : null,
                  type: s['type']!.isNotEmpty ? s['type'] : null,
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  INLINE ANIMATED SEARCH BAR (home page)
//  - Static prefix "بحث عن" / "Search for"
//  - Rotating keyword that slides up every ~1.6s
//  - No modal sheet: tapping focuses a real TextField in place
//  - Filter button stays on the right, always orange
// ══════════════════════════════════════════════════════════════
class _HomeSearchBar extends StatefulWidget {
  final bool filterActive;
  final VoidCallback onFilterTap;
  final void Function(String query) onSubmit;
  const _HomeSearchBar({
    required this.filterActive,
    required this.onFilterTap,
    required this.onSubmit,
  });

  @override
  State<_HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<_HomeSearchBar> {
  static const _kBrand = Color(0xFFFF6B35);
  static const _kBrandDark = Color(0xFFE85A24);

  // Rotating keywords (Arabic + English pairs).
  static const _keywordsAr = [
    'شاليه',
    'فيلا',
    'شاطئ',
    'أكوا بارك',
    'منتجع',
    'فندق',
    'الساحل الشمالي',
    'الجونة',
  ];
  static const _keywordsEn = [
    'Chalet',
    'Villa',
    'Beach',
    'Aqua Park',
    'Resort',
    'Hotel',
    'Sahel',
    'Gouna',
  ];

  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _rotator;
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
    _focus.addListener(() => setState(() {}));
    _rotator = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (!mounted) return;
      // Don't rotate while the user is typing / field is focused with text.
      if (_focus.hasFocus || _ctrl.text.isNotEmpty) return;
      setState(() => _idx = (_idx + 1) % _keywordsAr.length);
    });
  }

  void _onLangChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange);
    _rotator?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    _focus.unfocus();
    widget.onSubmit(q);
  }

  @override
  Widget build(BuildContext context) {
    final ar = appSettings.arabic;
    final keywords = ar ? _keywordsAr : _keywordsEn;
    final prefix = ar ? 'بحث عن ' : 'Search for ';
    final showRotator = !_focus.hasFocus && _ctrl.text.isEmpty;

    return Container(
      height: 54,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        // Fully transparent fill so the waves Lottie behind the
        // header reads through the search row.  A 1.5px white-ish
        // border + a faint frosted overlay still give the field a
        // tappable affordance without breaking the glass effect.
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        const SizedBox(width: 16),
        // Translucent so the waves animation behind the bar is
        // still legible *through* the icon glyph — the entire bar
        // is supposed to read as glass, not a solid chip.
        Icon(
          Icons.search_rounded,
          color: _kBrand.withValues(alpha: 0.55),
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              // Real text field — always present so tap works instantly.
              TextField(
                controller: _ctrl,
                focusNode: _focus,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                textInputAction: TextInputAction.search,
                style: TextStyle(fontSize: 14, color: context.kText),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                ),
              ),

              // Animated hint overlay — ignores pointer so TextField receives taps.
              if (showRotator)
                IgnorePointer(
                  child: Row(children: [
                    Text(
                      prefix,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        // Soft translucent so the wave motion is
                        // visible behind the prefix copy.  Still
                        // hits ~3.5:1 contrast on white — readable
                        // without dominating the animation.
                        color: context.kText.withValues(alpha: 0.45),
                      ),
                    ),
                    Expanded(
                      child: ClipRect(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 450),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) {
                            final inTween = Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(anim);
                            return ClipRect(
                              child: SlideTransition(
                                position: inTween,
                                child: FadeTransition(
                                    opacity: anim, child: child),
                              ),
                            );
                          },
                          layoutBuilder: (current, previous) => Stack(
                            alignment: AlignmentDirectional.centerStart,
                            children: [...previous, if (current != null) current],
                          ),
                          child: Text(
                            keywords[_idx % keywords.length],
                            key: ValueKey('${ar}_$_idx'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              // Brand orange but translucent so the
                              // wave behind it tints the glyph — the
                              // word still reads orange thanks to the
                              // bold weight + 0.55 alpha floor.
                              color: _kBrand.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
            ],
          ),
        ),

        // Clear button when user has typed something.
        if (_ctrl.text.isNotEmpty)
          GestureDetector(
            onTap: () {
              _ctrl.clear();
              setState(() {});
            },
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Icon(Icons.close_rounded, color: context.kSub, size: 18),
            ),
          ),

        // Filter pill — always orange.
        GestureDetector(
          onTap: widget.onFilterTap,
          child: Stack(children: [
            Container(
              margin: const EdgeInsets.all(7),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.filterActive ? _kBrandDark : _kBrand,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _kBrand.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(children: [
                const Icon(Icons.tune_rounded,
                    color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  ar ? 'فلتر' : 'Filter',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ]),
            ),
            if (widget.filterActive)
              PositionedDirectional(
                top: 4,
                end: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}
