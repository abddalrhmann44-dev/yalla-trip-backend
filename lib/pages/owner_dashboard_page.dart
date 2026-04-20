// ═══════════════════════════════════════════════════════════════
//  TALAA — Owner Dashboard Page  (REST API)
//  Premium host dashboard — Airbnb / Booking.com quality
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../main.dart' show appSettings;
import '../widgets/constants.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/property_model_api.dart';
import '../services/property_service.dart';
import 'owner_add_property_page.dart';
import 'owner_payouts_page.dart';
import 'host_dashboard_page.dart';
import 'offer_creation_page.dart';
import 'home_page.dart';
import '../services/user_role_service.dart';
import 'availability_calendar_page.dart';

// Accent colors (same in light & dark)
const _kOcean  = Color(0xFF1565C0);
const _kOrange = Color(0xFFFF6D00);
const _kGreen  = Color(0xFF22C55E);


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

  List<PropertyApi> _properties = [];
  bool _loading = true;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onLangChange);
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _checkOwnerAccess();
  }

  void _onLangChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    appSettings.removeListener(_onLangChange); _fadeCtrl.dispose(); super.dispose(); }



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
    try {
      final list = await PropertyService.getMyProperties();
      if (mounted) {
        setState(() { _properties = list; _loading = false; });
        _fadeCtrl.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleAvailability(PropertyApi p) async {
    await PropertyService.updateProperty(
        p.id, {'is_available': !p.isAvailable});
    _loadProperties();
  }

  Future<void> _deleteProperty(PropertyApi p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('حذف العقار؟',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('هيتحذف "${p.name}" نهائياً ومش هيرجع.',
            style: TextStyle(color: context.kSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('لأ', style: TextStyle(color: context.kSub)),
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
    await PropertyService.deleteProperty(p.id);
    _loadProperties();
  }

  // ── Stats ────────────────────────────────────────────────────
  int get _activeCount =>
      _properties.where((p) => p.isAvailable).length;
  double get _avgRating {
    final rated = _properties.where((p) => p.rating > 0);
    if (rated.isEmpty) return 0;
    return rated.map((p) => p.rating).reduce((a, b) => a + b) /
        rated.length;
  }
  int get _totalReviews =>
      _properties.fold(0, (acc, p) => acc + p.reviewCount);

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.kSand,
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
                    _buildOwnerOptionsSection(),
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
            color: context.kCard,
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
          style: TextStyle(fontSize: 10, color: context.kSub, height: 1.3)),
    ]);
  }

  Widget _divider() => Container(
      width: 1, height: 50,
      color: context.kBorder);

  // ── Owner Options Section ──────────────────────────────────────
  Widget _buildOwnerOptionsSection() {
    final isDark = context.isDark;
    final options = [
      _OwnerOption(
        icon: Icons.add_home_work_rounded,
        title: 'Add New Chalet / Hotel',
        subtitle: 'Publish a new listing with photos, pricing, and location.',
        gradient: const [Color(0xFF1565C0), Color(0xFF42A5F5)],
        onTap: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const OwnerAddPropertyPage()));
          _loadProperties();
        },
      ),
      _OwnerOption(
        icon: Icons.view_list_rounded,
        title: 'View My Listings',
        subtitle: 'Manage all your active and inactive properties.',
        gradient: const [Color(0xFF00897B), Color(0xFF4DB6AC)],
        onTap: () {
          // scroll down to properties list
          if (_properties.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No properties yet — add one first!')),
            );
          }
        },
      ),
      _OwnerOption(
        icon: Icons.calendar_month_rounded,
        title: 'Bookings & Requests',
        subtitle: 'Track customer booking requests and confirmed reservations.',
        gradient: const [Color(0xFF5C6BC0), Color(0xFF7986CB)],
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const HostDashboardPage())),
      ),
      _OwnerOption(
        icon: Icons.analytics_rounded,
        title: 'Financial Reports',
        subtitle: 'View revenue, payouts, and monthly statements.',
        gradient: const [Color(0xFFFF6D00), Color(0xFFFFAB40)],
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const OwnerPayoutsPage())),
      ),
      _OwnerOption(
        icon: Icons.local_offer_rounded,
        title: 'Time-Limited Offers',
        subtitle: 'Create discount offers with start/end dates.',
        gradient: const [Color(0xFFAD1457), Color(0xFFE91E63)],
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const OfferCreationPage())),
      ),
      _OwnerOption(
        icon: Icons.support_agent_rounded,
        title: 'Support & Help',
        subtitle: 'Reach our support team anytime.',
        gradient: const [Color(0xFF37474F), Color(0xFF78909C)],
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Support coming soon')),
          );
        },
      ),
    ];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(children: [
              Container(
                width: 4, height: 22,
                decoration: BoxDecoration(
                  color: _kOcean,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Text('Quick Actions',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900,
                      color: context.kText)),
            ]),
            const SizedBox(height: 16),

            // 2-column grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (_, i) {
                final o = options[i];
                return _OwnerOptionCard(
                  icon: o.icon,
                  title: o.title,
                  subtitle: o.subtitle,
                  gradient: o.gradient,
                  isDark: isDark,
                  onTap: o.onTap,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Title ────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(children: [
          Text(title, style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900, color: context.kText)),
          const Spacer(),
          Text('${_properties.length} عقار',
              style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600, color: context.kSub)),
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
  Widget _propertyCard(PropertyApi p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: context.kCard,
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
                      color: p.isAvailable ? _kGreen : Colors.grey.shade500,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                          color: (p.isAvailable ? _kGreen : Colors.grey)
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
                      Text(p.isAvailable ? 'مفعّل' : 'موقوف',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                )),

              // ── Badges ──
              Positioned(top: 12, right: 12,
                child: Row(children: [
                  if (p.isFeatured)
                    _badge('⭐ مميز', _kOrange),
                  if (p.instantBooking) ...[
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
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w900, color: context.kText),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.location_on_rounded,
                        size: 13, color: p.areaColor),
                    const SizedBox(width: 2),
                    Text(p.area,
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
            Divider(height: 1, color: context.kBorder),
            const SizedBox(height: 12),

            // ── Action buttons ──
            Row(children: [
              // Reviews count
              Icon(Icons.rate_review_rounded,
                  size: 14, color: context.kSub),
              const SizedBox(width: 4),
              Text('${p.reviewCount} مراجعة',
                  style: TextStyle(fontSize: 12, color: context.kSub,
                      fontWeight: FontWeight.w600)),
              const Spacer(),

              // Calendar editor button
              _actionBtn(
                icon: Icons.calendar_month_rounded,
                label: 'تقويم',
                color: _kGreen,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AvailabilityCalendarPage(
                      propertyId: p.id,
                      propertyName: p.name,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

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

  Widget _imgPlaceholder(PropertyApi p) => Container(
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
              Text('مفيش عقارات لسه',
                  style: TextStyle(fontSize: 20,
                      fontWeight: FontWeight.w900, color: context.kText)),
              const SizedBox(height: 8),
              Text(
                'ابدأ أضف أول عقارك دلوقتي\nوابدأ تستقبل حجوزات من آلاف المسافرين',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14,
                    color: context.kSub, height: 1.5),
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

// ══════════════════════════════════════════════════════════════
//  _OwnerOption — data model for each option
// ══════════════════════════════════════════════════════════════
class _OwnerOption {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _OwnerOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });
}

// ══════════════════════════════════════════════════════════════
//  _OwnerOptionCard — reusable premium card widget
// ══════════════════════════════════════════════════════════════
class _OwnerOptionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final bool isDark;
  final VoidCallback onTap;

  const _OwnerOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_OwnerOptionCard> createState() => _OwnerOptionCardState();
}

class _OwnerOptionCardState extends State<_OwnerOptionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.gradient.first;
    final cardBg = widget.isDark
        ? const Color(0xFF1A2234)
        : Colors.white;
    final titleColor = widget.isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subColor = widget.isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primaryColor.withValues(alpha: widget.isDark ? 0.15 : 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: widget.isDark ? 0.08 : 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              if (!widget.isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative gradient circle — top right
              Positioned(
                top: -18, right: -18,
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withValues(alpha: 0.12),
                        primaryColor.withValues(alpha: 0.03),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon bubble
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: widget.gradient,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(widget.icon, size: 22, color: Colors.white),
                    ),

                    const SizedBox(height: 14),

                    // Title
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Subtitle
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: subColor,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const Spacer(),

                    // Arrow indicator
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 15, color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
