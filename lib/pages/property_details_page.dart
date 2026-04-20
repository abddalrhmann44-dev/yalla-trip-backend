// ═══════════════════════════════════════════════════════════════
//  TALAA — Property Details Page
//  Full details, gallery, reviews, book CTA → BookingFlowPage
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show appSettings;
import '../services/sharing_service.dart';
import '../utils/app_strings.dart';
import '../widgets/constants.dart';
import '../widgets/favorite_button.dart';
import '../models/property_model_api.dart';
import '../models/review_model.dart';
import '../services/property_service.dart';
import '../services/report_service.dart';
import '../services/review_service.dart';
import '../widgets/report_sheet.dart';
import '../utils/api_client.dart';
import '../utils/error_handler.dart';
import 'booking_flow_page.dart';
import 'photo_viewer_page.dart';
import 'chat_page.dart';
import '../widgets/review_card.dart';
import '../widgets/verified_badge.dart';

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
  bool _descExpand = false;
  bool _loading    = true;
  String? _error;
  PropertyApi? _prop;
  final PageController _imgCtrl = PageController();

  // Similar properties (recommendations)
  List<PropertyApi> _similar = [];
  bool _similarLoading = false;

  // Reviews
  List<ReviewModel> _reviews = const [];
  bool _reviewsLoading = false;

  PropertyApi get p => _prop!;

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
    if (widget.propertyApi != null) {
      _prop = widget.propertyApi;
      _loading = false;
      _loadSimilar();
      _loadReviews();
    } else {
      _loadProperty();
    }
  }

  Future<void> _loadProperty() async {
    try {
      final prop = await PropertyService.getProperty(widget.propertyId!);
      if (!mounted) return;
      setState(() { _prop = prop; _loading = false; });
      _loadSimilar();
      _loadReviews();
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = ErrorHandler.getMessage(e); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'حدث خطأ غير متوقع'; _loading = false; });
    }
  }

  Future<void> _loadSimilar() async {
    if (_prop == null || _similarLoading) return;
    setState(() => _similarLoading = true);
    try {
      final list = await PropertyService.getSimilar(_prop!.id, limit: 8);
      if (!mounted) return;
      setState(() {
        _similar = list;
        _similarLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _similarLoading = false);
    }
  }

  Future<void> _loadReviews() async {
    if (_prop == null || _reviewsLoading) return;
    setState(() => _reviewsLoading = true);
    try {
      final list = await ReviewService.forProperty(_prop!.id, limit: 6);
      if (!mounted) return;
      setState(() {
        _reviews = list;
        _reviewsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _reviewsLoading = false);
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
              Padding(
                padding: const EdgeInsets.all(8),
                child: FavoriteButton(
                  propertyId: p.id,
                  size: 20,
                  background: Colors.black.withValues(alpha: 0.35),
                  inactiveColor: Colors.white,
                  activeColor: Colors.red,
                  padding: const EdgeInsets.all(8),
                ),
              ),
              GestureDetector(
                onTap: () => _sharePropertyLink(p),
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              GestureDetector(
                onTap: () => showReportSheet(
                  context,
                  target: ReportTarget.property,
                  targetId: p.id,
                ),
                child: Container(
                  margin: const EdgeInsets.only(right: 12, left: 8, top: 8, bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flag_outlined,
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
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => _openPhotoViewer(p, i),
                          child: Hero(
                            tag: p.images[i],
                            child: Image.network(
                              p.images[i],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF1565C0),
                                child: const Icon(Icons.villa_rounded,
                                    color: Colors.white54, size: 80)),
                            ),
                          ),
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

              // ── Similar properties ───────────────────
              if (_similar.isNotEmpty)
                _section('✨ عقارات مشابهة', _similarList()),

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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text('لا يوجد تقييمات بعد',
              style: TextStyle(color: context.kSub, fontSize: 13)),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Summary row
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
      const SizedBox(height: 16),
      if (_reviewsLoading && _reviews.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator(color: _kOcean)),
        )
      else
        ..._reviews.map((r) => ReviewCard(review: r)),
    ]);
  }

  Widget _ownerCard() {
    final ownerName = p.owner?.name ?? 'المالك';
    final ownerVerified = p.owner?.isVerified ?? false;
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
          Row(children: [
            Flexible(
              child: Text(ownerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w800, color: context.kText)),
            ),
            if (ownerVerified) ...[
              const SizedBox(width: 4),
              const VerifiedBadge(size: 16),
            ],
          ]),
          const SizedBox(height: 2),
          if (ownerVerified)
            const VerifiedChip(label: 'مضيف موثّق')
          else
            Text('مضيف في Talaa',
                style: TextStyle(fontSize: 12, color: context.kSub)),
        ],
      )),
      GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatPage(propertyId: p.id),
        )),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(color: _kOcean),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('تواصل',
              style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w700, color: _kOcean)),
        ),
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════
  //  SIMILAR PROPERTIES
  // ═══════════════════════════════════════════════════════════════
  Widget _similarList() => SizedBox(
    height: 210,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _similar.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, i) => _similarCard(_similar[i]),
    ),
  );

  Widget _similarCard(PropertyApi sp) => GestureDetector(
    onTap: () => Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PropertyDetailsPage(propertyApi: sp)),
    ),
    child: SizedBox(
      width: 180,
      child: Container(
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: Stack(fit: StackFit.expand, children: [
                  sp.firstImage.isNotEmpty
                      ? Image.network(sp.firstImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _similarPlaceholder(sp))
                      : _similarPlaceholder(sp),
                  PositionedDirectional(
                    top: 6,
                    end: 6,
                    child: FavoriteButton(
                      propertyId: sp.id,
                      size: 14,
                      padding: const EdgeInsets.all(6),
                    ),
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sp.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: context.kText)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.location_on_rounded,
                        size: 11, color: context.kSub),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(sp.area,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10, color: context.kSub)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (sp.rating > 0) ...[
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 12),
                      const SizedBox(width: 2),
                      Text(sp.rating.toStringAsFixed(1),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: context.kText)),
                    ],
                    const Spacer(),
                    Text('${sp.pricePerNight.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: _kOrange)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _similarPlaceholder(PropertyApi sp) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [sp.areaColor, sp.areaColor.withValues(alpha: 0.55)],
      ),
    ),
    child: Center(
      child: Text(sp.categoryEmoji, style: const TextStyle(fontSize: 42)),
    ),
  );

  // ═══════════════════════════════════════════════════════════════
  //  PHOTO VIEWER
  // ═══════════════════════════════════════════════════════════════
  void _openPhotoViewer(PropertyApi prop, int index) {
    if (prop.images.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => PhotoViewerPage(
          images: prop.images,
          initialIndex: index,
          title: prop.name,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SHARE  (native share sheet — WhatsApp, Messenger, SMS, Copy…)
  // ═══════════════════════════════════════════════════════════════
  Future<void> _sharePropertyLink(PropertyApi prop) async {
    HapticFeedback.selectionClick();
    final ok = await SharingService.instance.shareProperty(
      propertyId: prop.id,
      propertyName: prop.name,
      pricePerNight: prop.pricePerNight,
    );
    if (ok || !mounted) return;

    // Fall back to clipboard if the native sheet is unavailable.
    final link = SharingService.instance.propertyUrl(prop.id);
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          appSettings.arabic
              ? 'تم نسخ رابط العقار — الصقه أينما تريد للمشاركة'
              : 'Property link copied — paste it anywhere to share',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        backgroundColor: _kOcean,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
