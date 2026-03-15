// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Area Results Page
//  يفتح لما تضغط على Hero Card أو Destination
//  عرض احترافي: قائمتين جنب بعض حسب النوع
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'property_details_page.dart';
import '../models/property_model.dart';

// ── Colors ──────────────────────────────────────────────────────
const _kBlue = Color(0xFF1565C0);
const _kText = Color(0xFF0D1B2A);
const _kSub = Color(0xFF6B7280);

// ── Property model ───────────────────────────────────────────────
class _Prop {
  final String id, name, area, category, location, ownerId, ownerName;
  final double rating;
  final int price, reviewCount;
  final List<String> images;
  final bool instant, available;

  _Prop.fromMap(String docId, Map<String, dynamic> d)
      : id = docId,
        name = d['name'] ?? '',
        area = d['area'] ?? '',
        category = d['category'] ?? '',
        location = d['location'] ?? '',
        ownerId = d['ownerId'] ?? '',
        ownerName = d['ownerName'] ?? '',
        rating = (d['rating'] ?? 0).toDouble(),
        price = (d['price'] ?? 0).toInt(),
        reviewCount = (d['reviewCount'] ?? 0).toInt(),
        images = List<String>.from(d['images'] ?? []),
        instant = d['instant'] ?? false,
        available = d['available'] ?? true;

  String get firstImage => images.isNotEmpty ? images.first : '';
}

// ── Category config ──────────────────────────────────────────────
const _kCats = [
  {'key': 'الكل', 'icon': '🏠', 'color': _kBlue},
  {'key': 'شاليه', 'icon': '🏡', 'color': Color(0xFF0288D1)},
  {'key': 'فندق', 'icon': '🏨', 'color': Color(0xFF7B1FA2)},
  {'key': 'فيلا', 'icon': '🏖️', 'color': Color(0xFFE65100)},
  {'key': 'منتجع', 'icon': '🌺', 'color': Color(0xFF00695C)},
  {'key': 'أكوا بارك', 'icon': '🎢', 'color': Color(0xFFD32F2F)},
  {'key': 'بيت شاطئ', 'icon': '🏄', 'color': Color(0xFF0097A7)},
];

// ── Area colors ──────────────────────────────────────────────────
Color _areaColor(String area) {
  switch (area) {
    case 'عين السخنة':
      return const Color(0xFF0288D1);
    case 'الساحل الشمالي':
      return const Color(0xFF1976D2);
    case 'الجونة':
      return const Color(0xFFE65100);
    case 'الغردقة':
      return const Color(0xFF00695C);
    case 'شرم الشيخ':
      return const Color(0xFF6A1B9A);
    case 'رأس سدر':
      return const Color(0xFF00897B);
    default:
      return _kBlue;
  }
}

String _areaEmoji(String area) {
  switch (area) {
    case 'عين السخنة':
      return '🌊';
    case 'الساحل الشمالي':
      return '🏖️';
    case 'الجونة':
      return '⛵';
    case 'الغردقة':
      return '🐠';
    case 'شرم الشيخ':
      return '🦈';
    case 'رأس سدر':
      return '🌬️';
    default:
      return '📍';
  }
}

// ════════════════════════════════════════════════════════════════
//  AREA RESULTS PAGE
// ════════════════════════════════════════════════════════════════

class AreaResultsPage extends StatefulWidget {
  final String area; // المنطقة: عين السخنة، شرم الشيخ...
  final String? initialType; // فلتر نوع اختياري
  const AreaResultsPage({super.key, required this.area, this.initialType});
  @override
  State<AreaResultsPage> createState() => _AreaResultsPageState();
}

class _AreaResultsPageState extends State<AreaResultsPage> {
  List<_Prop> _all = [];
  bool _loading = true;
  String _selCat = 'الكل';

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) _selCat = widget.initialType!;
    _load();
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
        _all = snap.docs.map((d) => _Prop.fromMap(d.id, d.data())).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Properties filtered by selected category
  List<_Prop> get _filtered => _selCat == 'الكل'
      ? _all
      : _all.where((p) => p.category == _selCat).toList();

  // Group by category for dual-column display
  Map<String, List<_Prop>> get _grouped {
    final map = <String, List<_Prop>>{};
    for (final p in _all) {
      map.putIfAbsent(p.category, () => []).add(p);
    }
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
      backgroundColor: const Color(0xFFF5F7FF),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildAppBar()],
        body: _loading
            ? _buildShimmer()
            : _all.isEmpty
                ? _buildEmpty()
                : _buildBody(),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: _color,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 16),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/destinations/${widget.area.replaceAll(' ', '_').toLowerCase()}.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: _color),
            ),
          ),
          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _color.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          // Area info
          Positioned(
            bottom: 16,
            left: 20,
            right: 20,
            child: Row(children: [
              Text(_areaEmoji(widget.area),
                  style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.area,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                  Text('${_all.length} عقار متاح',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13)),
                ],
              )),
            ]),
          ),
        ]),
      ),

      // Category filter chips
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          height: 52,
          color: Colors.white,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _kCats.length,
            itemBuilder: (_, i) {
              final cat = _kCats[i];
              final key = cat['key'] as String;
              final sel = _selCat == key;
              final col = cat['color'] as Color;
              return GestureDetector(
                onTap: () => setState(() => _selCat = key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? col : const Color(0xFFF5F7FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? col : Colors.transparent),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(cat['icon'] as String,
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 5),
                    Text(key,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : _kSub)),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────
  Widget _buildBody() {
    // لو في فلتر محدد — عرض عادي
    if (_selCat != 'الكل') {
      final props = _filtered;
      return props.isEmpty ? _buildEmpty() : _buildTwoColumnList(props);
    }

    // لو "الكل" — عرض مجموعات حسب النوع (الشكل الاحترافي)
    final grouped = _grouped;
    if (grouped.isEmpty) return _buildEmpty();

    return RefreshIndicator(
      onRefresh: _load,
      color: _color,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        physics: const BouncingScrollPhysics(),
        children: grouped.entries.map((entry) {
          return _buildCategorySection(entry.key, entry.value);
        }).toList(),
      ),
    );
  }

  // ── Section لكل نوع ───────────────────────────────────────────
  Widget _buildCategorySection(String category, List<_Prop> props) {
    final catConfig = _kCats.firstWhere(
      (c) => c['key'] == category,
      orElse: () => {'key': category, 'icon': '🏠', 'color': _kBlue},
    );
    final color = catConfig['color'] as Color;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Section header
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
                child: Text(catConfig['icon'] as String,
                    style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _kText,
                      letterSpacing: -0.3)),
              Text('${props.length} عقار',
                  style: TextStyle(
                      fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            ],
          )),
          // See all button
          GestureDetector(
            onTap: () => setState(() => _selCat = category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('عرض الكل',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ),
        ]),
      ),

      // Two-column horizontal scroll
      SizedBox(
        height: 230,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          itemCount: props.length,
          itemBuilder: (_, i) => _buildHorizontalCard(props[i], color),
        ),
      ),

      const SizedBox(height: 8),
    ]);
  }

  // ── Two Column Grid للـ filtered view ─────────────────────────
  Widget _buildTwoColumnList(List<_Prop> props) {
    return RefreshIndicator(
      onRefresh: _load,
      color: _color,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: props.length,
        itemBuilder: (_, i) => _buildGridCard(props[i]),
      ),
    );
  }

  // ── Horizontal scroll card ─────────────────────────────────────
  Widget _buildHorizontalCard(_Prop p, Color accentColor) {
    return GestureDetector(
      onTap: () => _openDetails(p),
      child: Container(
        width: 175,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: SizedBox(
              height: 130,
              width: double.infinity,
              child: p.firstImage.isNotEmpty
                  ? Image.network(p.firstImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgFallback(accentColor))
                  : _imgFallback(accentColor),
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _kText,
                      height: 1.3)),
              const SizedBox(height: 5),
              Row(children: [
                Icon(Icons.star_rounded,
                    size: 12,
                    color:
                        p.rating > 0 ? const Color(0xFFFFC107) : Colors.grey),
                const SizedBox(width: 2),
                Text(p.rating > 0 ? p.rating.toStringAsFixed(1) : 'جديد',
                    style: TextStyle(
                        fontSize: 10,
                        color: p.rating > 0 ? _kText : _kSub,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                if (p.instant)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('فوري',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4CAF50))),
                  ),
              ]),
              const SizedBox(height: 6),
              RichText(
                  text: TextSpan(
                children: [
                  TextSpan(
                    text: '${p.price} ',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: accentColor),
                  ),
                  const TextSpan(
                    text: 'جنيه/ليلة',
                    style: TextStyle(
                        fontSize: 10,
                        color: _kSub,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Grid card للـ category filter ─────────────────────────────
  Widget _buildGridCard(_Prop p) {
    final color = _areaColor(p.area);
    return GestureDetector(
      onTap: () => _openDetails(p),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image with badge
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(children: [
                Positioned.fill(
                  child: p.firstImage.isNotEmpty
                      ? Image.network(p.firstImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imgFallback(color))
                      : _imgFallback(color),
                ),
                if (p.instant)
                  Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('حجز فوري',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      )),
                Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                      child: const SizedBox(height: 40),
                    )),
              ]),
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _kText)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.star_rounded,
                    size: 11, color: Color(0xFFFFC107)),
                const SizedBox(width: 2),
                Text(p.rating > 0 ? p.rating.toStringAsFixed(1) : 'جديد',
                    style: const TextStyle(
                        fontSize: 10,
                        color: _kSub,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 5),
              Text('${p.price} جنيه/ليلة',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w900, color: color)),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Fallback image ─────────────────────────────────────────────
  Widget _imgFallback(Color color) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: 0.6)],
          ),
        ),
        child: Center(
            child: Text(_areaEmoji(widget.area),
                style: const TextStyle(fontSize: 36))),
      );

  // ── Open property details ──────────────────────────────────────
  void _openDetails(_Prop p) {
    final model = PropertyModel(
      id: p.id,
      name: p.name,
      area: p.area,
      location: p.location,
      address: '',
      description: '',
      category: p.category,
      ownerId: p.ownerId,
      ownerName: p.ownerName,
      price: p.price,
      weekendPrice: p.price,
      cleaningFee: 0,
      rating: p.rating,
      reviewCount: p.reviewCount,
      bedrooms: 0,
      beds: 0,
      bathrooms: 0,
      maxGuests: 0,
      images: p.images,
      amenities: const [],
      facilities: const [],
      nearby: const [],
      instant: p.instant,
      online: false,
      featured: false,
      available: p.available,
      autoConfirm: false,
      requireId: false,
      minNights: 1,
      maxNights: 30,
      bookingMode: 'instant',
      currency: 'EGP',
      checkinTime: '14:00',
      checkoutTime: '12:00',
      createdAt: DateTime.now(),
    );
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PropertyDetailsPage(property: model),
        ));
  }

  // ── Empty state ────────────────────────────────────────────────
  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_areaEmoji(widget.area), style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text('لا توجد عقارات في ${widget.area}',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
          const SizedBox(height: 8),
          const Text('جاري إضافة عقارات جديدة قريباً',
              style: TextStyle(fontSize: 13, color: _kSub)),
        ]),
      );

  // ── Shimmer loading ────────────────────────────────────────────
  Widget _buildShimmer() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: List.generate(
          3,
          (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 20,
                      width: 140,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      )),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 3,
                      itemBuilder: (_, __) => Container(
                        width: 175,
                        height: 200,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              )),
    );
  }
}
