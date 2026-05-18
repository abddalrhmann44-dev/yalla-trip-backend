// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — World-Class Home Page
//  Senior Flutter UI/UX Engineer Level
//  Airbnb + Booking.com quality for Egyptian tourism market
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import '../main.dart' show appSettings, userProvider;
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/constants.dart';
import '../widgets/promo_banner_carousel.dart';
import '../services/promo_banner_service.dart' show PromoBannerItem;
import 'explore_page.dart';
import 'area_results_page.dart';
import '../utils/app_strings.dart';
import '../utils/auth_guard.dart';
import 'best_trip_page.dart';
import 'profile_page.dart';
import 'property_details_page.dart';
import '../models/property_model_api.dart';
import '../services/property_service.dart';
import '../services/recently_viewed_service.dart';
import 'chat_inbox_page.dart';
import 'favorites_page.dart';
import 'notifications_page.dart';
import 'host_today_tab.dart';
import 'owner_dashboard_page.dart';
import 'bookings_page.dart';
import 'host_payouts_page.dart';
import '../services/user_role_service.dart';

// ────────────────────────────────────────────────────────────────
//  MODELS
// ────────────────────────────────────────────────────────────────

/// Lightweight bottom-nav tab descriptor.  Three immutable fields:
/// the active icon, the outline icon, and the label.  Lives at the
/// top of the file so both the guest and host item lists can build
/// the same shape without touching ``Map<String, dynamic>`` casts
/// (which were the source of subtle bugs in the previous version).
class _NavItem {
  final IconData active;
  final IconData icon;
  final String label;
  const _NavItem(this.active, this.icon, this.label);
}

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
  _Dest('دهب', '🤿', [Color(0xFF0288D1), Color(0xFF01579B)],
      'assets/images/destinations/dahb.jpg'),
  _Dest('العلمين الجديدة', '🏙️', [Color(0xFFFF7043), Color(0xFFD84315)],
      // Re-uses the North Coast hero image — New Alamein sits on the
      // same Mediterranean strip and the product team approved sharing
      // the asset until a dedicated photo is shot.
      'assets/images/destinations/north_coast.jpg'),
  _Dest('مرسى مطروح', '🌊', [Color(0xFF00ACC1), Color(0xFF006064)],
      'assets/images/destinations/marsa_matroh.jpg'),
  _Dest('الفيوم', '🐪', [Color(0xFF558B2F), Color(0xFF33691E)],
      'assets/images/destinations/elfayom.jpg'),
  _Dest('الأقصر', '🏛️', [Color(0xFFFFB300), Color(0xFFFF8F00)],
      'assets/images/destinations/alqsor.jpg'),
  _Dest('أسوان', '⛵', [Color(0xFFFF6F00), Color(0xFFE65100)],
      'assets/images/destinations/aswan.jpg'),
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

  // Filter chips inside the home search bar.  Must mirror the
  // host's ``_kLocations`` in lib/pages/owner_add_property_page.dart
  // so every area the user can filter by is also somewhere a host
  // can publish to (otherwise the chip routes to an empty list).
  static const _kAreas = [
    'الكل',
    'عين السخنة',
    'الساحل الشمالي',
    'العلمين الجديدة',
    'مرسى مطروح',
    'الجونة',
    'الغردقة',
    'شرم الشيخ',
    'دهب',
    'رأس سدر',
    'القاهرة',
    'اسكندرية',
    'الفيوم',
    'سهل حشيش',
    'مرسى علم',
    'الأقصر',
    'أسوان',
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
    // Listen for guest⇄owner flips so the bottom-nav swaps in place
    // instead of pushing a separate ``HostShellPage``.  Keeps the
    // user inside the same Scaffold; the IndexedStack just renders
    // a different set of tabs.
    UserRoleService.instance.addListener(_onRoleChanged);
    // Kick off a one-shot role fetch so the cached role is fresh
    // when the user arrives from a deep link.  ``getRole`` is a
    // no-op once the cache is populated.
    UserRoleService.instance.getRole();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Simulate loading
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _isLoading = false);
      _fadeCtrl.forward();
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

  /// Reset to tab 0 whenever the role flips so the user always lands
  /// on the *first* tab of the new mode (Home for guests, Today for
  /// hosts).  Without this, switching from a guest's Profile tab
  /// (index 3) to host mode would surface the host's "Earnings" tab
  /// (also index 3) — a confusing place to start.
  void _onRoleChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _navIdx = 0);
    });
  }

  /// Synchronous host check.  ``cachedRole`` is hydrated by the
  /// ``getRole`` call in ``initState`` and again by every
  /// ``saveRole``; before the first fetch resolves we default to
  /// guest, which is the safer choice for the home page UX.
  bool get _isHost => UserRoleService.instance.isOwnerSync;

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange);
    userProvider.removeListener(_onUserChanged);
    UserRoleService.instance.removeListener(_onRoleChanged);
    _heroTimer?.cancel();
    _fadeCtrl.dispose();
    _heroCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────

  // ════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Pick the active tab set up-front so the AnnotatedRegion,
    // IndexedStack and bottom-nav all stay in lock-step on every
    // role flip.  Guests see the discovery flow; hosts see the
    // dashboard flow — but never via a separate route, always
    // inside this same Scaffold.
    final children = _isHost ? _hostChildren() : _guestChildren();
    // Only the guest "home" tab uses the light status-bar tint
    // (translucent header over the orange waves).  Every other
    // surface — guest sub-tabs *and* every host tab — has a white
    // background, so dark-icon overlay style is correct there.
    final isLightOverlay = !_isHost && _navIdx == 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isLightOverlay
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.kSand,
        // ``extendBody`` lets the home hero bleed under the bottom
        // bar; only meaningful on the guest home tab.  Host tabs
        // have their own scrollable surfaces and shouldn't extend.
        extendBody: !_isHost && _navIdx == 0,
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
            // Clamp in case the role just flipped and ``_navIdx``
            // is briefly out of bounds for the new tab set (the
            // PostFrame callback in ``_onRoleChanged`` resets it,
            // but a guarded clamp avoids a one-frame
            // ``RangeError`` on slow devices).
            index: _navIdx.clamp(0, children.length - 1),
            children: children,
          ),
        ),
      ),
    );
  }

  /// Guest-mode tab roots, in display order.  Indexes here MUST
  /// align with ``_guestNavItems`` below.
  List<Widget> _guestChildren() => [
        _isLoading ? _buildShimmerScreen() : _buildContent(),
        const BestTripPage(embedded: true),
        const ChatInboxPage(embedded: true),
        const ProfilePage(embedded: true),
      ];

  /// Host-mode tab roots, in display order.  Indexes here MUST
  /// align with ``_hostNavItems`` below.  ``Profile`` is the last
  /// tab so the host can flip back to guest mode without leaving
  /// the shell.  Only ``BookingsPage`` and ``ProfilePage`` accept an
  /// ``embedded`` flag today — the other host pages render their
  /// own scrollable surfaces with no AppBar, which is exactly what
  /// we want inside the shell.
  List<Widget> _hostChildren() => const [
        HostTodayTab(),
        OwnerDashboardPage(),
        BookingsPage(embedded: true),
        HostPayoutsPage(),
        ProfilePage(embedded: true),
      ];

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
          // Wave 30 — admin-curated promo banners above the
          // destinations rail.  The widget self-hides when no active
          // banners are scheduled, so the homepage layout stays
          // unchanged if marketing hasn't pushed anything.
          SliverToBoxAdapter(
            child: PromoBannerCarousel(onTap: _handlePromoBannerTap),
          ),
          SliverToBoxAdapter(child: _buildDestinations()),
          SliverToBoxAdapter(child: _buildOffersSection()),
          SliverToBoxAdapter(child: _buildRecentlyViewedSection()),
          // Wave 30 � replaced the two area-pinned "Popular in
          // Hurghada / Sharm" rows with a single random pick of
          // chalets + hotels (per user request).  The shuffle runs
          // once per session in `_loadOffers` so the order stays
          // stable across rebuilds and feels curated, not jittery.
          SliverToBoxAdapter(child: _buildRandomChaletsAndHotels()),
          SliverToBoxAdapter(child: _buildRecommendationBanners()),
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
                      feature: S.featureViewFavorites)) {
                    return;
                  }
                  if (!mounted) return;
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const FavoritesPage()));
                }),
                const SizedBox(width: 8),
                _hdrIcon(Icons.chat_bubble_outline_rounded, onTap: () async {
                  if (!await AuthGuard.require(context,
                      feature: S.featureChatHosts)) {
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
                      feature: S.featureViewNotifications)) {
                    return;
                  }
                  if (!mounted) return;
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const NotificationsPage()));
                }),
              ]),

              const SizedBox(height: 16),

              // ── Search pill (Wave 28 — airbnb-style) ──────────
              // Tapping the pill no longer focuses an inline field.
              // It opens the full ``_SearchSheet`` overlay (recent
              // queries + curated suggestions), which is closer to
              // how guests actually browse — they pick a vibe
              // ("شاليهات عين السخنة") rather than free-typing.
              _HomeSearchPill(
                filterActive: _filterActive,
                onFilterTap: _openFilter,
                onTap: _openSearchSheet,
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
                      _fSection(S.filterAreaTitle),
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
                                    child: Text(a == 'الكل' ? S.all : S.areaName(a),
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
                      _fSection(S.filterPropertyType),
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
                                    child: Text(t == 'الكل' ? S.all : S.catName(t),
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
                      _fSection(S.filterPriceRange),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _priceChip('${tmpPrice.start.round()} ${S.egp}'),
                          Icon(Icons.arrow_forward_rounded,
                              size: 16, color: context.kSub),
                          _priceChip('${tmpPrice.end.round()} ${S.egp}'),
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
                      _fSection(S.filterGuestCount),
                      const SizedBox(height: 10),
                      _counterRow(
                        label: S.filterGuestsRow,
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
                        label: S.filterRoomsRow,
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
                      _fSection(S.filterMinRatingTitle),
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
                      _fSection(S.filterFeatures),
                      const SizedBox(height: 10),
                      Wrap(spacing: 10, runSpacing: 10, children: [
                        _featureChip(S.featurePool, tmpPool,
                            () => setSheet(() => tmpPool = !tmpPool)),
                        _featureChip(S.featurePrivateBeach, tmpBeach,
                            () => setSheet(() => tmpBeach = !tmpBeach)),
                        _featureChip(S.featureInstantBook, tmpInstant,
                            () => setSheet(() => tmpInstant = !tmpInstant)),
                        _featureChip(S.featureOnlineNow, tmpOnline,
                            () => setSheet(() => tmpOnline = !tmpOnline)),
                        _featureChip(S.featureWifi, tmpWifi,
                            () => setSheet(() => tmpWifi = !tmpWifi)),
                        _featureChip(S.featureParking, tmpParking,
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
    if (h < 12) return S.greetingMorning;
    if (h < 17) return S.greetingAfternoon;
    return S.greetingEvening;
  }

  String _getUserName() {
    if (userProvider.hasUser && userProvider.name.isNotEmpty) {
      return userProvider.name.split(' ').first;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return S.guestNameLabel;
    if (user.isAnonymous) return S.guestNameLabel;
    final name = user.displayName ?? user.email ?? S.guestNameLabel;
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

  // ════════════════════════════════════════════════
  //  Search sheet launcher (shared between header pill and any
  //  future entry points — e.g. a /search deep link).
  // ════════════════════════════════════════════════
  void _openSearchSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchSheet(
        recentSearches: _recentSearches,
        onSearch: (q, {area, type}) {
          Navigator.pop(context);
          // Persist into the recent-search ring buffer (capped at 6).
          setState(() {
            if (q.isNotEmpty && !_recentSearches.contains(q)) {
              _recentSearches.insert(0, q);
              if (_recentSearches.length > 6) _recentSearches.removeLast();
            }
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExplorePage(
                initialSearch: q,
                initialArea: area,
                initialType: type,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Dispatcher for promo-banner taps.  Routes by ``ctaKind``:
  ///   - deeplink / url → external browser via [launchUrl]
  ///   - area           → area results page
  ///   - property       → property details page (fetches by id)
  ///   - none           → no-op
  Future<void> _handlePromoBannerTap(PromoBannerItem b) async {
    final target = b.ctaTarget?.trim() ?? '';
    switch (b.ctaKind) {
      case 'url':
      case 'deeplink':
        if (target.isEmpty) return;
        final uri = Uri.tryParse(target);
        if (uri == null) return;
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {/* silently ignore broken URLs */}
        return;
      case 'area':
        if (target.isEmpty) return;
        _openAreaResults(target);
        return;
      case 'property':
        final pid = int.tryParse(target);
        if (pid == null) return;
        try {
          final p = await PropertyService.getProperty(pid);
          if (!mounted) return;
          await _openProperty(p);
        } catch (_) {/* property may have been deleted */}
        return;
      default:
        return;
    }
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
                                  child: Text(S.catName(cat),
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

  /// Wave 28 � cache of every approved listing fetched in [_loadOffers].
  /// We reuse it so the "Recently viewed" + future Popular rows don't
  /// each trigger their own ``getProperties`` round-trip.
  List<PropertyApi> _allProperties = const [];

  /// Wave 30 � a shuffled subset of [_allProperties] limited to
  /// chalets (شاليه) and hotels (فندق).  Computed once per session
  /// in [_loadOffers] so the order doesn't jitter on every rebuild.
  /// Empty until offers finish loading, or when the catalog has no
  /// matching listings yet.
  List<PropertyApi> _randomPicks = const [];

  /// Wave 28 � hydrated PropertyApi objects for the IDs the guest
  /// opened in [PropertyDetailsPage] (newest first, capped to 10
  /// by [RecentlyViewedService.kMaxEntries]).  Empty for fresh users.
  List<PropertyApi> _recentlyViewed = const [];

  Future<void> _loadOffers() async {
    try {
      final props = await PropertyService.getProperties();
      // Wave 28: the Offers row now lists ONLY listings with a live
      // limited-time offer (configured by the host through the owner
      // form Step 8 toggle).  We sort by earliest expiry so the
      // �about to end� cards bubble to the front � that's also what
      // drives the urgency in the countdown timer.
      final active = props.where((p) => p.isOfferActive).toList()
        ..sort((a, b) =>
            (a.offerEnd ?? DateTime(2100)).compareTo(b.offerEnd ?? DateTime(2100)));
      _allProperties = props;
      // Wave 30 � pre-compute the random chalets-and-hotels row.
      // We shuffle a *copy* (Random with no seed → fresh order on
      // each cold start) and cap at 8 cards.  Doing this once here,
      // instead of inside the build method, keeps the order stable
      // for the whole session so the user can scroll back to the
      // same row without it reshuffling under them.
      final picksPool = props
          .where((p) => p.category == 'شاليه' || p.category == 'فندق')
          .toList()
        ..shuffle(Random());
      final picks = picksPool.take(8).toList();
      final recent = await _hydrateRecentlyViewed(props);
      if (mounted) {
        setState(() {
          _featuredOffers = active;
          _recentlyViewed = recent;
          _randomPicks = picks;
          _offersLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _offersLoading = false);
    }
  }

  /// Resolves the on-device recently-viewed IDs into the matching
  /// [PropertyApi] objects from [_allProperties].  IDs that are no
  /// longer in the catalog (deleted listings, etc.) are silently
  /// skipped so the row doesn't render "ghost" cards.
  Future<List<PropertyApi>> _hydrateRecentlyViewed(
      List<PropertyApi> all) async {
    try {
      final ids = await RecentlyViewedService.instance.getIds();
      if (ids.isEmpty) return const [];
      final byId = {for (final p in all) p.id: p};
      return ids.map((id) => byId[id]).whereType<PropertyApi>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Light-weight refresh used whenever the user comes back from the
  /// details page: we only need to re-read SharedPreferences �
  /// [_allProperties] is still good.
  Future<void> _refreshRecentlyViewed() async {
    if (_allProperties.isEmpty) return;
    final recent = await _hydrateRecentlyViewed(_allProperties);
    if (!mounted) return;
    setState(() => _recentlyViewed = recent);
  }

  /// Wraps a [Navigator.push] to the details page so we can refresh
  /// the "Recently viewed" row the moment the user comes back.  This
  /// keeps the row synchronised without a polling timer or a
  /// RouteObserver.
  Future<void> _openProperty(PropertyApi p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PropertyDetailsPage(propertyApi: p)),
    );
    if (!mounted) return;
    _refreshRecentlyViewed();
  }

  // ══════════════════════════════════════════════════════════
  //  RECENTLY VIEWED (Wave 28)
  //  - Hidden entirely when the user has no recents (no empty
  //    placeholder, since this is purely a personalisation row).
  //  - Compact horizontal card with image + name + price; opens the
  //    details page on tap and refreshes the row when the user
  //    pops back so re-tapping a card doesn't visually duplicate it.
  // ══════════════════════════════════════════════════════════
  Widget _buildRecentlyViewedSection() {
    if (_recentlyViewed.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
          child: _secTitle(
            S.recentlyViewedTitle,
            action: '',
          ),
        ),
        SizedBox(
          height: 178,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recentlyViewed.length,
            itemBuilder: (_, i) => _recentCard(_recentlyViewed[i]),
          ),
        ),
      ],
    );
  }

  Widget _recentCard(PropertyApi p) {
    final priceLabel = 'EGP ${p.effectivePrice.toStringAsFixed(0)}';
    return GestureDetector(
      onTap: () => _openProperty(p),
      child: Container(
        width: 165,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.kBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo (or area-tinted fallback) � fixed height so all
              // cards align horizontally regardless of aspect ratio.
              SizedBox(
                height: 100,
                child: Stack(fit: StackFit.expand, children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          p.areaColor,
                          p.areaColor.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                  if (p.firstImage.isNotEmpty)
                    Image.network(
                      p.firstImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  if (p.isOfferActive)
                    PositionedDirectional(
                      top: 8,
                      end: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '-${p.offerDiscountPercent}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: context.kText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      S.areaName(p.area),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: context.kSub,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text(
                        priceLabel,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                      const Spacer(),
                      if (p.rating > 0) ...[
                        const Icon(Icons.star_rounded,
                            size: 12, color: Color(0xFFFFC107)),
                        const SizedBox(width: 2),
                        Text(
                          p.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.kText,
                          ),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  RANDOM CHALETS & HOTELS  (Wave 30)
  //  - Replaces the old "Popular in Hurghada / Sharm" rows.
  //  - The pool is filtered to category ∈ {شاليه, فندق} only so
  //    villas, day-use trips, boats, etc. don't muddy the row.
  //  - The shuffle is done once in `_loadOffers` (see _randomPicks)
  //    so the same 8 cards stay in the same order while the user
  //    is on the home screen � they only refresh on the next cold
  //    start (or when the user pulls-to-refresh, which calls
  //    `_loadOffers` again).
  //  - Hides itself when the catalog has no chalets/hotels yet.
  // ══════════════════════════════════════════════════════════
  Widget _buildRandomChaletsAndHotels() {
    if (_randomPicks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
          child: _secTitle(
            S.selectedChaletsHotels,
            action: '',
          ),
        ),
        SizedBox(
          height: 178,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _randomPicks.length,
            itemBuilder: (_, i) => _recentCard(_randomPicks[i]),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  RECOMMENDATION BANNERS (Wave 28)
  //  Two large gradient cards inviting the guest to discover Dahab
  //  and the North Coast.  Tapping one opens the area-filtered
  //  results page (re-using AreaResultsPage so listing rules,
  //  filters, etc. stay consistent).
  // ══════════════════════════════════════════════════════════
  Widget _buildRecommendationBanners() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secTitle(
            S.tripsForYou,
            action: '',
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _recommendationCard(
                area: 'دهب',
                title: S.stayInDahab,
                subtitle: S.dahabSubtitle,
                emoji: '🐠',
                colors: const [Color(0xFF00897B), Color(0xFF004D40)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _recommendationCard(
                area: 'الساحل الشمالي',
                title: S.stayInSahel,
                subtitle: S.sahelSubtitle,
                emoji: '🏖️',
                colors: const [Color(0xFFE85A24), Color(0xFFFF6B35)],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _recommendationCard({
    required String area,
    required String title,
    required String subtitle,
    required String emoji,
    required List<Color> colors,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AreaResultsPage(area: area)),
      ),
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(children: [
          PositionedDirectional(
            top: -6,
            end: -6,
            child: Text(emoji, style: const TextStyle(fontSize: 60)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  S.areaName(area),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Text(
                  S.exploreNowShort,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 13),
              ]),
            ],
          ),
        ]),
      ),
    );
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
            S.exclusiveDeals,
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
          Text(S.noOffersNow,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: context.kText)),
          const SizedBox(height: 6),
          Text(S.offersWillAppear,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.kSub)),
        ]),
      ),
    );
  }

  Widget _offerCard(PropertyApi p) {
    final areaColor = p.areaColor;
    final ar = appSettings.arabic;
    final pct = p.offerDiscountPercent;
    final originalPrice = p.pricePerNight.toStringAsFixed(0);
    final discounted = p.effectivePrice.toStringAsFixed(0);

    return GestureDetector(
      onTap: () => _openProperty(p),
      child: Container(
        width: 215,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: areaColor.withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(children: [
            // Background gradient � falls back to brand-tinted when
            // no image is on file (offer cards still look intentional
            // even on freshly created listings).
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [areaColor, areaColor.withValues(alpha: 0.65)],
                ),
              ),
            ),
            if (p.firstImage.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  p.firstImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            // Dark gradient over the photo so the white text + the
            // bottom price row keep WCAG-AA contrast.
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.78),
                    ],
                  ),
                ),
              ),
            ),
            // ---- Card content ----------------------------------
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    // Area chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        S.areaName(p.area),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Discount badge � the visual hook of the card.
                    if (pct > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF3B30)
                                  .withValues(alpha: 0.45),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '-$pct%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ]),
                  const Spacer(),
                  Text(
                    p.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Strike-through original price + discounted price.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'EGP $discounted',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        originalPrice,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Live countdown � ticks every second so the user
                  // feels the urgency.  When the offer expires the
                  // widget self-removes (returns SizedBox.shrink).
                  if (p.offerEnd != null)
                    _OfferCountdown(
                      end: p.offerEnd!,
                      arabic: ar,
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BOTTOM NAV
  // ═══════════════════════════════════════════════════════════════
  Widget _buildNavBar() {
    // ── Two distinct, ordered tab sets ────────────────────
    // Guest set is the discovery flow (4 tabs).  Host set is the
    // dashboard flow (5 tabs) and Profile sits at the end so the
    // host can flip back to guest mode without leaving the shell.
    final items = _isHost
        ? <_NavItem>[
            _NavItem(
                Icons.dashboard_rounded,
                Icons.dashboard_outlined,
                S.navToday),
            _NavItem(
                Icons.apartment_rounded,
                Icons.apartment_outlined,
                S.navListings),
            _NavItem(
                Icons.calendar_month_rounded,
                Icons.calendar_month_outlined,
                S.navReservations),
            _NavItem(
                Icons.account_balance_wallet_rounded,
                Icons.account_balance_wallet_outlined,
                S.navEarnings),
            _NavItem(
                Icons.person_rounded,
                Icons.person_outline_rounded,
                S.navProfile),
          ]
        : <_NavItem>[
            _NavItem(
                Icons.home_rounded,
                Icons.home_outlined,
                S.navHomeTab),
            _NavItem(
                Icons.travel_explore_rounded,
                Icons.travel_explore_outlined,
                S.navBestTrip),
            _NavItem(
                Icons.chat_rounded,
                Icons.chat_bubble_outline_rounded,
                S.navMessages),
            _NavItem(
                Icons.person_rounded,
                Icons.person_outline_rounded,
                S.navProfile),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final sel = _navIdx == i;
              final inactiveColor = context.kSub;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    if (_navIdx == i) return;
                    // Guest mode: tabs 1..3 (Best Trip / Chat /
                    // Profile) all need a logged-in user — bounce
                    // guests to login first.  Host mode skips this
                    // ladder because hosts are authenticated by
                    // definition.
                    if (!_isHost && i != 0) {
                      final feature = i == 1
                          ? S.featureViewBookings
                          : i == 2
                              ? S.featureChatHosts
                              : S.featureOpenProfile;
                      if (!await AuthGuard.require(context,
                          feature: feature)) {
                        return;
                      }
                      if (!mounted) return;
                    }
                    setState(() => _navIdx = i);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                    child:
                        Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(sel ? item.active : item.icon,
                          size: 24,
                          color: sel ? accent : inactiveColor),
                      const SizedBox(height: 3),
                      Text(item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                sel ? FontWeight.w800 : FontWeight.w500,
                            color: sel ? accent : inactiveColor,
                          )),
                    ]),
                  ),
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
                  hintText: S.searchHintHome,
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
              final area = s['area'] ?? '';
              final type = s['type'] ?? '';
              // Translate the visible label by re-deriving it from
              // (area, type) instead of trusting the Arabic key.
              final String displayLabel;
              if (area.isNotEmpty && type.isEmpty) {
                final cat = (s['label'] ?? '').split(' ').first;
                if (cat == 'شاليهات') {
                  displayLabel = S.suggestChaletsArea(S.areaName(area));
                } else if (cat == 'فيلات') {
                  displayLabel = S.suggestVillasArea(S.areaName(area));
                } else if (cat == 'منتجعات') {
                  displayLabel = S.suggestResortsArea(S.areaName(area));
                } else if (cat == 'فنادق') {
                  displayLabel = S.suggestHotelsArea(S.areaName(area));
                } else if (cat == 'عروض') {
                  displayLabel = S.suggestDealsArea(S.areaName(area));
                } else {
                  displayLabel = s['label']!;
                }
              } else if (type == 'أكوا بارك') {
                displayLabel = S.suggestAquaPark;
              } else if (type == 'شاليه') {
                displayLabel = S.suggestChaletsPool;
              } else {
                displayLabel = s['label']!;
              }
              final displaySubtitle = area.isNotEmpty
                  ? S.areaName(area)
                  : type.isNotEmpty
                      ? S.catName(type)
                      : '';
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
                title: Text(displayLabel,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.kText)),
                subtitle: Text(
                  displaySubtitle,
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
//  HOME SEARCH PILL (Wave 28 — airbnb-style)
//  - Solid white pill with a soft drop shadow.
//  - Tapping the pill opens the full ``_SearchSheet`` overlay
//    (recent queries + curated suggestions).
//  - A small trailing filter chip lives inside the pill on the
//    end side; the orange dot reappears when a filter is active
//    so users can see at a glance that the result set is narrowed.
// ══════════════════════════════════════════════════════════════
class _HomeSearchPill extends StatelessWidget {
  final bool filterActive;
  final VoidCallback onFilterTap;
  final VoidCallback onTap;
  const _HomeSearchPill({
    required this.filterActive,
    required this.onFilterTap,
    required this.onTap,
  });

  static const _kBrand = Color(0xFFFF6B35);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        // Solid white reads cleanly against the wave-Lottie
        // backdrop and matches the airbnb-style mock the user
        // requested.  Border kept to a hair so the pill still has
        // crisp edges on light-mode (where the card colour and
        // background are very close).
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: const Color(0xFFE8E8E8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(40),
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 6, 0),
            child: Row(children: [
              const Icon(
                Icons.search_rounded,
                color: _kBrand,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  S.startSearch,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
              // Trailing filter chip — circular, only fills with
              // the brand colour when at least one filter is set
              // (so an unconfigured pill reads as a neutral icon).
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onFilterTap,
                  child: Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: filterActive
                          ? _kBrand
                          : const Color(0xFFF5F5F5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: filterActive
                            ? _kBrand
                            : const Color(0xFFE8E8E8),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: filterActive
                          ? Colors.white
                          : const Color(0xFF666666),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  OFFER COUNTDOWN (Wave 28)
//  Live "ينتهي خلال …" badge for the home-page Offers row.
//  Ticks once per second; when the offer expires the widget
//  collapses to a SizedBox so the parent card silently drops the
//  timer instead of showing a stale "0:00:00".
// ══════════════════════════════════════════════════════════════
class _OfferCountdown extends StatefulWidget {
  final DateTime end;
  final bool arabic;
  const _OfferCountdown({required this.end, required this.arabic});

  @override
  State<_OfferCountdown> createState() => _OfferCountdownState();
}

class _OfferCountdownState extends State<_OfferCountdown> {
  Timer? _ticker;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _compute();
    // 1-second cadence is plenty � the card is small enough that
    // sub-second precision would be wasted GPU.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _compute());
    });
  }

  Duration _compute() {
    final now = DateTime.now().toUtc();
    final end = widget.end.toUtc();
    if (!now.isBefore(end)) return Duration.zero;
    return end.difference(now);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _format(Duration d) {
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    final ar = widget.arabic;
    if (days > 0) {
      // Past 24h: "3ي 04:12:08" reads cleaner than the full string.
      return ar
          ? '$daysي ${_two(hours)}:${_two(minutes)}:${_two(seconds)}'
          : '${days}d ${_two(hours)}:${_two(minutes)}:${_two(seconds)}';
    }
    return '${_two(hours)}:${_two(minutes)}:${_two(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            S.endsIn,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            _format(_remaining),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
