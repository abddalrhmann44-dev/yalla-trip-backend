// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Profile Page
//  Real Firebase data · Owner toggle inside profile · No fake data
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_role_service.dart';
import 'owner_add_property_page.dart';
import 'login_page.dart';
import '../main.dart' show appSettings;

const _kOcean  = Color(0xFF1565C0);
const _kOrange = Color(0xFFFF6D00);
const _kSand   = Color(0xFFF5F3EE);
const _kCard   = Colors.white;
const _kText   = Color(0xFF0D1B2A);
const _kSub    = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kGreen  = Color(0xFF4CAF50);
const _kRed    = Color(0xFFEF5350);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  // ── Real data from Firebase ───────────────────────────────
  String  _name        = '';
  String  _email       = '';
  String  _phone       = '';
  String  _memberSince = '';
  bool    _isOwner     = false;
  bool    _loading     = true;

  // Settings toggles
  bool _notifBookings = true;
  bool _notifMessages = true;
  bool _notifDeals    = false;

  // Owner stats (real from Firestore)
  int    _listingsCount = 0;
  int    _bookingsCount = 0;
  double _avgRating     = 0.0;
  int    _totalRevenue  = 0;

  // Guest stats (real from Firestore)
  int _tripsCount    = 0;
  int _reviewsCount  = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final db  = FirebaseFirestore.instance;
      final doc = await db.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

      // Role
      final roleStr = data['role'] as String? ?? 'guest';
      _isOwner = roleStr == 'owner';

      // Basic info
      _name  = data['name']  as String? ?? user.displayName ?? '';
      _email = data['email'] as String? ?? user.email ?? '';
      _phone = data['phone'] as String? ?? user.phoneNumber ?? '';

      // Member since
      if (data['createdAt'] != null) {
        final ts = (data['createdAt'] as dynamic).toDate() as DateTime;
        final months = ['يناير','فبراير','مارس','إبريل','مايو','يونيو',
                        'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
        _memberSince = '${months[ts.month - 1]} ${ts.year}';
      }

      // Owner stats
      if (_isOwner) {
        final props = await db.collection('properties')
            .where('ownerId', isEqualTo: user.uid)
            .get();
        _listingsCount = props.docs.length;

        final bookings = await db.collection('bookings')
            .where('ownerId', isEqualTo: user.uid)
            .get();
        _bookingsCount = bookings.docs.length;

        int total = 0;
        double ratingSum = 0;
        int ratedCount   = 0;
        for (final b in bookings.docs) {
          final d = b.data();
          total += ((d['ownerAmount'] ?? 0) as num).toInt();
          final r = (d['rating'] ?? 0) as num;
          if (r > 0) { ratingSum += r; ratedCount++; }
        }
        _totalRevenue = total;
        _avgRating = ratedCount > 0 ? ratingSum / ratedCount : 0.0;
      } else {
        // Guest stats
        final bookings = await db.collection('bookings')
            .where('userId', isEqualTo: user.uid)
            .get();
        _tripsCount = bookings.docs.length;

        int reviews = 0;
        for (final b in bookings.docs) {
          if ((b.data()['rating'] ?? 0) > 0) reviews++;
        }
        _reviewsCount = reviews;
      }

      if (mounted) { setState(() => _loading = false); }
    } catch (e) {
      debugPrint('Profile load error: $e');
      if (mounted) { setState(() => _loading = false); }
    }
  }

  // ── Upgrade to Owner ──────────────────────────────────────
  Future<void> _becomeOwner() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تحويل الحساب لمالك عقار؟',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: const Text(
          'هتقدر تضيف عقاراتك وتستقبل حجوزات وتستلم مدفوعات.\n\nممكن ترجع عميل في أي وقت.',
          style: TextStyle(color: _kSub, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء',
                style: TextStyle(color: _kSub, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOcean,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('تحويل لمالك',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await UserRoleService.instance.saveRole(UserRole.owner);
    setState(() { _isOwner = true; _loading = true; });
    await _loadProfile();
  }

  // ── Switch back to Guest ──────────────────────────────────
  Future<void> _becomeGuest() async {
    await UserRoleService.instance.saveRole(UserRole.guest);
    setState(() { _isOwner = false; _loading = true; });
    await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _kSand,
        body: Center(child: CircularProgressIndicator(color: _kOcean)),
      );
    }

    return Scaffold(
      backgroundColor: _kSand,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          if (_isOwner) ...[
            SliverToBoxAdapter(child: _buildOwnerBanner()),
            SliverToBoxAdapter(child: _buildOwnerSection()),
          ] else ...[
            SliverToBoxAdapter(child: _buildBeOwnerCard()),
            SliverToBoxAdapter(child: _buildGuestSection()),
          ],
          SliverToBoxAdapter(child: _buildSettings()),
          SliverToBoxAdapter(child: _buildDangerZone()),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  // ── Header (Real data) ────────────────────────────────────
  Widget _buildHeader() {
    final initials = _name.isNotEmpty
        ? _name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join()
        : '؟';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomCenter,
          colors: [Color(0xFF0A2463), Color(0xFF1565C0), Color(0xFF1E88E5)],
        ),
      ),
      child: SafeArea(bottom: false, child: Column(children: [
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
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
            const Spacer(),
            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _isOwner
                    ? _kOrange.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isOwner ? '🏠 مالك عقار' : '🧳 عميل',
                style: const TextStyle(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // Avatar with initials
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.4), width: 3),
          ),
          child: Center(child: Text(initials,
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w900,
                  color: Colors.white))),
        ),

        const SizedBox(height: 12),

        Text(_name.isNotEmpty ? _name : 'بدون اسم',
            style: const TextStyle(color: Colors.white,
                fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),

        if (_phone.isNotEmpty)
          Text(_phone, style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
        if (_email.isNotEmpty)
          Text(_email, style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65), fontSize: 11)),

        const SizedBox(height: 10),

        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _badge('✅ موثّق', Colors.white.withValues(alpha: 0.2)),
          if (_memberSince.isNotEmpty) ...[
            const SizedBox(width: 8),
            _badge('⭐ عضو منذ $_memberSince',
                Colors.white.withValues(alpha: 0.2)),
          ],
        ]),

        const SizedBox(height: 20),
      ])),
    );
  }

  Widget _badge(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(
          color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  // ── Card لتحويل لمالك (للـ guest) ─────────────────────────
  Widget _buildBeOwnerCard() {
    return GestureDetector(
      onTap: _becomeOwner,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFF6D00), Color(0xFFFF8F00)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: _kOrange.withValues(alpha: 0.35),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Row(children: [
          Text('🏠', style: TextStyle(fontSize: 32)),
          SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('هل عندك عقار؟',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                      color: Colors.white)),
              Text('حوّل حسابك لمالك وضيف عقارك الآن',
                  style: TextStyle(fontSize: 11,
                      color: Colors.white70)),
            ],
          )),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: Colors.white),
        ]),
      ),
    );
  }

  // ── Owner banner (للمالك — switch back button) ─────────────
  Widget _buildOwnerBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kOcean.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kOcean.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.home_work_rounded, color: _kOcean, size: 20),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('أنت في وضع المالك',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                  color: _kOcean)),
        ),
        GestureDetector(
          onTap: _becomeGuest,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kSub.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('تحويل لعميل',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: _kSub)),
          ),
        ),
      ]),
    );
  }

  // ── Guest Section (real data) ─────────────────────────────
  Widget _buildGuestSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _statCard(_tripsCount.toString(),  'رحلاتي',   '✈️', _kOcean),
          const SizedBox(width: 12),
          _statCard(_reviewsCount.toString(),'تقييماتي', '⭐', const Color(0xFFFFC107)),
        ]),

        const SizedBox(height: 20),

        _sectionTitle('بياناتي'),
        const SizedBox(height: 10),

        _infoTile(Icons.person_rounded,    'الاسم الكامل', _name.isNotEmpty  ? _name  : '—'),
        _infoTile(Icons.phone_rounded,     'رقم الهاتف',   _phone.isNotEmpty ? _phone : '—'),
        if (_email.isNotEmpty)
          _infoTile(Icons.email_rounded,   'البريد الإلكتروني', _email),

        const SizedBox(height: 20),
      ]),
    );
  }

  // ── Owner Section (real data) ─────────────────────────────
  Widget _buildOwnerSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Stats row
        Row(children: [
          _statCard(_listingsCount.toString(), 'عقاراتي',  '🏠', _kOcean),
          const SizedBox(width: 8),
          _statCard(_bookingsCount.toString(), 'حجوزاتي',  '📅', _kGreen),
          const SizedBox(width: 8),
          _statCard(
            _avgRating > 0 ? _avgRating.toStringAsFixed(1) : '—',
            'التقييم', '⭐', const Color(0xFFFFC107)),
        ]),

        const SizedBox(height: 12),

        // Revenue card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(
                color: _kOcean.withValues(alpha: 0.35),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            const Text('💰', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إجمالي ما استلمته',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text(
                  _totalRevenue > 0
                      ? 'EGP ${_totalRevenue.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'
                      : 'EGP 0',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 22, fontWeight: FontWeight.w900)),
                Text(
                  _bookingsCount > 0
                      ? '$_bookingsCount حجز حتى الآن'
                      : 'لا يوجد حجوزات بعد',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            )),
          ]),
        ),

        const SizedBox(height: 16),

        // Add listing CTA
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const OwnerAddPropertyPage())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _kOrange.withValues(alpha: 0.3), width: 1.5),
            ),
            child: const Row(children: [
              Text('➕', style: TextStyle(fontSize: 24)),
              SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إضافة عقار جديد',
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w800, color: _kText)),
                  Text('أضف شاليهك أو فيلتك في دقائق',
                      style: TextStyle(fontSize: 11, color: _kSub)),
                ],
              )),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: _kOrange),
            ]),
          ),
        ),

        const SizedBox(height: 20),

        _sectionTitle('بياناتي'),
        const SizedBox(height: 10),

        _infoTile(Icons.person_rounded, 'الاسم الكامل',
            _name.isNotEmpty ? _name : '—'),
        _infoTile(Icons.phone_rounded, 'رقم الهاتف',
            _phone.isNotEmpty ? _phone : '—'),
        if (_email.isNotEmpty)
          _infoTile(Icons.email_rounded, 'البريد الإلكتروني', _email),

        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _statCard(String val, String label, String emoji, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 5),
        Text(val, style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(
            fontSize: 10, color: _kSub, fontWeight: FontWeight.w600)),
      ]),
    ));
  }

  Widget _infoTile(IconData icon, String label, String val) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: _kOcean),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(
                fontSize: 10, color: _kSub, fontWeight: FontWeight.w600)),
            Text(val, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _kText)),
          ],
        )),
      ]),
    );
  }

  // ── Settings ──────────────────────────────────────────────
  Widget _buildSettings() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        _sectionTitle('الإشعارات'),
        const SizedBox(height: 10),
        _switchTile('📅 تحديثات الحجز',
            'اعرف أي جديد في حجوزاتك',
            _notifBookings, (v) => setState(() => _notifBookings = v)),
        _switchTile('💬 الرسائل',
            'رسائل جديدة من الملاك أو الضيوف',
            _notifMessages, (v) => setState(() => _notifMessages = v)),
        _switchTile('⚡ عروض خاصة',
            'عروض محدودة الوقت على العقارات',
            _notifDeals, (v) => setState(() => _notifDeals = v)),

        const SizedBox(height: 20),
        _sectionTitle('التفضيلات'),
        const SizedBox(height: 10),
        _switchTile('🌙 الوضع الداكن', 'تحويل للثيم الداكن',
            appSettings.darkMode,
            (v) { appSettings.toggleDark(); setState(() {}); }),
        _switchTile('🇦🇪 الواجهة العربية', 'تحويل للعربية',
            appSettings.arabic,
            (v) { appSettings.toggleArabic(); setState(() {}); }),

        const SizedBox(height: 20),
        _sectionTitle('الدعم'),
        const SizedBox(height: 10),
        _navTile(Icons.help_outline_rounded, 'مركز المساعدة', _kOcean,
            onTap: () {}),
        _navTile(Icons.star_rate_rounded, 'قيّم التطبيق ⭐', _kOrange,
            onTap: () {}),

        const SizedBox(height: 20),
      ]),
    );
  }

  // ── Danger Zone ───────────────────────────────────────────
  Widget _buildDangerZone() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        // Logout
        GestureDetector(
          onTap: _confirmLogout,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kRed.withValues(alpha: 0.3)),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: _kRed, size: 18),
                SizedBox(width: 8),
                Text('تسجيل الخروج',
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w800, color: _kRed)),
              ]),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _confirmDeleteAccount,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kRed.withValues(alpha: 0.5)),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_forever_rounded,
                    color: _kRed, size: 18),
                SizedBox(width: 8),
                Text('حذف الحساب',
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w800, color: _kRed)),
              ]),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Yalla Trip v1.0.0 · Made with ❤️ in Egypt',
            style: TextStyle(fontSize: 11, color: _kSub)),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _switchTile(String title, String sub, bool val,
      ValueChanged<bool> onChange) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? const Color(0xFF2E3540) : _kBorder),
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : _kText)),
            Text(sub, style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white54 : _kSub)),
          ],
        )),
        Switch.adaptive(
            value: val,
            activeThumbColor: _kOcean,
            onChanged: onChange,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ]),
    );
  }

  Widget _navTile(IconData icon, String label, Color color,
      {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2530) : _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? const Color(0xFF2E3540) : _kBorder),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: color))),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 13,
              color: onTap != null
                  ? color.withValues(alpha: 0.4)
                  : _kBorder),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(t, style: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : _kText));
  }

  // ── Logout Dialog ─────────────────────────────────────────
  void _confirmLogout() {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('تسجيل الخروج؟',
          style: TextStyle(fontWeight: FontWeight.w900)),
      content: const Text('هل أنت متأكد من تسجيل الخروج؟',
          style: TextStyle(color: _kSub)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء',
              style: TextStyle(color: _kOcean, fontWeight: FontWeight.w700)),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            UserRoleService.instance.clearCache();
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (_) => false);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _kRed,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('خروج',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  // ── Delete Account Dialog ─────────────────────────────────
  void _confirmDeleteAccount() {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('حذف الحساب؟',
          style: TextStyle(fontWeight: FontWeight.w900, color: _kRed)),
      content: const Text(
          'سيتم حذف حسابك وجميع بياناتك نهائياً. لا يمكن التراجع.',
          style: TextStyle(color: _kSub)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء',
              style: TextStyle(color: _kOcean, fontWeight: FontWeight.w700)),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            try {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                await FirebaseFirestore.instance
                    .collection('users').doc(uid).delete();
              }
              UserRoleService.instance.clearCache();
              await FirebaseAuth.instance.currentUser?.delete();
            } catch (_) {}
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (_) => false);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _kRed,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('حذف',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }
}
