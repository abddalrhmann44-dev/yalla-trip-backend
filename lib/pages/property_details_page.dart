// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Property Details Page
//  Full details, gallery, reviews, book CTA → BookingFlowPage
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../models/property_model.dart';
import 'booking_flow_page.dart';

const _kOcean  = Color(0xFF1565C0);
const _kOrange = Color(0xFFFF6D00);
const _kSand   = Color(0xFFF5F3EE);
const _kText   = Color(0xFF0D1B2A);
const _kSub    = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);

class PropertyDetailsPage extends StatefulWidget {
  final PropertyModel property;
  const PropertyDetailsPage({super.key, required this.property});

  @override
  State<PropertyDetailsPage> createState() => _PropertyDetailsPageState();
}

class _PropertyDetailsPageState extends State<PropertyDetailsPage> {
  int  _imgIndex   = 0;
  bool _isFav      = false;
  bool _descExpand = false;
  final PageController _imgCtrl = PageController();

  PropertyModel get p => widget.property;

  @override
  void dispose() { _imgCtrl.dispose(); super.dispose(); }

  // ═══════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSand,
      body: Stack(children: [

        CustomScrollView(slivers: [

          // ── Image gallery SliverAppBar ────────────
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: _kOcean,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () => setState(() => _isFav = !_isFav),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _isFav ? Colors.red : Colors.white, size: 20),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Container(
                  margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(children: [
                // Images PageView
                p.images.isEmpty
                    ? Container(color: const Color(0xFF1565C0),
                        child: const Icon(Icons.villa_rounded,
                            color: Colors.white54, size: 80))
                    : PageView.builder(
                        controller: _imgCtrl,
                        onPageChanged: (i) => setState(() => _imgIndex = i),
                        itemCount: p.images.length,
                        itemBuilder: (_, i) => Image.network(
                          p.images[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF1565C0),
                            child: const Icon(Icons.villa_rounded,
                                color: Colors.white54, size: 80)),
                        ),
                      ),
                // Image counter
                if (p.images.length > 1)
                  Positioned(
                    bottom: 16, right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_imgIndex + 1} / ${p.images.length}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    ),
                  ),
                // Dots
                if (p.images.length > 1)
                  Positioned(
                    bottom: 14, left: 0, right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(p.images.length, (i) =>
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _imgIndex == i ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _imgIndex == i
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Gradient
                Positioned.fill(child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.transparent,
                               Color(0x33000000)],
                      stops: [0.0, 0.6, 1.0],
                    ),
                  ),
                )),
              ]),
            ),
          ),

          // ── Content ────────────────────────────────
          SliverToBoxAdapter(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header card ──────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category + Area badges
                    Row(children: [
                      _badge(p.categoryEmoji, p.category,
                          p.areaColor.withValues(alpha: 0.12), p.areaColor),
                      const SizedBox(width: 8),
                      _badge('📍', p.area,
                          const Color(0xFFF3F4F6), _kSub),
                      if (p.featured) ...[
                        const SizedBox(width: 8),
                        _badge('⭐', 'مميز',
                            const Color(0xFFFFF8E1), const Color(0xFFF59E0B)),
                      ],
                    ]),
                    const SizedBox(height: 12),
                    // Property name
                    Text(p.name,
                        style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900,
                          color: _kText, height: 1.2,
                        )),
                    const SizedBox(height: 8),
                    // Location
                    Row(children: [
                      const Icon(Icons.location_on_rounded,
                          size: 15, color: _kOrange),
                      const SizedBox(width: 4),
                      Expanded(child: Text(
                        p.address.isNotEmpty ? p.address : p.location,
                        style: const TextStyle(
                            fontSize: 13, color: _kSub),
                      )),
                    ]),
                    const SizedBox(height: 14),
                    // Rating + reviews
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(p.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800,
                                  color: Color(0xFF92400E))),
                          Text(' (${p.reviewCount} تقييم)',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF92400E))),
                        ]),
                      ),
                      const SizedBox(width: 10),
                      if (p.instant)
                        _infoBadge(Icons.bolt_rounded,
                            'حجز فوري', const Color(0xFF22C55E)),
                      if (!p.instant)
                        _infoBadge(Icons.schedule_rounded,
                            'يحتاج موافقة', _kSub),
                    ]),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Quick stats ──────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 20),
                child: Row(children: [
                  _stat('🛏️', '${p.bedrooms}', 'غرف'),
                  _divV(),
                  _stat('🛁', '${p.bathrooms}', 'حمامات'),
                  _divV(),
                  _stat('👥', '${p.guests}', 'ضيوف'),
                  _divV(),
                  _stat('🌙', '${p.minNights}+', 'ليالي'),
                ]),
              ),

              const SizedBox(height: 8),

              // ── Description ──────────────────────────
              if (p.description.isNotEmpty)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('عن العقار',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w900, color: _kText)),
                      const SizedBox(height: 10),
                      AnimatedCrossFade(
                        firstChild: Text(p.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, color: _kSub, height: 1.6)),
                        secondChild: Text(p.description,
                            style: const TextStyle(
                                fontSize: 14, color: _kSub, height: 1.6)),
                        crossFadeState: _descExpand
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 250),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _descExpand = !_descExpand),
                        child: Text(
                            _descExpand ? 'عرض أقل ↑' : 'قرأة المزيد ↓',
                            style: const TextStyle(
                                fontSize: 13, color: _kOcean,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),

              if (p.description.isNotEmpty) const SizedBox(height: 8),

              // ── Amenities ────────────────────────────
              if (p.amenities.isNotEmpty)
                _section('✨ المرافق والخدمات', _chipGrid(p.amenities)),

              // ── Facilities ───────────────────────────
              if (p.facilities.isNotEmpty)
                _section('🏊 المنشآت', _chipGrid(p.facilities)),

              // ── Nearby ───────────────────────────────
              if (p.nearby.isNotEmpty)
                _section('📍 المناطق القريبة', _chipGrid(p.nearby)),

              // ── Pricing breakdown ────────────────────
              _section('💰 التسعير', _pricingCard()),

              // ── Check-in rules ───────────────────────
              _section('🕐 مواعيد الوصول', _checkInCard()),

              // ── Reviews placeholder ──────────────────
              _section('⭐ التقييمات', _reviewsSection()),

              // ── Owner info ───────────────────────────
              _section('🏠 المضيف', _ownerCard()),

              const SizedBox(height: 120),
            ],
          )),
        ]),

        // ── Bottom CTA bar ──────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
                20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20, offset: const Offset(0, -4),
              )],
            ),
            child: Row(children: [
              // Price
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p.price.toInt()} جنيه',
                    style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900,
                      color: _kOcean,
                    )),
                const Text('/ الليلة',
                    style: TextStyle(fontSize: 12, color: _kSub)),
              ]),
              const Spacer(),
              // Book button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: p.available ? _startBooking : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.available ? _kOcean : Colors.grey,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    p.available ? 'احجز الآن 🏖️' : 'غير متاح',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  void _startBooking() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BookingFlowPage(property: p),
    ));
  }

  // ── Helpers ─────────────────────────────────────────────────

  Widget _section(String title, Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    color: Colors.white,
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w900, color: _kText)),
      const SizedBox(height: 14),
      child,
    ]),
  );

  Widget _badge(String emoji, String label, Color bg, Color fg) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text('$emoji $label',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: fg)),
    );

  Widget _infoBadge(IconData icon, String label, Color color) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
    );

  Widget _stat(String emoji, String val, String label) =>
    Expanded(child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 4),
      Text(val, style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w900, color: _kText)),
      Text(label, style: const TextStyle(fontSize: 11, color: _kSub)),
    ]));

  Widget _divV() => Container(
    height: 40, width: 1, color: _kBorder);

  Widget _chipGrid(List<String> items) => Wrap(
    spacing: 8, runSpacing: 8,
    children: items.map((item) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _kOcean.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _kOcean.withValues(alpha: 0.2)),
      ),
      child: Text(item, style: const TextStyle(
          fontSize: 12, color: _kOcean, fontWeight: FontWeight.w600)),
    )).toList(),
  );

  Widget _pricingCard() => Column(children: [
    _priceRow('السعر الأساسي / ليلة',
        '${p.price.toInt()} جنيه'),
    if (p.weekendPrice > 0)
      _priceRow('سعر نهاية الأسبوع',
          '${p.weekendPrice.toInt()} جنيه'),
    if (p.cleaningFee > 0)
      _priceRow('رسوم التنظيف',
          '${p.cleaningFee.toInt()} جنيه'),
    const Divider(color: _kBorder, height: 24),
    _priceRow('الحد الأدنى للإقامة',
        '${p.minNights} ليالي', bold: true),
    if (p.maxNights > 0)
      _priceRow('الحد الأقصى للإقامة',
          '${p.maxNights} ليالي'),
  ]);

  Widget _priceRow(String label, String val, {bool bold = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(label,
            style: TextStyle(fontSize: 13,
                color: bold ? _kText : _kSub,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
        Text(val, style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: bold ? _kOcean : _kText)),
      ]),
    );

  Widget _checkInCard() => Row(children: [
    Expanded(child: _timeCard('تسجيل الوصول',
        p.checkinTime.isNotEmpty ? p.checkinTime : '14:00',
        Icons.login_rounded, const Color(0xFF22C55E))),
    const SizedBox(width: 12),
    Expanded(child: _timeCard('تسجيل المغادرة',
        p.checkoutTime.isNotEmpty ? p.checkoutTime : '12:00',
        Icons.logout_rounded, _kOrange)),
  ]);

  Widget _timeCard(String label, String time, IconData icon, Color color) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(time, style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(
            fontSize: 11, color: _kSub)),
      ]),
    );

  Widget _reviewsSection() {
    if (p.reviewCount == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('لا يوجد تقييمات بعد',
              style: TextStyle(color: _kSub, fontSize: 13)),
        ),
      );
    }
    return Column(children: [
      Row(children: [
        Text(p.rating.toStringAsFixed(1),
            style: const TextStyle(
                fontSize: 48, fontWeight: FontWeight.w900, color: _kText)),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: List.generate(5, (i) => Icon(
            i < p.rating.round()
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            color: const Color(0xFFF59E0B), size: 20))),
          Text('${p.reviewCount} تقييم',
              style: const TextStyle(fontSize: 13, color: _kSub)),
        ]),
      ]),
    ]);
  }

  Widget _ownerCard() => Row(children: [
    Container(
      width: 54, height: 54,
      decoration: BoxDecoration(
        color: _kOcean.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(child: Text(
        p.ownerName.isNotEmpty ? p.ownerName[0].toUpperCase() : 'م',
        style: const TextStyle(fontSize: 22,
            fontWeight: FontWeight.w900, color: _kOcean),
      )),
    ),
    const SizedBox(width: 14),
    Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(p.ownerName.isNotEmpty ? p.ownerName : 'المالك',
            style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.w800, color: _kText)),
        const Text('مضيف في Yalla Trip',
            style: TextStyle(fontSize: 12, color: _kSub)),
      ],
    )),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        border: Border.all(color: _kOcean),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('تواصل',
          style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w700, color: _kOcean)),
    ),
  ]);
}
