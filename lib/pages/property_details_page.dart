// ═══════════════════════════════════════════════════════════════
//  TALAA — Property Details Page
//  Full details, gallery, reviews, book CTA → BookingFlowPage
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../main.dart' show appSettings;
import '../utils/app_strings.dart';
import '../widgets/constants.dart';
import '../models/property_model_api.dart';
import '../services/property_service.dart';
import '../utils/api_client.dart';
import '../utils/error_handler.dart';
import 'booking_flow_page.dart';

const _kOcean  = Color(0xFF1565C0);
const _kOrange = Color(0xFFFF6D00);

class PropertyDetailsPage extends StatefulWidget {
  final int? propertyId;
  final PropertyApi? propertyApi;
  const PropertyDetailsPage({super.key, this.propertyId, this.propertyApi})
      : assert(propertyId != null || propertyApi != null);

  @override
  State<PropertyDetailsPage> createState() => _PropertyDetailsPageState();
}

class _PropertyDetailsPageState extends State<PropertyDetailsPage> {
  int  _imgIndex   = 0;
  bool _isFav      = false;
  bool _descExpand = false;
  bool _loading    = true;
  String? _error;
  PropertyApi? _prop;
  final PageController _imgCtrl = PageController();

  PropertyApi get p => _prop!;

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
    if (widget.propertyApi != null) {
      _prop = widget.propertyApi;
      _loading = false;
    } else {
      _loadProperty();
    }
  }

  Future<void> _loadProperty() async {
    try {
      final prop = await PropertyService.getProperty(widget.propertyId!);
      if (!mounted) return;
      setState(() { _prop = prop; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = ErrorHandler.getMessage(e); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'حدث خطأ غير متوقع'; _loading = false; });
    }
  }

  void _onLangChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange); _imgCtrl.dispose(); super.dispose(); }

  // ═══════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: context.kSand,
        appBar: AppBar(backgroundColor: _kOcean, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: _kOcean)),
      );
    }
    if (_error != null || _prop == null) {
      return Scaffold(
        backgroundColor: context.kSand,
        appBar: AppBar(backgroundColor: _kOcean, elevation: 0),
        body: Center(child: Text(_error ?? 'العقار غير موجود',
            style: TextStyle(fontSize: 16, color: context.kSub))),
      );
    }
    return Scaffold(
      backgroundColor: context.kSand,
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
                          Color(0xFFF3F4F6), context.kSub),
                      if (p.isFeatured) ...[
                        const SizedBox(width: 8),
                        _badge('⭐', S.featured,
                            const Color(0xFFFFF8E1), const Color(0xFFF59E0B)),
                      ],
                    ]),
                    const SizedBox(height: 12),
                    // Property name
                    Text(p.name,
                        style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900,
                          color: context.kText, height: 1.2,
                        )),
                    const SizedBox(height: 8),
                    // Location
                    Row(children: [
                      const Icon(Icons.location_on_rounded,
                          size: 15, color: _kOrange),
                      const SizedBox(width: 4),
                      Expanded(child: Text(
                        p.area,
                        style: TextStyle(
                            fontSize: 13, color: context.kSub),
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
                      if (p.instantBooking)
                        _infoBadge(Icons.bolt_rounded,
                            S.instantBooking, const Color(0xFF22C55E)),
                      if (!p.instantBooking)
                        _infoBadge(Icons.schedule_rounded,
                            S.needsApproval, context.kSub),
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
                  _stat('🛏️', '${p.bedrooms}', S.rooms),
                  _divV(),
                  _stat('🛁', '${p.bathrooms}', S.bathrooms),
                  _divV(),
                  _stat('👥', '${p.maxGuests}', S.maxGuests),
                  _divV(),
                  _stat('🌙', '1+', S.nights),
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
                      Text(S.aboutProperty,
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w900, color: context.kText)),
                      const SizedBox(height: 10),
                      AnimatedCrossFade(
                        firstChild: Text(p.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14, color: context.kSub, height: 1.6)),
                        secondChild: Text(p.description,
                            style: TextStyle(
                                fontSize: 14, color: context.kSub, height: 1.6)),
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

              // ── Services ────────────────────────────
              if (p.services.isNotEmpty)
                _section('🏊 الخدمات', _servicesGrid()),

              // ── Pricing breakdown ────────────────────
              _section('💰 التسعير', _pricingCard()),

              // ── Check-in / closing time ───────────────
              _section('🕐 مواعيد الوصول', _checkInCard()),

              // ── Reviews placeholder ──────────────────
              _section('⭐ التقييمات', _reviewsSection()),

              // ── Owner info ───────────────────────────
              if (p.owner != null)
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
                Text('${p.pricePerNight.toStringAsFixed(0)} جنيه',
                    style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900,
                      color: _kOcean,
                    )),
                Text('/ الليلة',
                    style: TextStyle(fontSize: 12, color: context.kSub)),
              ]),
              const Spacer(),
              // Book button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: p.isAvailable ? _startBooking : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.isAvailable ? _kOcean : Colors.grey,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    p.isAvailable ? 'احجز الآن 🏖️' : 'غير متاح',
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
      builder: (_) => BookingFlowPage(propertyApi: p),
    ));
  }

  // ── Helpers ─────────────────────────────────────────────────

  Widget _section(String title, Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    color: Colors.white,
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w900, color: context.kText)),
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
      Text(emoji, style: TextStyle(fontSize: 22)),
      const SizedBox(height: 4),
      Text(val, style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w900, color: context.kText)),
      Text(label, style: TextStyle(fontSize: 11, color: context.kSub)),
    ]));

  Widget _divV() => Container(
    height: 40, width: 1, color: context.kBorder);

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

  Widget _servicesGrid() => Wrap(
    spacing: 8, runSpacing: 8,
    children: p.services.map((s) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: s.isFree ? const Color(0xFF22C55E).withValues(alpha: 0.08)
                        : _kOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: s.isFree ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                            : _kOrange.withValues(alpha: 0.3)),
      ),
      child: Text('${s.name} ${s.displayPrice}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: s.isFree ? const Color(0xFF22C55E) : _kOrange)),
    )).toList(),
  );

  Widget _pricingCard() => Column(children: [
    _priceRow('السعر الأساسي / ليلة',
        '${p.pricePerNight.toStringAsFixed(0)} جنيه'),
    if ((p.weekendPrice ?? 0) > 0)
      _priceRow('سعر نهاية الأسبوع',
          '${p.weekendPrice!.toStringAsFixed(0)} جنيه'),
    if (p.cleaningFee > 0)
      _priceRow(S.cleaningFee,
          '${p.cleaningFee.toStringAsFixed(0)} جنيه'),
    if (p.electricityFee > 0)
      _priceRow('رسوم الكهرباء',
          '${p.electricityFee.toStringAsFixed(0)} جنيه'),
    if (p.waterFee > 0)
      _priceRow('رسوم المياه',
          '${p.waterFee.toStringAsFixed(0)} جنيه'),
    if (p.securityDeposit > 0)
      _priceRow('تأمين (مسترد)',
          '${p.securityDeposit.toStringAsFixed(0)} جنيه'),
    Divider(color: context.kBorder, height: 24),
    _priceRow('الحد الأدنى للإقامة', '1 ليلة', bold: true),
  ]);

  Widget _priceRow(String label, String val, {bool bold = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(label,
            style: TextStyle(fontSize: 13,
                color: bold ? context.kText : context.kSub,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
        Text(val, style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: bold ? _kOcean : context.kText)),
      ]),
    );

  Widget _checkInCard() => Row(children: [
    Expanded(child: _timeCard('تسجيل الوصول',
        '14:00',
        Icons.login_rounded, const Color(0xFF22C55E))),
    const SizedBox(width: 12),
    Expanded(child: _timeCard('وقت الإغلاق',
        p.closingTime ?? '22:00',
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
        Text(label, style: TextStyle(
            fontSize: 11, color: context.kSub)),
      ]),
    );

  Widget _reviewsSection() {
    if (p.reviewCount == 0) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('لا يوجد تقييمات بعد',
              style: TextStyle(color: context.kSub, fontSize: 13)),
        ),
      );
    }
    return Column(children: [
      Row(children: [
        Text(p.rating.toStringAsFixed(1),
            style: TextStyle(
                fontSize: 48, fontWeight: FontWeight.w900, color: context.kText)),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: List.generate(5, (i) => Icon(
            i < p.rating.round()
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            color: const Color(0xFFF59E0B), size: 20))),
          Text('${p.reviewCount} تقييم',
              style: TextStyle(fontSize: 13, color: context.kSub)),
        ]),
      ]),
    ]);
  }

  Widget _ownerCard() {
    final ownerName = p.owner?.name ?? 'المالك';
    return Row(children: [
      Container(
        width: 54, height: 54,
        decoration: BoxDecoration(
          color: _kOcean.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Center(child: Text(
          ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'م',
          style: const TextStyle(fontSize: 22,
              fontWeight: FontWeight.w900, color: _kOcean),
        )),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ownerName,
              style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w800, color: context.kText)),
          Text('مضيف في Talaa',
              style: TextStyle(fontSize: 12, color: context.kSub)),
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
}
