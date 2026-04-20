// ═══════════════════════════════════════════════════════════════
//  TALAA — Host Dashboard Page  (Owner Home)
//  Lottie house animation + 3 premium action buttons
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../widgets/constants.dart';
import 'owner_add_property_page.dart';
import 'owner_analytics_page.dart';
import 'owner_dashboard_page.dart';
import 'bookings_page.dart';
import 'host_payouts_page.dart';

const _kOcean  = Color(0xFF1565C0);
const _kGreen  = Color(0xFF22C55E);
const _kOrange = Color(0xFFFF6D00);
const _kPurple = Color(0xFF7C3AED);
const _kTeal   = Color(0xFF0891B2);

class HostDashboardPage extends StatelessWidget {
  const HostDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final animHeight = (mq.size.height * 0.28).clamp(160.0, 260.0);

    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: context.kCard,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: context.kText, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('لوحة المضيف',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: mq.size.width * 0.06,
            vertical: 16,
          ),
          child: Column(children: [
            // ── Lottie Animation ───────────────────────────
            SizedBox(
              height: animHeight,
              child: Lottie.asset(
                'assets/animations/House.json',
                fit: BoxFit.contain,
                frameRate: FrameRate.max,
              ),
            ),

            const SizedBox(height: 8),

            // ── Welcome text ──────────────────────────────
            Text('أهلاً بيك في لوحة المضيف',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: context.kText)),
            const SizedBox(height: 6),
            Text('أدر عقاراتك وحجوزاتك بسهولة',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.kSub)),

            const SizedBox(height: 28),

            // ── Action Buttons ────────────────────────────
            _ActionButton(
              icon: Icons.add_home_rounded,
              label: 'إضافة عقار',
              subtitle: 'أضف شاليه، فيلا أو فندق جديد',
              color: _kOcean,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OwnerAddPropertyPage()),
                );
              },
            ),
            const SizedBox(height: 14),
            _ActionButton(
              icon: Icons.apartment_rounded,
              label: 'عقاراتي',
              subtitle: 'إدارة وتعديل عقاراتك المسجلة',
              color: _kGreen,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OwnerDashboardPage()),
                );
              },
            ),
            const SizedBox(height: 14),
            _ActionButton(
              icon: Icons.calendar_month_rounded,
              label: 'حجوزاتي',
              subtitle: 'تتبع حجوزات الضيوف وإيراداتك',
              color: _kOrange,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BookingsPage()),
                );
              },
            ),
            const SizedBox(height: 14),
            _ActionButton(
              icon: Icons.insights_rounded,
              label: 'التحليلات',
              subtitle: 'الأرباح، الإشغال، وأفضل عقاراتك',
              color: _kPurple,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OwnerAnalyticsPage()),
                );
              },
            ),
            const SizedBox(height: 14),
            _ActionButton(
              icon: Icons.account_balance_wallet_rounded,
              label: 'أرباحي والتحويلات',
              subtitle: 'الرصيد المستحق، الحسابات البنكية، سجل السحب',
              color: _kTeal,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const HostPayoutsPage()),
                );
              },
            ),

            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }
}

// ── Premium Action Button ────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.kBorder),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          // Icon container
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: context.kText)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.kSub)),
              ],
            ),
          ),

          // Arrow
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_forward_ios_rounded,
                color: color, size: 14),
          ),
        ]),
      ),
    );
  }
}
