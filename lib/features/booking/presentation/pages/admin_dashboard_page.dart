// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Admin Dashboard
//  Analytics: total bookings, revenue, owner earnings, trends
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/constants.dart';
import '../providers/booking_providers.dart';
import '../widgets/booking_card_widget.dart';
import 'admin_promo_manager_page.dart';
import 'admin_financial_settings_page.dart';

const _kOcean  = Color(0xFF1565C0);
const _kGreen  = Color(0xFF4CAF50);
const _kOrange = Color(0xFFFF6D00);
const _kPurple = Color(0xFF7E57C2);

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(allBookingsStreamProvider);
    final feeAsync = ref.watch(appFeeStreamProvider);

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
        title: Text('لوحة الإدارة',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        centerTitle: true,
      ),
      body: bookingsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kOcean)),
        error: (e, _) => Center(
            child: Text('خطأ: $e',
                style: TextStyle(color: context.kSub))),
        data: (bookings) {
          final totalBookings = bookings.length;
          final totalRevenue =
              bookings.fold<double>(0, (s, b) => s + b.appFeeAmount);
          final totalOwnerEarnings =
              bookings.fold<double>(0, (s, b) => s + b.ownerEarnings);
          final totalVolume =
              bookings.fold<double>(0, (s, b) => s + b.finalPrice);
          final promoUsage =
              bookings.where((b) => b.promoCodeUsed.isNotEmpty).length;
          final appFee = feeAsync.valueOrNull ?? 10.0;

          // Last 7 days trend
          final now = DateTime.now();
          final weekAgo = now.subtract(const Duration(days: 7));
          final recentBookings =
              bookings.where((b) => b.createdAt.isAfter(weekAgo)).length;

          return ListView(padding: const EdgeInsets.all(16), children: [
            // ── Stats grid ──────────────────────────────────
            _statsGrid(context, totalBookings, totalRevenue,
                totalOwnerEarnings, totalVolume, promoUsage,
                recentBookings),
            const SizedBox(height: 20),

            // ── Quick actions ───────────────────────────────
            _sectionLabel(context, 'إدارة'),
            const SizedBox(height: 12),
            Row(children: [
              _actionTile(context, '🏷️', 'أكواد الخصم', _kOrange, () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const AdminPromoManagerPage()));
              }),
              const SizedBox(width: 12),
              _actionTile(context, '⚙️', 'رسوم المنصة', _kPurple, () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AdminFinancialSettingsPage(
                            currentFee: appFee)));
              }),
            ]),
            const SizedBox(height: 24),

            // ── Recent bookings ─────────────────────────────
            _sectionLabel(context, 'آخر الحجوزات'),
            const SizedBox(height: 12),
            if (bookings.isEmpty)
              Center(
                  child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('لا توجد حجوزات بعد',
                    style: TextStyle(
                        fontSize: 14, color: context.kSub)),
              ))
            else
              ...bookings.take(10).map((b) => BookingCardWidget(
                    booking: b,
                    showOwnerEarnings: true,
                  )),
          ]);
        },
      ),
    );
  }

  Widget _statsGrid(
    BuildContext context,
    int totalBookings,
    double totalRevenue,
    double totalOwnerEarnings,
    double totalVolume,
    int promoUsage,
    int recentBookings,
  ) {
    return Column(children: [
      Row(children: [
        _stat(context, 'إجمالي الحجوزات', '$totalBookings', _kOcean,
            Icons.calendar_today_rounded),
        const SizedBox(width: 12),
        _stat(context, 'إيرادات المنصة',
            '${totalRevenue.toStringAsFixed(0)} جنيه', _kGreen,
            Icons.account_balance_rounded),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _stat(context, 'أرباح الملاك',
            '${totalOwnerEarnings.toStringAsFixed(0)} جنيه', _kOrange,
            Icons.people_rounded),
        const SizedBox(width: 12),
        _stat(context, 'حجم التداول',
            '${totalVolume.toStringAsFixed(0)} جنيه', _kPurple,
            Icons.trending_up_rounded),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _stat(context, 'استخدام أكواد الخصم', '$promoUsage', _kOrange,
            Icons.local_offer_rounded),
        const SizedBox(width: 12),
        _stat(context, 'حجوزات آخر 7 أيام', '$recentBookings', _kOcean,
            Icons.show_chart_rounded),
      ]),
    ]);
  }

  Widget _stat(BuildContext context, String label, String value,
          Color color, IconData icon) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: context.kSub)),
          ]),
        ),
      );

  Widget _sectionLabel(BuildContext context, String text) => Text(text,
      style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: context.kText));

  Widget _actionTile(BuildContext context, String emoji, String label,
          Color color, VoidCallback onTap) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.kText)),
              ),
              Icon(Icons.chevron_left_rounded,
                  size: 20, color: context.kSub),
            ]),
          ),
        ),
      );
}
