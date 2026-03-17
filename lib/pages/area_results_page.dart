// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Area Results Page  v5
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../main.dart' show appSettings;
import '../utils/app_strings.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'property_details_page.dart';
import '../models/property_model.dart';

const _kBg   = Color(0xFFF5F7FA);
const _kText = Color(0xFF0D1B2A);
const _kSub  = Color(0xFF6B7280);
const _kCard = Colors.white;

Color _areaColor(String area) {
  switch (area) {
    case 'عين السخنة':     return const Color(0xFF0288D1);
    case 'الساحل الشمالي': return const Color(0xFF1976D2);
    case 'الجونة':         return const Color(0xFFE65100);
    case 'الغردقة':        return const Color(0xFF00695C);
    case 'شرم الشيخ':      return const Color(0xFF6A1B9A);
    case 'رأس سدر':        return const Color(0xFF00897B);
    default:               return const Color(0xFF1565C0);
  }
}

IconData _areaIcon(String area) {
  switch (area) {
    case 'عين السخنة':     return Icons.waves_rounded;
    case 'الساحل الشمالي': return Icons.beach_access_rounded;
    case 'الجونة':         return Icons.sailing_rounded;
    case 'الغردقة':        return Icons.water_rounded;
    case 'شرم الشيخ':      return Icons.scuba_diving_rounded;
    case 'رأس سدر':        return Icons.air_rounded;
    default:               return Icons.location_on_rounded;
  }
}

IconData _catIcon(String key) {
  switch (key) {
    case 'الكل':      return Icons.grid_view_rounded;
    case 'شاليه':     return Icons.cabin_rounded;
    case 'فندق':      return Icons.hotel_rounded;
    case 'فيلا':      return Icons.villa_rounded;
    case 'منتجع':     return Icons.spa_rounded;
    case 'أكوا بارك': return Icons.pool_rounded;
    case 'بيت شاطئ':  return Icons.beach_access_rounded;
    default:          return Icons.home_rounded;
  }
}

String _areaImagePath(String area) =>
    'assets/images/destinations/${area.replaceAll(' ', '_').toLowerCase()}.jpg';

const _kCatKeys = ['الكل', 'شاليه', 'فندق', 'فيلا', 'منتجع', 'أكوا بارك', 'بيت شاطئ'];
const _kCatColors = {
  'الكل':       Color(0xFF1565C0),
  'شاليه':      Color(0xFF0288D1),
  'فندق':       Color(0xFF7B1FA2),
  'فيلا':       Color(0xFFE65100),
  'منتجع':      Color(0xFF00695C),
  'أكوا بارك':  Color(0xFFD32F2F),
  'بيت شاطئ':   Color(0xFF0097A7),
};

class _Prop {
  final String id, name, area, category, location, ownerId, ownerName;
  final double rating;
  final int    price, reviewCount;
  final List<String> images;
  final bool   instant, available;

  _Prop.fromMap(String docId, Map<String, dynamic> d)
      : id          = docId,
        name        = d['name']         ?? '',
        area        = d['area']         ?? '',
        category    = d['category']     ?? '',
        location    = d['location']     ?? '',
        ownerId     = d['ownerId']      ?? '',
        ownerName   = d['ownerName']    ?? '',
        rating      = (d['rating']      ?? 0).toDouble(),
        price       = (d['price']       ?? 0).toInt(),
        reviewCount = (d['reviewCount'] ?? 0).toInt(),
        images      = List<String>.from(d['images'] ?? []),
        instant     = d['instant']      ?? false,
        available   = d['available']    ?? true;

  String get firstImage => images.isNotEmpty ? images.first : '';
}

class AreaResultsPage extends StatefulWidget {
  final String  area;
  final String? initialType;
  const AreaResultsPage({super.key, required this.area, this.initialType});
  @override State<AreaResultsPage> createState() => _AreaResultsPageState();
}

class _AreaResultsPageState extends State<AreaResultsPage> {
  List<_Prop> _all = [];
  bool   _loading  = true;
  String _selKey   = 'الكل';

  void _onLangChange() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
    if (widget.initialType != null) _selKey = _toArabicKey(widget.initialType!);
    _load();
  }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange);
    super.dispose();
  }

  String _toArabicKey(String s) {
    const map = {
      'Chalets':'شاليه','Chalet':'شاليه',
      'Hotels':'فندق','Hotel':'فندق',
      'Villas':'فيلا','Villa':'فيلا',
      'Resorts':'منتجع','Resort':'منتجع',
      'Aqua Park':'أكوا بارك',
      'Beach House':'بيت شاطئ',
      'All':'الكل',
    };
    return map[s] ?? s;
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('properties')
          .where('area', isEqualTo: widget.area)
          .where('available', isEqualTo: true)
          .get();
      if (!mounted) return;
      setState(() {
        _all     = snap.docs.map((d) => _Prop.fromMap(d.id, d.data())).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Prop> get _filtered =>
      _selKey == 'الكل' ? _all : _all.where((p) => p.category == _selKey).toList();

  Map<String, List<_Prop>> get _grouped {
    final map = <String, List<_Prop>>{};
    for (final p in _all) map.putIfAbsent(p.category, () => []).add(p);
    return map;
  }

  Color get _color => _areaColor(widget.area);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    return Scaffold(
      backgroundColor: _kBg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildAppBar()],
        body: _loading ? _buildShimmer()
            : _all.isEmpty ? _buildEmpty()
            : _buildBody(),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 230,
      pinned: true,
      backgroundColor: _color,
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      // ✅ زرار الرجوع فقط — مفيش اسم هنا
      title: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 17),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        // ✅ مفيش title هنا — الاسم في الصورة فقط فمفيش تكرار
        background: Stack(children: [
          Positioned.fill(
            child: Image.asset(
              _areaImagePath(widget.area),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: _color),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
          ),
          // ✅ الاسم هنا بس — مرة واحدة
          Positioned(
            bottom: 18, left: 20, right: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: Icon(_areaIcon(widget.area), color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(S.areaName(widget.area),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5, height: 1.1)),
                      const SizedBox(height: 3),
                      Text(
                        _loading ? S.loading
                            : '${_all.length} ${appSettings.arabic ? 'عقار متاح' : 'properties'}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(54),
        child: Container(
          height: 54,
          color: Colors.white,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            itemCount: _kCatKeys.length,
            itemBuilder: (_, i) {
              final key   = _kCatKeys[i];
              final sel   = _selKey == key;
              final col   = _kCatColors[key] ?? _color;
              final icon  = _catIcon(key);
              final label = key == 'الكل' ? S.all : S.catName(key);
              return GestureDetector(
                onTap: () => setState(() => _selKey = key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: sel ? col : const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? col : const Color(0xFFE0E7FF), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13, color: sel ? Colors.white : _kSub),
                      const SizedBox(width: 5),
                      Text(label,
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : _kSub)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_selKey != 'الكل') {
      final props = _filtered;
      return props.isEmpty ? _buildEmpty() : _buildGrid(props);
    }
    final grouped = _grouped;
    if (grouped.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      onRefresh: _load, color: _color,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        physics: const BouncingScrollPhysics(),
        children: grouped.entries.map((e) => _buildSection(e.key, e.value)).toList(),
      ),
    );
  }

  Widget _buildSection(String catKey, List<_Prop> props) {
    final col         = _kCatColors[catKey] ?? _color;
    final icon        = _catIcon(catKey);
    final displayName = catKey == 'الكل' ? S.all : S.catName(catKey);
    final countLabel  = appSettings.arabic
        ? '${props.length} عقار' : '${props.length} properties';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: col, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900,
                          color: _kText, letterSpacing: -0.3)),
                  Text(countLabel,
                      style: TextStyle(fontSize: 12, color: col,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _selKey = catKey),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: col.withValues(alpha: 0.3)),
                ),
                child: Text(S.viewAll,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: col)),
              ),
            ),
          ]),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: props.length,
            itemBuilder: (_, i) => _buildHCard(props[i], col),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildHCard(_Prop p, Color col) {
    final newLabel  = appSettings.arabic ? 'جديد' : 'New';
    final perNight  = appSettings.arabic ? 'جنيه/ليلة' : 'EGP/night';
    final fastLabel = appSettings.arabic ? 'فوري' : 'Instant';
    return GestureDetector(
      onTap: () => _open(p),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(
              color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 140, width: double.infinity,
                child: Stack(children: [
                  Positioned.fill(
                    child: p.firstImage.isNotEmpty
                        ? Image.network(p.firstImage, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imgFallback(col))
                        : _imgFallback(col),
                  ),
                  if (p.instant)
                    Positioned(top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(fastLabel,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 9, fontWeight: FontWeight.w900)),
                      )),
                ]),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                            color: _kText, height: 1.3)),
                    const Spacer(),
                    Row(children: [
                      Icon(Icons.star_rounded, size: 12,
                          color: p.rating > 0 ? const Color(0xFFFFC107) : _kSub),
                      const SizedBox(width: 2),
                      Text(p.rating > 0 ? p.rating.toStringAsFixed(1) : newLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                              color: p.rating > 0 ? _kText : _kSub)),
                    ]),
                    const SizedBox(height: 5),
                    RichText(text: TextSpan(children: [
                      TextSpan(text: '${p.price} ',
                          style: TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w900, color: col)),
                      TextSpan(text: perNight,
                          style: const TextStyle(fontSize: 10,
                              color: _kSub, fontWeight: FontWeight.w500)),
                    ])),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<_Prop> props) {
    return RefreshIndicator(
      onRefresh: _load, color: _color,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12,
          mainAxisSpacing: 12, childAspectRatio: 0.7,
        ),
        itemCount: props.length,
        itemBuilder: (_, i) => _buildGridCard(props[i]),
      ),
    );
  }

  Widget _buildGridCard(_Prop p) {
    final col       = _areaColor(p.area);
    final newLabel  = appSettings.arabic ? 'جديد' : 'New';
    final perNight  = appSettings.arabic ? 'جنيه/ليلة' : 'EGP/night';
    final fastLabel = appSettings.arabic ? 'حجز فوري' : 'Instant';
    return GestureDetector(
      onTap: () => _open(p),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(
              color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Stack(children: [
                  Positioned.fill(
                    child: p.firstImage.isNotEmpty
                        ? Image.network(p.firstImage, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imgFallback(col))
                        : _imgFallback(col),
                  ),
                  if (p.instant)
                    Positioned(top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(fastLabel,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 8, fontWeight: FontWeight.w900)),
                      )),
                ]),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                            color: _kText, height: 1.3)),
                    Row(children: [
                      const Icon(Icons.star_rounded, size: 11, color: Color(0xFFFFC107)),
                      const SizedBox(width: 2),
                      Text(p.rating > 0 ? p.rating.toStringAsFixed(1) : newLabel,
                          style: const TextStyle(fontSize: 9, color: _kSub,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (p.location.isNotEmpty)
                        Flexible(child: Text(p.location, maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9, color: _kSub))),
                    ]),
                    Text('${p.price} $perNight',
                        style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w900, color: col)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgFallback(Color col) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [col.withValues(alpha: 0.8), col.withValues(alpha: 0.45)],
      ),
    ),
    child: Center(
      child: Icon(_areaIcon(widget.area),
          color: Colors.white.withValues(alpha: 0.6), size: 40),
    ),
  );

  void _open(_Prop p) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PropertyDetailsPage(
        property: PropertyModel(
          id: p.id, name: p.name, area: p.area,
          location: p.location, address: '', description: '',
          category: p.category, ownerId: p.ownerId,
          ownerName: p.ownerName, price: p.price,
          weekendPrice: p.price, cleaningFee: 0,
          rating: p.rating, reviewCount: p.reviewCount,
          bedrooms: 0, beds: 0, bathrooms: 0, maxGuests: 0,
          images: p.images, amenities: const [],
          facilities: const [], nearby: const [],
          instant: p.instant, online: false,
          featured: false, available: p.available,
          autoConfirm: false, requireId: false,
          minNights: 1, maxNights: 30,
          bookingMode: 'instant', currency: 'EGP',
          checkinTime: '14:00', checkoutTime: '12:00',
          createdAt: DateTime.now(),
        ),
      ),
    ));
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(_areaIcon(widget.area),
              color: _color.withValues(alpha: 0.55), size: 36),
        ),
        const SizedBox(height: 20),
        Text(
          appSettings.arabic
              ? 'لا توجد عقارات في ${S.areaName(widget.area)}'
              : 'No properties in ${S.areaName(widget.area)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
        const SizedBox(height: 8),
        Text(S.comingSoon, style: const TextStyle(fontSize: 13, color: _kSub)),
      ],
    ),
  );

  Widget _buildShimmer() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: List.generate(2, (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 22, width: 160,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.grey[200], borderRadius: BorderRadius.circular(8))),
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (_, __) => Container(
                width: 180, height: 240,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[200], borderRadius: BorderRadius.circular(20))),
            ),
          ),
          const SizedBox(height: 28),
        ],
      )),
    );
  }
}