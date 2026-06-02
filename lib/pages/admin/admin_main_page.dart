// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Main Dashboard  (REST API)
//  Stats + navigation to Properties / Bookings / Users / Reviews /
//  Pending. Access is role-gated — only User.role == admin can reach
//  this page (backend also enforces via require_role).
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/constants.dart';
import '../../services/admin_service.dart';
import '../../main.dart' show userProvider;
import '../admin_pending_page.dart';
import 'admin_properties_page.dart';
import 'admin_bookings_page.dart';
import 'admin_users_page.dart';
import 'admin_stats_page.dart';
import 'admin_reports_page.dart';
import 'admin_promo_codes_page.dart';
import 'admin_payouts_page.dart';
import 'admin_audit_log_page.dart';
import 'admin_reviews_moderation_page.dart';
import 'admin_refunds_page.dart';
import 'admin_disputes_page.dart';
import 'admin_notifications_page.dart';
import 'admin_host_verification_page.dart';
import 'admin_featured_listings_page.dart';
import 'admin_pricing_rules_page.dart';
import 'admin_kyc_page.dart';
import 'admin_analytics_dashboard.dart';
import 'admin_fraud_detection_page.dart';
import 'admin_ab_testing_page.dart';
import 'admin_api_keys_page.dart';
import 'admin_chat_monitor_page.dart';
import 'admin_promo_banner_page.dart';
import 'admin_owners_page.dart';
import 'admin_property_suspension_page.dart';
import 'admin_wallet_management_page.dart';
import 'admin_financial_report_page.dart';
import 'admin_trip_posts_moderation_page.dart';
import 'admin_code_lookup_page.dart';
import 'admin_revenue_detail_page.dart';
import 'admin_commission_detail_page.dart';
import 'admin_withdrawal_requests_page.dart';

const _kOcean  = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF4CAF50);
const _kOrange = Color(0xFFFF6D00);
const _kPurple = Color(0xFF7E57C2);
const _kRed    = Color(0xFFEF5350);

class AdminMainPage extends StatefulWidget {
  const AdminMainPage({super.key});
  @override
  State<AdminMainPage> createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  bool _loading = true;
  String? _error;

  int _propertiesCount = 0;
  int _bookingsCount = 0;
  int _usersCount = 0;
  int _pendingCount = 0;
  int _pendingBookings = 0;
  double _revenue = 0;
  double _platformFees = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await AdminService.getStats();
      _propertiesCount = stats['total_properties'] ?? 0;
      _bookingsCount = stats['total_bookings'] ?? 0;
      _usersCount = stats['total_users'] ?? 0;
      _pendingCount = stats['pending_properties'] ?? 0;
      _pendingBookings = stats['pending_bookings'] ?? 0;
      _revenue = (stats['total_revenue'] ?? 0).toDouble();
      _platformFees = (stats['total_platform_fees'] ?? 0).toDouble();
    } catch (e) {
      debugPrint('Admin stats error: $e');
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ────────────────────────────────────────
          SliverAppBar(
            backgroundColor: _kOcean,
            expandedHeight: 140,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text('لوحة الإدارة',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE85A24), _kOcean],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'مرحباً ${userProvider.name.split(' ').first}',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Stats Cards ────────────────────────────────────
          SliverToBoxAdapter(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                        child: CircularProgressIndicator(color: _kOcean)))
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Column(children: [
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kRed.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kRed.withValues(alpha: 0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded,
                                color: _kRed, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'فشل تحميل الإحصائيات',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _kRed),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadStats,
                              child: const Text('إعادة المحاولة',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _kRed)),
                            ),
                          ]),
                        ),
                      Row(children: [
                        _statCard(
                          'العقارات', '$_propertiesCount',
                          Icons.apartment_rounded, _kOcean,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AdminPropertiesPage())),
                        ),
                        const SizedBox(width: 12),
                        _statCard(
                          'الحجوزات', '$_bookingsCount',
                          Icons.calendar_month_rounded, _kGreen,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AdminBookingsPage())),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        _statCard(
                          'المستخدمين', '$_usersCount',
                          Icons.people_rounded, _kPurple,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AdminUsersPage())),
                        ),
                        const SizedBox(width: 12),
                        _statCard(
                          'الإيرادات',
                          '${_revenue.toStringAsFixed(0)} ج.م',
                          Icons.payments_rounded, _kOrange,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => AdminRevenueDetailPage(totalRevenue: _revenue))),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        _statCard(
                          'عمولة المنصة',
                          '${_platformFees.toStringAsFixed(0)} ج.م',
                          Icons.account_balance_wallet_rounded, _kGreen,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => AdminCommissionDetailPage(totalCommission: _platformFees))),
                        ),
                        const SizedBox(width: 12),
                        _statCard(
                          'حجوزات معلقة',
                          '$_pendingBookings',
                          Icons.schedule_rounded, _kRed,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AdminBookingsPage(initialFilter: 'في الانتظار'))),
                        ),
                      ]),
                    ]),
                  ),
          ),

          // ── Pending Alert ──────────────────────────────────
          if (!_loading && _pendingCount > 0)
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminPendingPage())),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _kOrange.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _kOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.pending_actions_rounded,
                          color: _kOrange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$_pendingCount عقار في انتظار الموافقة',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _kOrange)),
                          const SizedBox(height: 2),
                          Text('اضغط للمراجعة والموافقة',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: context.kSub)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: _kOrange, size: 14),
                  ]),
                ),
              ),
            ),

          // ── Management Tiles ───────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text('الإدارة',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: context.kText)),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                _navTile(
                  icon: Icons.apartment_rounded,
                  title: 'إدارة العقارات',
                  subtitle: 'عرض وتعديل وحذف كل العقارات',
                  color: _kOcean,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminPropertiesPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.calendar_month_rounded,
                  title: 'إدارة الحجوزات',
                  subtitle: 'تأكيد أو إلغاء الحجوزات',
                  color: _kGreen,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminBookingsPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.people_alt_rounded,
                  title: 'إدارة المستخدمين',
                  subtitle: 'تغيير الصلاحيات، التفعيل، التوثيق',
                  color: _kPurple,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminUsersPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.home_work_rounded,
                  title: 'إدارة الملاك',
                  subtitle: 'عقارات، تقييمات، وإيرادات كل مالك',
                  color: _kOcean,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminOwnersPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.pending_actions_rounded,
                  title: 'العقارات المعلقة',
                  subtitle: _pendingCount > 0
                      ? '$_pendingCount عقار في انتظار الموافقة'
                      : 'موافقة أو رفض العقارات الجديدة',
                  color: _kOrange,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminPendingPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.report_rounded,
                  title: 'البلاغات والنزاعات',
                  subtitle: 'حل شكاوى المستخدمين',
                  color: _kRed,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminReportsPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.local_offer_rounded,
                  title: 'أكواد الخصم',
                  subtitle: 'إنشاء وإدارة أكواد البروموشن',
                  color: _kGreen,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminPromoCodesPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'دفعات المضيفين',
                  subtitle: 'تجميع + دفع مستحقات الملاك',
                  color: _kOrange,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminPayoutsPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.move_to_inbox_rounded,
                  title: 'طلبات السحب',
                  subtitle: 'موافقة أو رفض طلبات سحب أرباح الملاك',
                  color: _kGreen,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdminWithdrawalRequestsPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.savings_rounded,
                  title: 'إدارة المحافظ',
                  subtitle: 'رصيد المستخدمين، تعديل يدوي، سجل المعاملات',
                  color: _kGreen,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdminWalletManagementPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.history_rounded,
                  title: 'سجل الإجراءات',
                  subtitle: 'من فعل ماذا ومتى — forensic audit log',
                  color: _kRed,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminAuditLogPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.analytics_rounded,
                  title: 'الإحصائيات التفصيلية',
                  subtitle: 'إيرادات، عمولات، نسب نمو',
                  color: _kPurple,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminStatsPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.insights_rounded,
                  title: 'التحليلات المتقدمة',
                  subtitle: 'رسوم بيانية، أعلى المناطق، و KPIs',
                  color: _kOcean,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdminAnalyticsDashboardPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.bar_chart_rounded,
                  title: 'التقرير المالي',
                  subtitle: 'إيرادات شهرية، عمولات، مستحقات الملاك',
                  color: _kGreen,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdminFinancialReportPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'البحث بالكود',
                  subtitle: 'بحث بكود العقار أو كود الحجز — بيانات كاملة + صور الهوية',
                  color: _kPurple,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdminCodeLookupPage())),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, right: 4),
                  child: Text('الإدارة التشغيلية',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: context.kSub)),
                ),
                _navTile(
                  icon: Icons.rate_review_rounded,
                  title: 'إدارة التقييمات',
                  subtitle: 'حذف التعليقات المسيئة',
                  color: _kRed,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdminReviewsModerationPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.photo_library_rounded,
                  title: 'إشراف بوستات الرحلات',
                  subtitle: 'إخفاء أو حذف بوستات مسيئة من الفيد',
                  color: _kOcean,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdminTripPostsModerationPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.block_rounded,
                  title: 'تعليق العقارات',
                  subtitle: 'تعليق أو رفع تعليق عن عقار بشكل مؤقت',
                  color: _kRed,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdminPropertySuspensionPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'الاستردادات و التعويضات',
                  subtitle: 'رد الأموال للضيوف',
                  color: _kGreen,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminRefundsPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.gavel_rounded,
                  title: 'النزاعات',
                  subtitle: 'حل البلاغات المتعلقة بحجوزات',
                  color: _kOrange,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminDisputesPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.campaign_rounded,
                  title: 'الإشعارات الجماعية',
                  subtitle: 'بث push notifications',
                  color: _kPurple,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminNotificationsPage())),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, right: 4),
                  child: Text('التوثيق و التحقق',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: context.kSub)),
                ),
                _navTile(
                  icon: Icons.verified_user_rounded,
                  title: 'توثيق المضيفين',
                  subtitle: 'اعتماد وثائق ملكية العقارات',
                  color: _kOcean,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdminHostVerificationPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.badge_rounded,
                  title: 'توثيق هوية المستخدمين (KYC)',
                  subtitle: 'مراجعة بطاقات و سيلفي',
                  color: _kPurple,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminKycPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.shield_rounded,
                  title: 'كشف الاحتيال',
                  subtitle: 'حسابات مشبوهة و تعطيل',
                  color: _kRed,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdminFraudDetectionPage())),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, right: 4),
                  child: Text('التسويق و السياسات',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: context.kSub)),
                ),
                _navTile(
                  icon: Icons.star_rounded,
                  title: 'العقارات المميزة',
                  subtitle: 'تحديد عقارات الواجهة الرئيسية',
                  color: _kOrange,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdminFeaturedListingsPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.tune_rounded,
                  title: 'قواعد التسعير و العمولة',
                  subtitle: 'عمولة المنصة، العربون، الإحالات',
                  color: _kGreen,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdminPricingRulesPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.image_rounded,
                  title: 'بانرات الواجهة الرئيسية',
                  subtitle: 'بانرات تسويقية مجدولة',
                  color: _kOcean,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdminPromoBannerPage())),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, right: 4),
                  child: Text('المراقبة و التكامل',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: context.kSub)),
                ),
                _navTile(
                  icon: Icons.shield_moon_rounded,
                  title: 'مراقبة المحادثات',
                  subtitle: 'رسائل مفلترة و إخفاء الإساءات',
                  color: _kRed,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdminChatMonitorPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.flag_rounded,
                  title: 'Feature Flags / A-B Testing',
                  subtitle: 'إدارة التجارب و الـ rollouts',
                  color: _kPurple,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminAbTestingPage())),
                ),
                const SizedBox(height: 10),
                _navTile(
                  icon: Icons.vpn_key_rounded,
                  title: 'مفاتيح API للشركاء',
                  subtitle: 'إنشاء، تدوير، و إلغاء',
                  color: _kOrange,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminApiKeysPage())),
                ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── Stat Card ──────────────────────────────────────────────
  Widget _statCard(
      String label, String value, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap();
              },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.kBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: context.kText)),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.kSub)),
              ),
              if (onTap != null)
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 10, color: color.withValues(alpha: 0.6)),
            ]),
          ]),
        ),
      ),
    );
  }

  // ── Navigation Tile ────────────────────────────────────────
  Widget _navTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.kBorder),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.kText)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: context.kSub)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              color: context.kSub, size: 14),
        ]),
      ),
    );
  }
}
