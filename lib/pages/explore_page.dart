// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Explore Page
//  Advanced Search · Filters · Map Areas · Trending · Today Deals
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../main.dart' show appSettings;
import '../utils/app_strings.dart';
import '../widgets/constants.dart';
import 'property_details_page.dart';
import '../models/property_model_api.dart';
import '../services/property_service.dart';

// ── Colors (theme-dependent ones come from AppThemeX) ─────────
const _kOcean  = Color(0xFF1565C0);
const _kOrange = Color(0xFFFF6D00);
const _kGreen  = Color(0xFF4CAF50);

// ── Static Data ───────────────────────────────────────────────
final List<Map<String, dynamic>> _kAreas = [
  {'name': S.ainSokhna,  'emoji': '🏖️', 'count': '48',  'color': const Color(0xFF0288D1)},
  {'name': S.northCoast, 'emoji': '🌴', 'count': '120', 'color': const Color(0xFF1976D2)},
  {'name': S.gouna,    'emoji': '⛵', 'count': '67',  'color': const Color(0xFFE65100)},
  {'name': S.hurghada,    'emoji': '🐠', 'count': '95',  'color': const Color(0xFF00695C)},
  {'name': S.sharm,       'emoji': '🦈', 'count': '142', 'color': const Color(0xFF6A1B9A)},
  {'name': S.rasSedr,    'emoji': '🌬️', 'count': '31',  'color': const Color(0xFF00897B)},
];

const _kCategories = [
  'الكل', 'شاليهات', 'فنادق', 'منتجعات', 'فيلات', 'أكوا بارك', 'بيت شاطئ',
];


// ════════════════════════════════════════════════════════════
//  EXPLORE PAGE
// ════════════════════════════════════════════════════════════

class ExplorePage extends StatefulWidget {
  final String? initialArea;
  final String? initialType;
  final String? initialSearch;
  const ExplorePage({super.key, this.initialArea, this.initialType, this.initialSearch});
  @override State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with SingleTickerProviderStateMixin {

  // ── Data ───────────────────────────────────────────────
  List<PropertyApi> _allProperties = [];
  bool _dbLoading = true;

  // ── Search & Filter ─────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _query       = '';
  String _selArea     = S.all;
  String _selCat      = S.all;
  int    _maxPrice    = 10000;
  double _minRating   = 0;
  bool   _instantOnly = false;
  bool   _onlineOnly  = false;
  final Set<String> _selAmenities = {};
  bool   _showFilters = false;

  // ── Tabs ────────────────────────────────────────────────────
  late TabController _tabCtrl;

  // ── Favorites ───────────────────────────────────────────────
  final Set<String> _favs = {};

  // ── View mode ───────────────────────────────────────────────
  bool _gridView = false;

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
    // تطبيق الـ initial filters القادمة من HomePage
    if (widget.initialArea != null && widget.initialArea!.isNotEmpty) {
      _selArea = widget.initialArea!;
    }
    if (widget.initialType != null && widget.initialType!.isNotEmpty) {
      _selCat = widget.initialType!;
    }
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _query = widget.initialSearch!;
      _searchCtrl.text = widget.initialSearch!;
    }
    _tabCtrl = TabController(length: 4, vsync: this);
    _searchCtrl.addListener(() =>
        setState(() => _query = _searchCtrl.text.toLowerCase()));
    _loadProperties();
  }

  void _onLangChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange);
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Load from API ─────────────────────────────────
  Future<void> _loadProperties() async {
    try {
      final props = await PropertyService.getProperties();
      if (mounted) { setState(() {
        _allProperties = props;
        _dbLoading     = false;
      }); }
    } catch (e) {
      if (mounted) { setState(() => _dbLoading = false); }
    }
  }

  Future<void> _refreshProperties() => _loadProperties();

  // ── Filtered list ───────────────────────────────────────────
  List<PropertyApi> get _filtered {
    return _allProperties.where((p) {
      final matchQ    = _query.isEmpty ||
          p.name.toLowerCase().contains(_query) ||
          p.area.toLowerCase().contains(_query) ||
          p.description.toLowerCase().contains(_query);
      final matchArea = _selArea == S.all || p.area == _selArea;
      final matchCat  = _selCat  == S.all || p.category == _selCat;
      final matchPrice   = p.pricePerNight <= _maxPrice;
      final matchRating  = p.rating >= _minRating;
      final matchInstant = !_instantOnly || p.instantBooking;
      final matchOnline  = !_onlineOnly  || p.instantBooking;
      return matchQ && matchArea && matchCat && matchPrice &&
             matchRating && matchInstant && matchOnline;
    }).toList();
  }

  List<PropertyApi> get _trending => _allProperties
      .where((p) => p.reviewCount > 100).toList()
    ..sort((a, b) => b.reviewCount.compareTo(a.reviewCount));

  List<PropertyApi> get _todayDeals => _allProperties
      .where((p) => p.isFeatured).toList();

  String _comma(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  // ════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      body: Column(children: [
        _buildHeader(),
        if (_showFilters) _buildFilterPanel(),
        Expanded(
          child: _dbLoading
              ? const Center(child: CircularProgressIndicator(color: _kOcean))
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildSearchTab(),
                    _buildMapTab(),
                    _buildTrendingTab(),
                    _buildTodayTab(),
                  ],
                ),
        ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomCenter,
          colors: [Color(0xFF0A2463), Color(0xFF1565C0), Color(0xFF1E88E5)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          // Top row
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
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              Text(S.explore,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 20, fontWeight: FontWeight.w900)),
              const Spacer(),
              // Grid/List toggle
              GestureDetector(
                onTap: () => setState(() => _gridView = !_gridView),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                    color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 12),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: context.kCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: Row(children: [
                const SizedBox(width: 14),
                const Icon(Icons.search_rounded, color: _kOcean, size: 20),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(fontSize: 14, color: context.kText),
                  decoration: InputDecoration(
                    hintText: S.exploreSearchHint,
                    hintStyle: TextStyle(color: context.kSub, fontSize: 13),
                    border: InputBorder.none,
                  ),
                )),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () { _searchCtrl.clear(); setState(() => _query = ''); },
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: Icon(Icons.close_rounded, color: context.kSub, size: 18)),
                  ),
                // Filter button
                GestureDetector(
                  onTap: () => setState(() => _showFilters = !_showFilters),
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _showFilters ? _kOrange : _kOcean,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.tune_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(_showFilters ? S.close : S.filterBtn,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          // Tab bar
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: [
              Tab(text: '🔍  ${S.search}'),
              Tab(text: '🗺️  ${S.areasTab}'),
              Tab(text: '🔥  ${S.trending}'),
              Tab(text: '⚡  ${S.deals}'),
            ],
          ),
        ]),
      ),
    );
  }

  // ── Filter Panel ──────────────────────────────────────────
  Widget _buildFilterPanel() {
    return Container(
      color: context.kCard,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // Area chips
        _filterLabel('📍 ${S.area}'),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _areaChip(S.all),
            ..._kAreas.map((a) => _areaChip(a['name'] as String)),
          ]),
        ),

        const SizedBox(height: 10),

        // Category
        _filterLabel('🏷️ ${S.propType}'),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _kCategories
              .map((c) => _catChip(c)).toList()),
        ),

        const SizedBox(height: 10),

        // Price
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
          _filterLabel('💰 ${S.maxPriceLabel}'),
          Text('${S.egp} ${_comma(_maxPrice)}',
              style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w800, color: _kOcean)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _kOcean, thumbColor: _kOcean,
            inactiveTrackColor: context.kBorder, trackHeight: 4,
            overlayColor: _kOcean.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: _maxPrice.toDouble(),
            min: 500, max: 10000, divisions: 19,
            onChanged: (v) => setState(() => _maxPrice = v.toInt()),
          ),
        ),

        // Rating + toggles
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            _filterLabel('⭐ ${S.minRating}: ${_minRating.toStringAsFixed(1)}'),
            Slider(
              value: _minRating, min: 0, max: 5, divisions: 10,
              activeColor: const Color(0xFFFFC107),
              inactiveColor: context.kBorder,
              onChanged: (v) => setState(() => _minRating = v),
            ),
          ])),

          Column(children: [
            _toggle('⚡ ${S.instantOnly}', _instantOnly,
                (v) => setState(() => _instantOnly = v)),
            _toggle('🟢 ${S.onlineOnly}', _onlineOnly,
                (v) => setState(() => _onlineOnly = v)),
          ]),
        ]),

        // Reset
        GestureDetector(
          onTap: _resetFilters,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(S.resetFilters,
                style: TextStyle(fontSize: 12,
                    color: _kOrange, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  void _resetFilters() => setState(() {
    _selArea = S.all; _selCat = S.all;
    _maxPrice = 10000; _minRating = 0;
    _instantOnly = false; _onlineOnly = false;
    _selAmenities.clear();
  });

  Widget _areaChip(String area) {
    final sel = _selArea == area;
    return GestureDetector(
      onTap: () => setState(() => _selArea = area),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsetsDirectional.only(end: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _kOcean : context.kSand,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? _kOcean : context.kBorder),
        ),
        child: Text(area, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: sel ? Colors.white : context.kSub)),
      ),
    );
  }

  Widget _catChip(String cat) {
    final sel = _selCat == cat;
    return GestureDetector(
      onTap: () => setState(() => _selCat = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsetsDirectional.only(end: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _kOrange : context.kSand,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? _kOrange : context.kBorder),
        ),
        child: Text(S.catName(cat), style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: sel ? Colors.white : context.kSub)),
      ),
    );
  }

  Widget _filterLabel(String t) => Text(t,
      style: TextStyle(fontSize: 12,
          fontWeight: FontWeight.w700, color: context.kSub));

  Widget _toggle(String label, bool val, ValueChanged<bool> onChange) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 11, color: context.kSub)),
      Switch.adaptive(value: val, activeThumbColor: _kOcean,
          onChanged: onChange, materialTapTargetSize:
          MaterialTapTargetSize.shrinkWrap),
    ]);
  }

  // ── TAB 1: Search ─────────────────────────────────────────
  Widget _buildSearchTab() {
    final results = _filtered;
    return RefreshIndicator(
      onRefresh: _refreshProperties,
      color: _kOcean,
      child: Column(children: [
      // Result count
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        child: Row(children: [
          Text('${results.length} ${S.propertiesFound}',
              style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w700, color: context.kText)),
          const Spacer(),
          Text(_selArea == S.all ? S.allAreas : _selArea,
              style: TextStyle(fontSize: 12, color: context.kSub)),
        ]),
      ),

      Expanded(child: results.isEmpty
          ? _emptyState()
          : _gridView
              ? _buildGrid(results)
              : _buildList(results)),
      ]),
    );
  }

  Widget _buildList(List<PropertyApi> props) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: props.length,
      itemBuilder: (_, i) => _propListCard(props[i]),
    );
  }

  Widget _buildGrid(List<PropertyApi> props) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12, mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: props.length,
      itemBuilder: (_, i) => _propGridCard(props[i]),
    );
  }

  // ── TAB 2: Map Areas ──────────────────────────────────────
  Widget _buildMapTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // Area cards
        // Row 1
        Row(children: [
          _bigAreaCard(_kAreas[0]),
          const SizedBox(width: 12),
          _bigAreaCard(_kAreas[1]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _bigAreaCard(_kAreas[2]),
          const SizedBox(width: 12),
          _bigAreaCard(_kAreas[3]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _bigAreaCard(_kAreas[4]),
          const SizedBox(width: 12),
          _bigAreaCard(_kAreas[5]),
        ]),

        const SizedBox(height: 24),

        // Egypt map illustration (stylized)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.kBorder),
          ),
          child: Column(children: [
            Text('🗺️ ${S.egyptMap}',
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w900, color: context.kText)),
            const SizedBox(height: 16),
            // Stylized map dots
            _mapIllustration(),
          ]),
        ),
      ]),
    );
  }

  Widget _bigAreaCard(Map<String, dynamic> area) {
    final color = area['color'] as Color;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() {
        _selArea = area['name'] as String;
        _tabCtrl.animateTo(0);
      }),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.6)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Stack(children: [
          Positioned(right: -10, bottom: -8,
            child: Text(area['emoji'] as String,
                style: const TextStyle(fontSize: 55))),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              Text(area['name'] as String,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 14, fontWeight: FontWeight.w900)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${area['count']} ${S.places}',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      ),
    ));
  }

  Widget _mapIllustration() {
    // Simple stylized dot-map of Egypt coastline
    final spots = [
      {'x': 0.55, 'y': 0.55, 'label': S.ainSokhna, 'color': const Color(0xFF0288D1)},
      {'x': 0.30, 'y': 0.35, 'label': S.northCoast,'color': const Color(0xFF1976D2)},
      {'x': 0.65, 'y': 0.72, 'label': S.rasSedr,   'color': const Color(0xFF00897B)},
      {'x': 0.75, 'y': 0.62, 'label': S.gouna,   'color': const Color(0xFFE65100)},
      {'x': 0.80, 'y': 0.68, 'label': S.hurghada,   'color': const Color(0xFF00695C)},
      {'x': 0.90, 'y': 0.85, 'label': S.sharm,      'color': const Color(0xFF6A1B9A)},
    ];
    return SizedBox(
      height: 220,
      child: Stack(children: [
        // Background
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // Egypt outline hint
        Center(child: Text('🗺️',
            style: TextStyle(fontSize: 120,
                color: Colors.grey.withValues(alpha: 0.15)))),

        // Location dots
        ...spots.map((s) {
          final c = s['color'] as Color;
          return Positioned(
            left: (s['x'] as double) *
                (MediaQuery.of(context).size.width - 80),
            top: (s['y'] as double) * 180,
            child: GestureDetector(
              onTap: () => setState(() {
                _selArea = s['label'] as String;
                _tabCtrl.animateTo(0);
              }),
              child: Column(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: c, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5),
                        blurRadius: 8)],
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: Colors.white, size: 18),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(s['label'] as String,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 8, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          );
        }),
      ]),
    );
  }

  // ── TAB 3: Trending ───────────────────────────────────────
  Widget _buildTrendingTab() {
    final list = _trending;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (_, i) => _trendingCard(list[i], i + 1),
    );
  }

  Widget _trendingCard(PropertyApi p, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        // Rank badge
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: rank <= 3 ? _kOrange : context.kBorder,
            shape: BoxShape.circle,
          ),
          child: Center(child: Text('$rank',
              style: TextStyle(
                  color: rank <= 3 ? Colors.white : context.kSub,
                  fontSize: 12, fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 10),
        // Image
        Container(
          width: 68, height: 68,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [p.areaColor, p.areaColor.withValues(alpha: 0.6)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text(p.categoryEmoji,
              style: const TextStyle(fontSize: 30))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(p.name, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: context.kText),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Row(children: [
            Icon(Icons.location_on_rounded, size: 11, color: p.areaColor),
            const SizedBox(width: 2),
            Text(p.area,
                style: TextStyle(fontSize: 10, color: p.areaColor,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            const Icon(Icons.star_rounded,
                color: Color(0xFFFFC107), size: 13),
            Text(' ${p.rating}  ',
                style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: context.kText)),
            Text('(${p.reviewCount} ${S.reviews})',
                style: TextStyle(fontSize: 10, color: context.kSub)),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${S.egp} ${_comma(p.pricePerNight.toInt())}',
              style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w900, color: context.kText)),
          Text('/${S.night}', style: TextStyle(fontSize: 10, color: context.kSub)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => PropertyDetailsPage(
                  propertyApi: p,
                ))),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _kOcean,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(S.book,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── TAB 4: Today's Deals ──────────────────────────────────
  Widget _buildTodayTab() {
    final deals = _todayDeals;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFFF6D00), Color(0xFFFF3500)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: _kOrange.withValues(alpha: 0.4),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            const Text('⚡', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(S.todayFeatured,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.w900)),
              Text(S.handPicked,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(S.dealsCount(deals.length),
                  style: const TextStyle(color: Colors.white,
                      fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        ...deals.map((p) => _propListCard(p)),
      ],
    );
  }

  // ── Property Cards ────────────────────────────────────────
  Widget _propListCard(PropertyApi p) {
    final fav = _favs.contains(p.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.kCard, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Image
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SizedBox(
            height: 140,
            child: Stack(fit: StackFit.expand, children: [
              // ── صورة حقيقية ──────────────────────
              p.firstImage.isNotEmpty
                ? Image.network(p.firstImage, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [p.areaColor, p.areaColor.withValues(alpha: 0.55)])),
                      child: Center(child: Text(p.categoryEmoji,
                          style: const TextStyle(fontSize: 60)))))
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [p.areaColor, p.areaColor.withValues(alpha: 0.55)])),
                    child: Center(child: Text(p.categoryEmoji,
                        style: const TextStyle(fontSize: 60)))),
              // Fav
              PositionedDirectional(top: 10, end: 10,
                child: GestureDetector(
                  onTap: () => setState(() =>
                      fav ? _favs.remove(p.name) : _favs.add(p.name)),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      fav ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 17,
                      color: fav ? Colors.red : Colors.grey),
                  ),
                )),
              // Category
              PositionedDirectional(top: 10, start: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(S.catName(p.category),
                      style: const TextStyle(color: Colors.white,
                          fontSize: 10, fontWeight: FontWeight.w700)),
                )),
              // Rating
              PositionedDirectional(bottom: 8, start: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFFFC107), size: 12),
                    Text(' ${p.rating} (${p.reviewCount})',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                )),
              if (p.instantBooking)
                PositionedDirectional(bottom: 8, end: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(children: [
                      const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 11),
                      Text(S.instantBook,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 9, fontWeight: FontWeight.w800)),
                    ]),
                  )),
            ]),
          ),
        ),
        // Info
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(p.name, style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: context.kText),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.location_on_rounded, size: 12, color: p.areaColor),
                const SizedBox(width: 2),
                Text(p.area,
                    style: TextStyle(fontSize: 11, color: p.areaColor,
                        fontWeight: FontWeight.w600)),
              ]),
              if (p.instantBooking) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.circle, size: 7, color: _kGreen),
                  const SizedBox(width: 3),
                  Text(S.ownerOnline,
                      style: const TextStyle(fontSize: 9, color: _kGreen,
                          fontWeight: FontWeight.w700)),
                ]),
              ],
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              RichText(text: TextSpan(children: [
                TextSpan(text: '${S.egp} ${_comma(p.pricePerNight.toInt())}',
                    style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w900, color: context.kText)),
                TextSpan(text: '/${S.night}',
                    style: TextStyle(fontSize: 10, color: context.kSub)),
              ])),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => PropertyDetailsPage(
                      propertyApi: p,
                    ))),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1976D2), Color(0xFF0D47A1)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: _kOcean.withValues(alpha: 0.4),
                        blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Text(S.bookProperty,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w900)),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _propGridCard(PropertyApi p) {
    final fav = _favs.contains(p.name);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PropertyDetailsPage(
            propertyApi: p,
          ))),
      child: Container(
        decoration: BoxDecoration(
          color: context.kCard, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: SizedBox(
              height: 100,
              child: Stack(fit: StackFit.expand, children: [
                // ── صورة حقيقية ──────────────────────
                p.firstImage.isNotEmpty
                  ? Image.network(p.firstImage, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [p.areaColor, p.areaColor.withValues(alpha: 0.55)])),
                        child: Center(child: Text(p.categoryEmoji,
                            style: const TextStyle(fontSize: 42)))))
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [p.areaColor, p.areaColor.withValues(alpha: 0.55)])),
                      child: Center(child: Text(p.categoryEmoji,
                          style: const TextStyle(fontSize: 42)))),
                PositionedDirectional(top: 6, end: 6,
                  child: GestureDetector(
                    onTap: () => setState(() =>
                        fav ? _favs.remove(p.name) : _favs.add(p.name)),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle),
                      child: Icon(
                        fav ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 14,
                        color: fav ? Colors.red : Colors.grey)),
                  )),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(p.name, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: context.kText),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(p.area, style: TextStyle(
                  fontSize: 9, color: p.areaColor, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                Text('${S.egp} ${_comma(p.pricePerNight.toInt())}',
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w900, color: context.kText)),
                Row(children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFFC107), size: 11),
                  Text('${p.rating}',
                      style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w700, color: context.kText)),
                ]),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState() {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: _kOcean.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.home_work_outlined,
            size: 40, color: _kOcean),
      ),
      const SizedBox(height: 16),
      Text(S.noResults,
          style: TextStyle(fontSize: 17,
              fontWeight: FontWeight.w900, color: context.kText)),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(S.noResultsSub,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.kSub)),
      ),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: _resetFilters,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _kOcean, borderRadius: BorderRadius.circular(12)),
          child: Text(S.resetFilters,
              style: const TextStyle(color: Colors.white,
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ),
    ]));
  }
}
