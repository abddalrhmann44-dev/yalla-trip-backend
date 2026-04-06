// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Profile Page
//  Real Firebase data · Owner toggle inside profile · No fake data
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/user_role_service.dart';
import 'owner_add_property_page.dart';
import 'login_page.dart';
import '../main.dart' show appSettings;
import '../utils/app_strings.dart';

const _kOcean = Color(0xFF1565C0);
const _kOrange = Color(0xFFFF6D00);
const _kSand = Color(0xFFF5F3EE);
const _kCard = Colors.white;
const _kText = Color(0xFF0D1B2A);
const _kSub = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFEF5350);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ── Real data from Firebase ───────────────────────────────
  String _name = '';
  String _email = '';
  String _phone = '';
  bool _isOwner = false;
  bool _loading = true;

  // Settings toggles
  bool _notifBookings = true;
  bool _notifMessages = true;
  bool _notifDeals = false;

  // Owner stats (real from Firestore)
  int _listingsCount = 0;
  int _bookingsCount = 0;
  double _avgRating = 0.0;
  int _totalRevenue = 0;

  // Guest stats (real from Firestore)
  int _tripsCount = 0;
  int _reviewsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final db = FirebaseFirestore.instance;
      final doc = await db.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

      // Role
      final roleStr = data['role'] as String? ?? 'guest';
      _isOwner = roleStr == 'owner';

      // Basic info
      _name = data['name'] as String? ?? user.displayName ?? '';
      _email = data['email'] as String? ?? user.email ?? '';
      _phone = data['phone'] as String? ?? user.phoneNumber ?? '';

      // Owner stats
      if (_isOwner) {
        final props = await db
            .collection('properties')
            .where('ownerId', isEqualTo: user.uid)
            .get();
        _listingsCount = props.docs.length;

        final bookings = await db
            .collection('bookings')
            .where('ownerId', isEqualTo: user.uid)
            .get();
        _bookingsCount = bookings.docs.length;

        int total = 0;
        double ratingSum = 0;
        int ratedCount = 0;
        for (final b in bookings.docs) {
          final d = b.data();
          total += ((d['ownerAmount'] ?? 0) as num).toInt();
          final r = (d['rating'] ?? 0) as num;
          if (r > 0) {
            ratingSum += r;
            ratedCount++;
          }
        }
        _totalRevenue = total;
        _avgRating = ratedCount > 0 ? ratingSum / ratedCount : 0.0;
      } else {
        // Guest stats
        final bookings = await db
            .collection('bookings')
            .where('userId', isEqualTo: user.uid)
            .get();
        _tripsCount = bookings.docs.length;

        int reviews = 0;
        for (final b in bookings.docs) {
          if ((b.data()['rating'] ?? 0) > 0) reviews++;
        }
        _reviewsCount = reviews;
      }

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
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
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await UserRoleService.instance.saveRole(UserRole.owner);
    setState(() {
      _isOwner = true;
      _loading = true;
    });
    await _loadProfile();
  }

  // ── Switch back to Guest ──────────────────────────────────
  Future<void> _becomeGuest() async {
    await UserRoleService.instance.saveRole(UserRole.guest);
    setState(() {
      _isOwner = false;
      _loading = true;
    });
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
    return Container(
      color: Colors.white,
      child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar: back + role badge ──────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FF),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                            color: const Color(0xFF0D1B2A)
                                .withValues(alpha: 0.08)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF0D1B2A), size: 16),
                    ),
                  ),
                  const Spacer(),
                  // Role badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isOwner
                          ? _kOrange.withValues(alpha: 0.1)
                          : const Color(0xFFF5F7FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isOwner
                            ? _kOrange.withValues(alpha: 0.4)
                            : const Color(0xFF0D1B2A).withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      _isOwner ? '🏠 ${S.ownerBadge}' : '🧳 ${S.guestBadge}',
                      style: TextStyle(
                          color: _isOwner
                              ? _kOrange
                              : const Color(0xFF0D1B2A).withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // ── اسم المستخدم — tappable ─────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: _showProfileSheet,
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        _name.isNotEmpty ? _name : S.noData,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0D1B2A),
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF0D1B2A)
                                .withValues(alpha: 0.08)),
                      ),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.edit_rounded,
                            size: 13, color: Color(0xFF1565C0)),
                        SizedBox(width: 4),
                        Text('تعديل',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1565C0))),
                      ]),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 16),

              // ── Thin divider ────────────────────────────
              Divider(
                  height: 1,
                  color: const Color(0xFF0D1B2A).withValues(alpha: 0.07)),
            ],
          )),
    );
  }

  // ── Profile info bottom sheet ─────────────────────────────
  void _showProfileSheet() {
    final nameCtrl = TextEditingController(text: _name);
    final phoneCtrl = TextEditingController(text: _phone);
    final emailCtrl = TextEditingController(text: _email);
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(children: [
                  Text(S.myProfile,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0D1B2A))),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: Color(0xFF0D1B2A)),
                    ),
                  ),
                ]),
              ),

              const Divider(height: 24, indent: 20, endIndent: 20),

              // Fields
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [
                  _sheetField(Icons.person_rounded, S.fullName, nameCtrl),
                  const SizedBox(height: 12),
                  _sheetField(Icons.phone_rounded, S.phone, phoneCtrl,
                      keyType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _sheetField(Icons.email_rounded, S.email, emailCtrl,
                      keyType: TextInputType.emailAddress),
                ]),
              ),

              const SizedBox(height: 20),

              // Save button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: GestureDetector(
                  onTap: saving
                      ? null
                      : () async {
                          setSheet(() => saving = true);
                          try {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .update({
                                'name': nameCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'email': emailCtrl.text.trim(),
                              });
                            }
                            if (!mounted) return;
                            final nav = Navigator.of(context);
                            setState(() {
                              _name = nameCtrl.text.trim();
                              _phone = phoneCtrl.text.trim();
                              _email = emailCtrl.text.trim();
                            });
                            nav.pop();
                          } catch (_) {
                            setSheet(() => saving = false);
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(S.saveChanges,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800))),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sheetField(IconData icon, String label, TextEditingController ctrl,
      {TextInputType? keyType}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FF),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFF0D1B2A).withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        const SizedBox(width: 14),
        Icon(icon, size: 18, color: const Color(0xFF1565C0)),
        const SizedBox(width: 10),
        Expanded(
            child: TextField(
          controller: ctrl,
          keyboardType: keyType,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D1B2A)),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
                fontSize: 11,
                color: const Color(0xFF0D1B2A).withValues(alpha: 0.4)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        )),
        const SizedBox(width: 14),
      ]),
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
          boxShadow: [
            BoxShadow(
                color: _kOrange.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(children: [
          Text('🏠', style: TextStyle(fontSize: 32)),
          SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.becomeOwner,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              Text(S.becomeOwnerSub,
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          )),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white),
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
        Expanded(
          child: Text(S.ownerMode,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _kOcean)),
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
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _kSub)),
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
          _statCard(_tripsCount.toString(), S.tripsCount, '✈️', _kOcean),
          const SizedBox(width: 12),
          _statCard(_reviewsCount.toString(), S.reviewsCountL, '⭐',
              const Color(0xFFFFC107)),
        ]),
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
          _statCard(_listingsCount.toString(), 'عقاراتي', '🏠', _kOcean),
          const SizedBox(width: 8),
          _statCard(_bookingsCount.toString(), 'حجوزاتي', '📅', _kGreen),
          const SizedBox(width: 8),
          _statCard(_avgRating > 0 ? _avgRating.toStringAsFixed(1) : '—',
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
            boxShadow: [
              BoxShadow(
                  color: _kOcean.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(children: [
            const Text('💰', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.totalRevenue,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
                Text(
                    _totalRevenue > 0
                        ? 'EGP ${_totalRevenue.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'
                        : 'EGP 0',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                Text(
                    _bookingsCount > 0
                        ? '$_bookingsCount حجز حتى الآن'
                        : S.noBookingsYet,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            )),
          ]),
        ),

        const SizedBox(height: 16),

        // Add listing CTA
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const OwnerAddPropertyPage())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _kOrange.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Row(children: [
              Text('➕', style: TextStyle(fontSize: 24)),
              SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.addProperty,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _kText)),
                  Text(S.addPropertySub,
                      style: const TextStyle(fontSize: 11, color: _kSub)),
                ],
              )),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _kOrange),
            ]),
          ),
        ),

        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _statCard(String val, String label, String emoji, Color color) {
    return Expanded(
        child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 5),
        Text(val,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: _kSub, fontWeight: FontWeight.w600)),
      ]),
    ));
  }

  // ── Settings ──────────────────────────────────────────────
  Widget _buildSettings() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(S.notifications),
        const SizedBox(height: 10),
        _switchTile(S.notifBookings, S.notifBookingsSub, _notifBookings,
            (v) => setState(() => _notifBookings = v)),
        _switchTile(S.notifMessages, S.notifMessagesSub, _notifMessages,
            (v) => setState(() => _notifMessages = v)),
        _switchTile(S.notifDeals, S.notifDealsSub, _notifDeals,
            (v) => setState(() => _notifDeals = v)),

        const SizedBox(height: 20),
        _sectionTitle(S.preferences),
        const SizedBox(height: 10),
        _switchTile('🌙 ${S.darkMode}', '', appSettings.darkMode, (v) {
          appSettings.toggleDark();
          setState(() {});
        }),
        // ── Language Toggle ────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _kOcean.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                  child: Text('🌐', style: TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.language,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D1B2A))),
                Text(S.langLabel,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
              ],
            )),
            // Toggle بين AR / EN
            GestureDetector(
              onTap: () {
                appSettings.toggleArabic();
                setState(() {});
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kOcean.withValues(alpha: 0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: appSettings.arabic ? _kOcean : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text('AR',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: appSettings.arabic
                                ? Colors.white
                                : const Color(0xFF6B7280))),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: !appSettings.arabic ? _kOcean : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text('EN',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: !appSettings.arabic
                                ? Colors.white
                                : const Color(0xFF6B7280))),
                  ),
                ]),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),
        _sectionTitle(S.support),
        const SizedBox(height: 10),
        _navTile(Icons.help_outline_rounded, S.helpCenter, _kOcean,
            onTap: () {}),
        _navTile(Icons.star_rate_rounded, S.rateApp, _kOrange, onTap: () {}),

        const SizedBox(height: 20),
      ]),
    );
  }

  // ── Danger Zone ───────────────────────────────────────────
  Widget _buildDangerZone() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        // Delete Account (فوق الخروج)
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
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.delete_forever_rounded, color: _kRed, size: 18),
              const SizedBox(width: 8),
              Text(S.deleteAccount,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: _kRed)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
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
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.logout_rounded, color: _kRed, size: 18),
              const SizedBox(width: 8),
              Text(S.logout,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: _kRed)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Talaa v1.0.0 · Made with ❤️ in Egypt',
            style: TextStyle(fontSize: 11, color: _kSub)),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _switchTile(
      String title, String sub, bool val, ValueChanged<bool> onChange) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2E3540) : _kBorder),
      ),
      child: Row(children: [
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : _kText)),
            Text(sub,
                style: TextStyle(
                    fontSize: 10, color: isDark ? Colors.white54 : _kSub)),
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
          border:
              Border.all(color: isDark ? const Color(0xFF2E3540) : _kBorder),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color))),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 13,
              color: onTap != null ? color.withValues(alpha: 0.4) : _kBorder),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(t,
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : _kText));
  }

  // ── Logout Dialog ─────────────────────────────────────────
  void _confirmLogout() {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('تسجيل الخروج؟',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              content: const Text('هل أنت متأكد من تسجيل الخروج؟',
                  style: TextStyle(color: _kSub)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء',
                      style: TextStyle(
                          color: _kOcean, fontWeight: FontWeight.w700)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    UserRoleService.instance.clearCache();
                    // ── مسح Google credential عشان متدخلش تلقائي ──
                    try {
                      final googleSignIn = GoogleSignIn();
                      await googleSignIn.signOut();
                    } catch (_) {}
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
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ));
  }

  // ── Delete Account Dialog ─────────────────────────────────
  void _confirmDeleteAccount() {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('حذف الحساب؟',
                  style: TextStyle(fontWeight: FontWeight.w900, color: _kRed)),
              content: const Text(
                  'سيتم حذف حسابك وجميع بياناتك نهائياً. لا يمكن التراجع.',
                  style: TextStyle(color: _kSub)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء',
                      style: TextStyle(
                          color: _kOcean, fontWeight: FontWeight.w700)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid != null) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .delete();
                      }
                      UserRoleService.instance.clearCache();
                      // ── disconnect أقوى من signOut — بيلغي الـ OAuth token كلياً ──
                      try {
                        final googleSignIn = GoogleSignIn();
                        await googleSignIn.disconnect();
                      } catch (_) {}
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
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ));
  }
}
