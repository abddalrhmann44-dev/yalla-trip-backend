// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Fraud Detection Page  (Wave 30)
//
//  Triage queue of accounts whose recent activity is *abnormally*
//  costly to the platform — high cancellation rate, repeated
//  refunds, multiple pending reports, or rejected KYC submissions.
//
//  The risk score is calculated server-side; the page displays each
//  contributing signal so the admin can sanity-check before acting
//  (the only "destructive" action wired in is **Deactivate**, which
//  hits the existing ``DELETE /admin/users/{id}`` endpoint).
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/admin_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';

const _kOcean = Color(0xFFFF6B35);
const _kRed = Color(0xFFEF5350);
const _kGreen = Color(0xFF4CAF50);
const _kAmber = Color(0xFFFFB300);

class AdminFraudDetectionPage extends StatefulWidget {
  const AdminFraudDetectionPage({super.key});
  @override
  State<AdminFraudDetectionPage> createState() =>
      _AdminFraudDetectionPageState();
}

class _AdminFraudDetectionPageState extends State<AdminFraudDetectionPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  int _threshold = 30;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await AdminService.getFraudFlags(threshold: _threshold);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التحميل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deactivate(int userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تعطيل الحساب',
            style: TextStyle(
                fontWeight: FontWeight.w900, color: _kRed)),
        content: const Text(
            'هل أنت متأكد من تعطيل هذا الحساب؟ لن يستطيع المستخدم تسجيل الدخول حتى يتم إعادة تفعيله.',
            style: TextStyle(fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء',
                style: TextStyle(
                    color: context.kSub, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('تعطيل',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    HapticFeedback.lightImpact();
    setState(() => _busy.add(userId));
    try {
      await AdminService.deactivateUser(userId);
      if (!mounted) return;
      setState(() => _items.removeWhere((x) => x['user_id'] == userId));
      _snack('تم تعطيل الحساب', _kGreen);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التعطيل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busy.remove(userId));
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  Color _riskColor(String label) => switch (label) {
        'high' => _kRed,
        'medium' => _kAmber,
        _ => _kOcean,
      };
  String _riskAr(String label) => switch (label) {
        'high' => 'مرتفع',
        'medium' => 'متوسط',
        _ => 'منخفض',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('كشف الاحتيال',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: _kOcean.withValues(alpha: 0.05),
          child: Row(children: [
            const Icon(Icons.tune_rounded, color: _kOcean, size: 18),
            const SizedBox(width: 8),
            Text('عتبة الخطورة:',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.kSub,
                    fontSize: 12)),
            Expanded(
              child: Slider(
                value: _threshold.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: '$_threshold',
                activeColor: _kOcean,
                onChanged: (v) => setState(() => _threshold = v.toInt()),
                onChangeEnd: (_) => _load(),
              ),
            ),
            Text('$_threshold',
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _kOcean,
                    fontSize: 13)),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _kOcean))
              : RefreshIndicator(
                  color: _kOcean,
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 100),
                            Icon(Icons.shield_rounded,
                                size: 64,
                                color: _kGreen.withValues(alpha: 0.6)),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                  'لا توجد حسابات مشبوهة عند هذه العتبة 🛡️',
                                  style: TextStyle(
                                      color: context.kSub,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(12, 12, 12, 100),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final r = _items[i];
                            final color = _riskColor(
                                (r['risk_label'] as String?) ?? 'low');
                            final score = (r['risk_score'] as num? ?? 0)
                                .toInt();
                            final uid = (r['user_id'] as num).toInt();
                            return Container(
                              decoration: BoxDecoration(
                                color: context.kCard,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.5)),
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            color.withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                          Icons.warning_amber_rounded,
                                          color: color,
                                          size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              r['user_name'] as String? ??
                                                  'مستخدم #$uid',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight:
                                                      FontWeight.w900,
                                                  color: context.kText)),
                                          Text(
                                              '#$uid • ${r['user_phone'] ?? r['user_email'] ?? '—'}',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: context.kSub,
                                                  fontWeight:
                                                      FontWeight.w500)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color:
                                            color.withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Column(children: [
                                        Text('$score',
                                            style: TextStyle(
                                                color: color,
                                                fontSize: 14,
                                                fontWeight:
                                                    FontWeight.w900)),
                                        Text(
                                            _riskAr(r['risk_label']
                                                    as String? ??
                                                'low'),
                                            style: TextStyle(
                                                color: color,
                                                fontSize: 9,
                                                fontWeight:
                                                    FontWeight.w800)),
                                      ]),
                                    ),
                                  ]),
                                  const SizedBox(height: 10),
                                  Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        _signal(
                                            'إلغاءات',
                                            r['cancelled_bookings']),
                                        _signal(
                                            'استرداد',
                                            r['refunded_bookings']),
                                        _signal(
                                            'بلاغات',
                                            r['pending_reports_against']),
                                        _signal('KYC مرفوض',
                                            r['rejected_kycs']),
                                        if (!(r['is_active'] as bool? ??
                                            true))
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _kRed.withValues(
                                                  alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text('معطل',
                                                style: TextStyle(
                                                    color: _kRed,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                          ),
                                      ]),
                                  if ((r['is_active'] as bool? ?? true)) ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _busy.contains(uid)
                                            ? null
                                            : () => _deactivate(uid),
                                        icon: _busy.contains(uid)
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: _kRed))
                                            : const Icon(
                                                Icons.block_rounded,
                                                color: _kRed,
                                                size: 16),
                                        label: const Text('تعطيل الحساب',
                                            style: TextStyle(
                                                color: _kRed,
                                                fontWeight:
                                                    FontWeight.w800)),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                              color: _kRed.withValues(
                                                  alpha: 0.5)),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 11),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(11)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
        ),
      ]),
    );
  }

  Widget _signal(String label, dynamic value) {
    final v = (value as num? ?? 0).toInt();
    if (v == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.kSand.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $v',
          style: TextStyle(
              color: context.kSub,
              fontSize: 10,
              fontWeight: FontWeight.w700)),
    );
  }
}
