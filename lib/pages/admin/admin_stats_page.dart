// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Stats Details
//  Detailed platform KPIs: users, properties, bookings, revenue.
//  Data from /admin/stats.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../services/admin_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';

const _kOcean  = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF4CAF50);
const _kOrange = Color(0xFFFF6D00);
const _kPurple = Color(0xFF7E57C2);
const _kRed    = Color(0xFFEF5350);

class AdminStatsPage extends StatefulWidget {
  const AdminStatsPage({super.key});
  @override
  State<AdminStatsPage> createState() => _AdminStatsPageState();
}

class _AdminStatsPageState extends State<AdminStatsPage> {
  Map<String, dynamic>? _stats;
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
      final stats = await AdminService.getStats();
      if (mounted) setState(() => _stats = stats);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = ErrorHandler.getMessage(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'حصل خطأ، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(num n) {
    final s = n.toStringAsFixed(n is int || n == n.toInt() ? 0 : 2);
    return s.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: context.kCard,
        elevation: 0,
        title: Text('الإحصائيات التفصيلية',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOcean))
          : _error != null
              ? _errorState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _kOcean,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _section('المستخدمون', _kPurple, [
                        _row('إجمالي المستخدمين', _fmt(_stats!['total_users'] ?? 0),
                            Icons.people_alt_rounded),
                        _row('مستخدمون مُفعّلون',
                            _fmt(_stats!['active_users'] ?? 0),
                            Icons.check_circle_rounded),
                        _row('ملاك العقارات',
                            _fmt(_stats!['total_owners'] ?? 0),
                            Icons.apartment_rounded),
                        _row('مشرفون', _fmt(_stats!['total_admins'] ?? 0),
                            Icons.admin_panel_settings_rounded),
                      ]),
                      const SizedBox(height: 12),
                      _section('العقارات', _kOcean, [
                        _row('إجمالي العقارات',
                            _fmt(_stats!['total_properties'] ?? 0),
                            Icons.apartment_rounded),
                        _row('معتمدة',
                            _fmt(_stats!['approved_properties'] ?? 0),
                            Icons.verified_rounded,
                            color: _kGreen),
                        _row('في انتظار الموافقة',
                            _fmt(_stats!['pending_properties'] ?? 0),
                            Icons.pending_actions_rounded,
                            color: _kOrange),
                        _row('مرفوضة',
                            _fmt(_stats!['rejected_properties'] ?? 0),
                            Icons.cancel_rounded,
                            color: _kRed),
                      ]),
                      const SizedBox(height: 12),
                      _section('الحجوزات', _kGreen, [
                        _row('إجمالي الحجوزات',
                            _fmt(_stats!['total_bookings'] ?? 0),
                            Icons.calendar_month_rounded),
                        _row('مؤكدة/مكتملة',
                            _fmt(_stats!['confirmed_bookings'] ?? 0),
                            Icons.event_available_rounded,
                            color: _kGreen),
                        _row('في الانتظار',
                            _fmt(_stats!['pending_bookings'] ?? 0),
                            Icons.schedule_rounded,
                            color: _kOrange),
                        _row('ملغاة',
                            _fmt(_stats!['cancelled_bookings'] ?? 0),
                            Icons.event_busy_rounded,
                            color: _kRed),
                      ]),
                      const SizedBox(height: 12),
                      _section('المالية', _kOrange, [
                        _row(
                            'إجمالي الإيرادات',
                            '${_fmt((_stats!['total_revenue'] ?? 0).toDouble())} ج.م',
                            Icons.payments_rounded,
                            bold: true),
                        _row(
                            'عمولة المنصة',
                            '${_fmt((_stats!['total_platform_fees'] ?? 0).toDouble())} ج.م',
                            Icons.account_balance_wallet_rounded,
                            color: _kGreen),
                        _row(
                            'مدفوعات الملاك',
                            '${_fmt((_stats!['total_owner_payouts'] ?? 0).toDouble())} ج.م',
                            Icons.account_balance_rounded,
                            color: _kPurple),
                      ]),
                      const SizedBox(height: 12),
                      _section('التفاعل', _kPurple, [
                        _row('إجمالي التقييمات',
                            _fmt(_stats!['total_reviews'] ?? 0),
                            Icons.star_rounded,
                            color: _kOrange),
                      ]),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _section(String title, Color color, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 8,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: context.kText)),
          ]),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value, IconData icon,
      {Color? color, bool bold = false}) {
    final c = color ?? context.kSub;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.kText)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 16 : 14,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
                color: bold ? c : context.kText)),
      ]),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 56, color: _kRed.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              Text(_error ?? 'حصل خطأ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.kText)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
}
