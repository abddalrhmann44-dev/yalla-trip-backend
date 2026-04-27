// ═══════════════════════════════════════════════════════════════
//  TALAA — Host "Today" Tab
//
//  The first thing a host sees after switching to host mode.  Pulls
//  /properties/mine/stats once — a single aggregated round-trip the
//  backend computes via Postgres FILTER aggregation — and surfaces
//  the four metrics hosts ask about every day:
//
//    • Revenue (last 30 days + lifetime)
//    • Upcoming bookings
//    • Listing health (active count, avg rating, review count)
//    • KYC alerts (listings missing ID documents)
//
//  Design ethos: Airbnb-style hero number for revenue, supporting
//  cards for the rest, FAB-style "إضافة عقار" for the primary CTA.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/property_service.dart';
import '../widgets/constants.dart';
import 'host_payouts_page.dart';
import 'host_reservations_page.dart';
import 'owner_add_property_page.dart';
import 'owner_analytics_page.dart';

const _kOcean = Color(0xFFFF6B35);
const _kGreen = Color(0xFF22C55E);
const _kAmber = Color(0xFFF59E0B);
const _kPurple = Color(0xFF7C3AED);

class HostTodayTab extends StatefulWidget {
  const HostTodayTab({super.key});

  @override
  State<HostTodayTab> createState() => _HostTodayTabState();
}

class _HostTodayTabState extends State<HostTodayTab> {
  MyPropertiesStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await PropertyService.getMyStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  String _fmtMoney(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)} م';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)} ك';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: _kOcean,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: _kOcean),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _errorView(),
                )
              else
                SliverToBoxAdapter(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB54414), _kOcean, Color(0xFFFF8A3D)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.waving_hand_rounded,
                  color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('أهلاً بيك',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'لوحة المضيف',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          _buildHeroRevenue(),
        ],
      ),
    );
  }

  Widget _buildHeroRevenue() {
    final stats = _stats;
    final revenue30d = stats?.revenue30d ?? 0;
    final revenueAllTime = stats?.revenueAllTime ?? 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إيرادات آخر 30 يوم',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _loading ? '…' : _fmtMoney(revenue30d),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('ج.م',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.trending_up_rounded,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                'إجمالى الأرباح: ${_fmtMoney(revenueAllTime)} ج.م',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final stats = _stats!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KYC alert (only when something needs doing)
          if (stats.pendingKyc > 0) _buildKycAlert(stats.pendingKyc),
          if (stats.pendingKyc > 0) const SizedBox(height: 16),

          _sectionTitle('نظرة سريعة'),
          const SizedBox(height: 10),
          _buildStatGrid(stats),

          const SizedBox(height: 24),
          _sectionTitle('إجراءات سريعة'),
          const SizedBox(height: 10),
          _buildQuickActions(),

          const SizedBox(height: 24),
          _buildAddPropertyCard(),
        ],
      ),
    );
  }

  Widget _buildKycAlert(int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kAmber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kAmber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kAmber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: _kAmber, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('فيه $count عقار محتاج تأكيد هوية',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: context.kText)),
                const SizedBox(height: 2),
                Text('ارفع البطاقة عشان يقدر يستقبل حجوزات',
                    style: TextStyle(fontSize: 11, color: context.kSub)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(MyPropertiesStats stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _statCard(
          icon: Icons.calendar_month_rounded,
          color: _kOcean,
          value: '${stats.upcomingBookings}',
          label: 'حجوزات قادمة',
        ),
        _statCard(
          icon: Icons.apartment_rounded,
          color: _kGreen,
          value: '${stats.activeProperties}/${stats.totalProperties}',
          label: 'عقارات مفعّلة',
        ),
        _statCard(
          icon: Icons.star_rounded,
          color: const Color(0xFFFFC107),
          value: stats.avgRating > 0 ? stats.avgRating.toStringAsFixed(1) : '—',
          label: 'متوسط التقييم',
        ),
        _statCard(
          icon: Icons.rate_review_rounded,
          color: _kPurple,
          value: '${stats.totalReviews}',
          label: 'مراجعات الضيوف',
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: context.kText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: context.kSub),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        _actionRow(
          icon: Icons.payments_rounded,
          color: _kGreen,
          title: 'استلام الكاش',
          subtitle: 'أكد استلام الباقى من الضيوف',
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const HostReservationsPage()),
            );
          },
        ),
        const SizedBox(height: 10),
        _actionRow(
          icon: Icons.insights_rounded,
          color: _kPurple,
          title: 'التحليلات',
          subtitle: 'الإيرادات، الإشغال، أفضل عقاراتك',
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OwnerAnalyticsPage()),
            );
          },
        ),
        const SizedBox(height: 10),
        _actionRow(
          icon: Icons.account_balance_rounded,
          color: const Color(0xFF0891B2),
          title: 'الحساب البنكى',
          subtitle: 'إدارة طرق استلام الأرباح',
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HostPayoutsPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _actionRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: context.kCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.kBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
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
                        style:
                            TextStyle(fontSize: 11, color: context.kSub)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: context.kSub),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddPropertyCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          HapticFeedback.lightImpact();
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OwnerAddPropertyPage()),
          );
          _load();
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kOcean, Color(0xFFFF8A3D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _kOcean.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add_home_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('أضف عقار جديد',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text('شاليه، فيلا، فندق أو مركب',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String s) {
    return Row(children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          color: _kOcean,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 8),
      Text(s,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: context.kText)),
    ]);
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text('فشل تحميل البيانات',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: context.kText)),
            const SizedBox(height: 6),
            Text(
              _error ?? 'حاول مرة تانية',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.kSub),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kOcean,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
