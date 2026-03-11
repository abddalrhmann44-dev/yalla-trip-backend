// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Owner Dashboard Page
//  Premium host dashboard — Airbnb / Booking.com quality
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'owner_add_property_page.dart';
import 'home_page.dart';
import '../services/user_role_service.dart';

// ── Colors ──────────────────────────────────────────────────────
const _kOcean  = Color(0xFF1565C0);
const _kOrange = Color(0xFFFF6D00);
const _kSand   = Color(0xFFF5F3EE);
const _kCard   = Colors.white;
const _kText   = Color(0xFF0D1B2A);
const _kSub    = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kGreen  = Color(0xFF22C55E);

// ── Property Model ──────────────────────────────────────────────
class _Property {
  final String   id, name, area, location, category, ownerId;
  final int      price;
  final double   rating;
  final int      reviewCount;
  final List<String> images;
  final bool     available, instant, featured;
  final DateTime createdAt;

  _Property.fromFirestore(String docId, Map<String, dynamic> d)
      : id          = docId,
        name        = d['name']        ?? '',
        area        = d['area']        ?? '',
        location    = d['location']    ?? '',
        category    = d['category']    ?? '',
        ownerId     = d['ownerId']     ?? '',
        price       = (d['price']      ?? 0).toInt(),
        rating      = (d['rating']     ?? 0.0).toDouble(),
        reviewCount = (d['reviewCount'] ?? 0).toInt(),
        images      = List<String>.from(d['images'] ?? []),
        available   = d['available']   ?? true,
        instant     = d['instant']     ?? false,
        featured    = d['featured']    ?? false,
        createdAt   = (d['createdAt'] as dynamic)?.toDate() ?? DateTime.now();

  String get firstImage => images.isNotEmpty ? images.first : '';

  String get categoryEmoji {
    switch (category) {
      case 'شاليه':     return '🏡';
      case 'فيلا':      return '🏖️';
      case 'فندق':      return '🏨';
      case 'منتجع':     return '🌺';
      case 'أكوا بارك': return '🌊';
      case 'بيت شاطئ':  return '🏄';
      default:          return '🏠';
    }
  }

  Color get areaColor {
    switch (area) {
      case 'عين السخنة':     return const Color(0xFF0288D1);
      case 'الساحل الشمالي': return const Color(0xFF1976D2);
      case 'الجونة':         return const Color(0xFFE65100);
      case 'الغردقة':        return const Color(0xFF00695C);
      case 'شرم الشيخ':      return const Color(0xFF6A1B9A);
      case 'رأس سدر':        return const Color(0xFF00897B);
      default:               return _kOcean;
    }
  }

  String get formattedPrice =>
      price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},');
}

// ══════════════════════════════════════════════════════════════
//  OWNER DASHBOARD PAGE
// ══════════════════════════════════════════════════════════════
class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({super.key});
  @override State<OwnerDashboardPage> createState() =>
      _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage>
    with TickerProviderStateMixin {

  List<_Property> _properties = [];
  bool _loading = true;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _checkOwnerAccess();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }



  Future<void> _checkOwnerAccess() async {
    final isOwner = await UserRoleService.instance.isOwner;
    if (!isOwner && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
      return;
    }
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    if (user == null) { setState(() => _loading = false); return; }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('properties')
          .where('ownerId', isEqualTo: user!.uid)
          .orderBy('createdAt', descending: true)
          .get();
      final list = snap.docs
          .map((d) => _Property.fromFirestore(d.id, d.data()))
          .toList();
      if (mounted) {
        setState(() { _properties = list; _loading = false; });
        _fadeCtrl.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleAvailability(_Property p) async {
    await FirebaseFirestore.instance
        .collection('properties')
        .doc(p.id)
        .update({'available': !p.available});
    _loadProperties();
  }

  Future<void> _deleteProperty(_Property p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف العقار؟',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('هيتحذف "${p.name}" نهائياً ومش هيرجع.',
            style: const TextStyle(color: _kSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لأ', style: TextStyle(color: _kSub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('احذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseFirestore.instance
        .collection('properties').doc(p.id).delete();
    _loadProperties();
  }

  // ── Stats ────────────────────────────────────────────────────
  int get _activeCount =>
      _properties.where((p) => p.available).length;
  double get _avgRating {
    final rated = _properties.where((p) => p.rating > 0);
    if (rated.isEmpty) return 0;
    return rated.map((p) => p.rating).reduce((a, b) => a + b) /
        rated.length;
  }
  int get _totalReviews =>
      _properties.fold(0, (sum, p) => sum + p.reviewCount);

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kSand,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _kOcean))
            : RefreshIndicator(
                onRefresh: _loadProperties,
                color: _kOcean,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildSliverHeader(),
                    _buildStatsBar(),
                    if (_properties.isEmpty)
                      _buildEmptySliver()
                    else ...[
                      _buildSectionTitle('عقاراتك'),
                      _buildPropertiesList(),
                    ],
                    const SliverToBoxAdapter(
                        child: SizedBox(height: 120)),
                  ],
                ),
              ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  // ── Sliver App Bar ───────────────────────────────────────────
  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF0A2463),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 15, color: Colors.white),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.fadeTitle,
        ],
        background: Stack(fit: StackFit.expand, children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A2463),
                  Color(0xFF1565C0),
                  Color(0xFF1E88E5),
                ],
              ),
            ),
          ),
          // Decorative circles
          Positioned(
            top: -30, right: -30,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 20, left: -20,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kOrange.withValues(alpha: 0.15),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(children: [
                  // Avatar
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 2),
                    ),
                    child: Center(
                      child: Text(
                        (user?.displayName ?? 'M')
                            .substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('أهلاً،',
                          style: TextStyle(color: Colors.white70,
                              fontSize: 13)),
                      Text(user?.displayName ?? 'المالك',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20,
                              fontWeight: FontWeight.w900)),
                    ],
                  )),
                  // Host badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kOrange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(children: [
                      Icon(Icons.verified_rounded,
                          size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Host', style: TextStyle(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ── Stats Bar ────────────────────────────────────────────────
  Widget _buildStatsBar() {
    return SliverToBoxAdapter(
      child: Container(
        color: const Color(0xFF0A2463),
        child: Container(
          margin: const EdgeInsets.only(top: 1),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28)),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20, offset: const Offset(0, -4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statItem(
                  '${_properties.length}', 'إجمالي\nالعقارات',
                  Icons.home_work_rounded, _kOcean),
              _divider(),
              _statItem(
                  '$_activeCount', 'مفعّل\nدلوقتي',
                  Icons.check_circle_outline_rounded, _kGreen),
              _divider(),
              _statItem(
                  _avgRating > 0
                      ? _avgRating.toStringAsFixed(1) : '—',
                  'متوسط\nالتقييم',
                  Icons.star_rounded, const Color(0xFFFFC107)),
              _divider(),
              _statItem(
                  '$_totalReviews', 'إجمالي\nالمراجعات',
                  Icons.rate_review_rounded, _kOrange),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(String val, String label,
      IconData icon, Color color) {
    return Column(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(height: 8),
      Text(val, style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: _kSub, height: 1.3)),
    ]);
  }

  Widget _divider() => Container(
      width: 1, height: 50,
      color: _kBorder);

  // ── Section Title ────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(children: [
          Text(title, style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900, color: _kText)),
          const Spacer(),
          Text('${_properties.length} عقار',
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600, color: _kSub)),
        ]),
      ),
    );
  }

  // ── Properties List ──────────────────────────────────────────
  Widget _buildPropertiesList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) => FadeTransition(
          opacity: _fadeAnim,
          child: _propertyCard(_properties[i]),
        ),
        childCount: _properties.length,
      ),
    );
  }

  // ── Property Card ────────────────────────────────────────────
  Widget _propertyCard(_Property p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18, offset: const Offset(0, 5))],
      ),
      child: Column(children: [
        // ── Image ──
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(22)),
          child: SizedBox(
            height: 160, width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              // Image or gradient
              p.firstImage.isNotEmpty
                  ? Image.network(p.firstImage, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _imgPlaceholder(p))
                  : _imgPlaceholder(p),

              // Dark gradient
              Container(
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
              ),

              // ── Status pill ──
              Positioned(top: 12, left: 12,
                child: GestureDetector(
                  onTap: () => _toggleAvailability(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: p.available ? _kGreen : Colors.grey.shade500,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                          color: (p.available ? _kGreen : Colors.grey)
                              .withValues(alpha: 0.4),
                          blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min,
                        children: [
                      Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(p.available ? 'مفعّل' : 'موقوف',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                )),

              // ── Badges ──
              Positioned(top: 12, right: 12,
                child: Row(children: [
                  if (p.featured)
                    _badge('⭐ مميز', _kOrange),
                  if (p.instant) ...[
                    const SizedBox(width: 6),
                    _badge('⚡ فوري', _kOcean),
                  ],
                ])),

              // ── Price bottom left ──
              Positioned(bottom: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'EGP ${p.formattedPrice} / ليلة',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w800),
                  ),
                )),

              // ── Rating bottom right ──
              if (p.rating > 0)
                Positioned(bottom: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min,
                        children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFC107), size: 13),
                      Text(' ${p.rating}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ]),
                  )),
            ]),
          ),
        ),

        // ── Details ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: const TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w900, color: _kText),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.location_on_rounded,
                        size: 13, color: p.areaColor),
                    const SizedBox(width: 2),
                    Text(p.location.isNotEmpty
                        ? '${p.area} · ${p.location}'
                        : p.area,
                        style: TextStyle(fontSize: 12,
                            color: p.areaColor,
                            fontWeight: FontWeight.w600)),
                  ]),
                ],
              )),
              const SizedBox(width: 8),
              // Category chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: p.areaColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${p.categoryEmoji} ${p.category}',
                    style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: p.areaColor)),
              ),
            ]),

            const SizedBox(height: 14),
            const Divider(height: 1, color: _kBorder),
            const SizedBox(height: 12),

            // ── Action buttons ──
            Row(children: [
              // Reviews count
              Icon(Icons.rate_review_rounded,
                  size: 14, color: _kSub),
              const SizedBox(width: 4),
              Text('${p.reviewCount} مراجعة',
                  style: const TextStyle(fontSize: 12, color: _kSub,
                      fontWeight: FontWeight.w600)),
              const Spacer(),

              // Edit button
              _actionBtn(
                icon: Icons.edit_rounded,
                label: 'تعديل',
                color: _kOcean,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('قريباً — تعديل العقار')),
                  );
                },
              ),
              const SizedBox(width: 8),

              // Delete button
              _actionBtn(
                icon: Icons.delete_outline_rounded,
                label: 'حذف',
                color: Colors.red,
                onTap: () => _deleteProperty(p),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _imgPlaceholder(_Property p) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [p.areaColor, p.areaColor.withValues(alpha: 0.6)],
      ),
    ),
    child: Center(child: Text(p.categoryEmoji,
        style: const TextStyle(fontSize: 60))),
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: const TextStyle(
        color: Colors.white, fontSize: 10,
        fontWeight: FontWeight.w800)),
  );

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: color)),
        ]),
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────
  Widget _buildEmptySliver() {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: _kOcean.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.home_work_outlined,
                    size: 48, color: _kOcean),
              ),
              const SizedBox(height: 24),
              const Text('مفيش عقارات لسه',
                  style: TextStyle(fontSize: 20,
                      fontWeight: FontWeight.w900, color: _kText)),
              const SizedBox(height: 8),
              const Text(
                'ابدأ أضف أول عقارك دلوقتي\nوابدأ تستقبل حجوزات من آلاف المسافرين',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14,
                    color: _kSub, height: 1.5),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _goAddProperty,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('أضف عقار',
                    style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOcean,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FAB ──────────────────────────────────────────────────────
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _goAddProperty,
      backgroundColor: _kOcean,
      foregroundColor: Colors.white,
      elevation: 6,
      icon: const Icon(Icons.add_rounded, size: 22),
      label: const Text('عقار جديد',
          style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.w800)),
    );
  }

  void _goAddProperty() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const OwnerAddPropertyPage()),
    );
    _loadProperties();
  }
}
