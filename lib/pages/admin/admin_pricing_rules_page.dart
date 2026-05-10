// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Pricing Rules Page  (Wave 30)
//
//  Edit the global platform tunables backing the booking pricing
//  engine, deposit policy, payout schedule, wallet redemption guard,
//  and referral rewards.  Stored in the singleton
//  ``platform_settings`` table; every change is audit-logged.
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

class AdminPricingRulesPage extends StatefulWidget {
  const AdminPricingRulesPage({super.key});
  @override
  State<AdminPricingRulesPage> createState() =>
      _AdminPricingRulesPageState();
}

class _AdminPricingRulesPageState extends State<AdminPricingRulesPage> {
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _initial;
  String? _updatedAt;
  String? _updatedBy;

  // Each setting gets its own controller so unsaved edits stay
  // local until the admin taps Save.
  final _fee = TextEditingController();
  final _deposit = TextEditingController();
  final _holdDays = TextEditingController();
  final _walletMin = TextEditingController();
  final _refReward = TextEditingController();
  final _refCap = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _fee,
      _deposit,
      _holdDays,
      _walletMin,
      _refReward,
      _refCap,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await AdminService.getPlatformSettings();
      _initial = data;
      _fee.text = '${data['platform_fee_percent'] ?? 10}';
      _deposit.text = '${data['deposit_percent_default'] ?? 20}';
      _holdDays.text = '${data['payout_hold_days'] ?? 1}';
      _walletMin.text = '${data['wallet_min_redeem_subtotal'] ?? 3000}';
      _refReward.text = '${data['referral_reward_egp'] ?? 100}';
      _refCap.text = '${data['referral_reward_cap'] ?? 3}';
      _updatedAt = data['updated_at'] as String?;
      _updatedBy = data['updated_by_name'] as String?;
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التحميل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _diff() {
    final out = <String, dynamic>{};
    void check(String key, TextEditingController c, bool isInt) {
      final txt = c.text.trim();
      if (txt.isEmpty) return;
      final num? parsed = isInt ? int.tryParse(txt) : double.tryParse(txt);
      if (parsed == null) return;
      final original = (_initial?[key] as num?)?.toDouble();
      if (original == null || original.toString() != parsed.toString()) {
        if ((parsed.toDouble() - (original ?? double.nan)).abs() > 1e-6 ||
            original == null) {
          out[key] = parsed;
        }
      }
    }

    check('platform_fee_percent', _fee, false);
    check('deposit_percent_default', _deposit, false);
    check('payout_hold_days', _holdDays, true);
    check('wallet_min_redeem_subtotal', _walletMin, false);
    check('referral_reward_egp', _refReward, false);
    check('referral_reward_cap', _refCap, true);
    return out;
  }

  Future<void> _save() async {
    final changes = _diff();
    if (changes.isEmpty) {
      _snack('لا يوجد تغييرات للحفظ', _kRed);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد الحفظ',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('سيتم تحديث الإعدادات التالية:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...changes.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• ${_arabicLabel(e.key)} → ${e.value}',
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
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
              backgroundColor: _kGreen,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('حفظ',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _saving = true);
    try {
      final data = await AdminService.updatePlatformSettings(
        changes,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      _initial = data;
      _updatedAt = data['updated_at'] as String?;
      _updatedBy = data['updated_by_name'] as String?;
      _note.clear();
      _snack('تم حفظ الإعدادات ✅', _kGreen);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل الحفظ: $e', _kRed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _arabicLabel(String key) => switch (key) {
        'platform_fee_percent' => 'عمولة المنصة (%)',
        'deposit_percent_default' => 'العربون الافتراضي (%)',
        'payout_hold_days' => 'مدة احتجاز الدفع (يوم)',
        'wallet_min_redeem_subtotal' => 'حد محفظة الاسترداد (ج.م)',
        'referral_reward_egp' => 'مكافأة الإحالة (ج.م)',
        'referral_reward_cap' => 'حد مكافآت الإحالة',
        _ => key,
      };

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('قواعد التسعير والعمولة',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOcean))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_updatedAt != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _kOcean.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _kOcean.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.history_rounded,
                          color: _kOcean, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'آخر تعديل بواسطة ${_updatedBy ?? '—'}\n$_updatedAt',
                          style: const TextStyle(
                              color: _kOcean,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                _section('الإيرادات والعمولات'),
                _numberField(
                  controller: _fee,
                  label: 'عمولة المنصة (%)',
                  hint: '10',
                  suffix: '%',
                  description:
                      'النسبة التي تأخذها المنصة من كل حجز مدفوع.',
                ),
                const SizedBox(height: 12),
                _numberField(
                  controller: _deposit,
                  label: 'العربون الافتراضي (%)',
                  hint: '20',
                  suffix: '%',
                  description:
                      'النسبة الافتراضية للعربون عندما لا يحدد المضيف نسبته الخاصة.',
                ),
                const SizedBox(height: 24),
                _section('دفعات المضيفين'),
                _numberField(
                  controller: _holdDays,
                  label: 'مدة الاحتجاز قبل الدفع (يوم)',
                  hint: '1',
                  isInt: true,
                  description:
                      'عدد الأيام بعد المغادرة قبل الإفراج عن مستحقات المضيف. كلما زاد، كلما طالت نافذة النزاع.',
                ),
                const SizedBox(height: 24),
                _section('المحفظة والإحالات'),
                _numberField(
                  controller: _walletMin,
                  label: 'حد استخدام المحفظة (ج.م)',
                  hint: '3000',
                  suffix: 'ج.م',
                  description:
                      'أقل قيمة فاتورة تسمح للضيف باستخدام رصيد المحفظة.',
                ),
                const SizedBox(height: 12),
                _numberField(
                  controller: _refReward,
                  label: 'مكافأة الإحالة (ج.م)',
                  hint: '100',
                  suffix: 'ج.م',
                  description:
                      'القيمة التي تُضاف لمحفظة المُحيل بعد إنجاز إحالة جديدة.',
                ),
                const SizedBox(height: 12),
                _numberField(
                  controller: _refCap,
                  label: 'حد عدد مكافآت الإحالة',
                  hint: '3',
                  isInt: true,
                  description:
                      'أكبر عدد من الإحالات المكافَأة لكل مستخدم — يمنع لوبات الاحتيال.',
                ),
                const SizedBox(height: 24),
                _section('سبب التغيير (اختياري)'),
                TextField(
                  controller: _note,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText:
                        'مثلاً: تخفيض العمولة لزيادة الجاذبية في الموسم الصيفي',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded,
                          color: Colors.white, size: 18),
                  label: const Text('حفظ التغييرات',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kOcean,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: _kOcean)),
      );

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? suffix,
    String? description,
    bool isInt = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
          inputFormatters: [
            isInt
                ? FilteringTextInputFormatter.digitsOnly
                : FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            suffixText: suffix,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kOcean, width: 2),
            ),
          ),
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4, left: 4),
            child: Text(description,
                style: TextStyle(
                    fontSize: 11,
                    color: context.kSub,
                    height: 1.4,
                    fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }
}
