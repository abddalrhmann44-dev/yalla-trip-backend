// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Promo Codes Page
//  Create + list + delete promo codes, see usage stats at a glance.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../services/promo_code_service.dart';
import '../../widgets/constants.dart';

class AdminPromoCodesPage extends StatefulWidget {
  const AdminPromoCodesPage({super.key});
  @override
  State<AdminPromoCodesPage> createState() => _AdminPromoCodesPageState();
}

class _AdminPromoCodesPageState extends State<AdminPromoCodesPage> {
  List<PromoCodeModel> _codes = [];
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
      final results = await Future.wait([
        PromoCodeService.adminList(limit: 200),
        PromoCodeService.adminStatsOverview(),
      ]);
      _codes = results[0] as List<PromoCodeModel>;
      _stats = results[1] as Map<String, dynamic>;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<PromoCodeModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreatePromoSheet(),
    );
    if (created != null) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم إنشاء الكود ${created.code}'),
          backgroundColor: Colors.green,
        ));
      }
    }
  }

  Future<void> _confirmDelete(PromoCodeModel promo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف كود الخصم'),
        content: Text(
          'هل أنت متأكد من حذف الكود "${promo.code}"؟\n'
          '${promo.usesCount > 0 ? "تم استخدامه ${promo.usesCount} مرة — سيتم حذف سجل الاستخدام كذلك." : "الكود غير مستخدم."}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PromoCodeService.adminDelete(promo.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('فشل الحذف: $e'),
        backgroundColor: const Color(0xFFE53935),
      ));
    }
  }

  Future<void> _toggleActive(PromoCodeModel promo) async {
    try {
      await PromoCodeService.adminUpdate(
        promo.id, isActive: !promo.isActive,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('فشل التحديث: $e'),
        backgroundColor: const Color(0xFFE53935),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        title: const Text('أكواد الخصم'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('كود جديد'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (_stats != null) _statsGrid(_stats!),
                      const SizedBox(height: 12),
                      if (_codes.isEmpty)
                        _emptyState()
                      else
                        ..._codes.map(_promoTile),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
    );
  }

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.local_offer_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('لا توجد أكواد بعد',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text('اضغط "+ كود جديد" لإنشاء أول كود خصم',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
      );

  Widget _statsGrid(Map<String, dynamic> s) {
    return Row(children: [
      Expanded(
        child: _statCard(
          'إجمالي الأكواد',
          '${s['total_codes'] ?? 0}',
          Icons.local_offer_rounded,
          AppColors.primary,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _statCard(
          'نشط الآن',
          '${s['active_codes'] ?? 0}',
          Icons.check_circle_rounded,
          Colors.green,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _statCard(
          'استخدامات',
          '${s['total_redemptions'] ?? 0}',
          Icons.trending_up_rounded,
          const Color(0xFFFF6B35), // brand orange (was Colors.blue)
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _statCard(
          'إجمالي الخصم',
          '${(s['total_discount_given'] ?? 0).toStringAsFixed(0)} ج',
          Icons.savings_rounded,
          Colors.orange,
        ),
      ),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                color: context.kText,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              )),
          Text(label,
              style: TextStyle(color: context.kSub, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _promoTile(PromoCodeModel p) {
    final df = intl.DateFormat('dd/MM/yyyy');
    final expired =
        p.validUntil != null && p.validUntil!.isBefore(DateTime.now());
    final statusColor = !p.isActive
        ? Colors.grey
        : p.isExhausted
            ? Colors.orange
            : expired
                ? Colors.red
                : Colors.green;
    final statusLabel = !p.isActive
        ? 'معطّل'
        : p.isExhausted
            ? 'انتهى'
            : expired
                ? 'منتهي الصلاحية'
                : 'نشط';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(p.code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  )),
            ),
            const SizedBox(width: 8),
            Text(p.displayValue,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.green,
                )),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ]),
          if (p.description != null && p.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(p.description!,
                style: TextStyle(color: context.kSub, fontSize: 13)),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            _meta(
              Icons.trending_up_rounded,
              p.maxUses != null
                  ? '${p.usesCount} / ${p.maxUses} استخدام'
                  : '${p.usesCount} استخدام',
            ),
            if (p.minBookingAmount != null)
              _meta(Icons.price_check_rounded,
                  'حد أدنى ${p.minBookingAmount!.toStringAsFixed(0)} ج'),
            if (p.validUntil != null)
              _meta(Icons.event_rounded, 'ينتهي ${df.format(p.validUntil!)}'),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _toggleActive(p),
                icon: Icon(
                    p.isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    size: 18),
                label: Text(p.isActive ? 'إيقاف' : 'تفعيل'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(p),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('حذف'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.kSub),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: context.kSub, fontSize: 12)),
        ],
      );
}


// ══════════════════════════════════════════════════════════════
//  Create sheet
// ══════════════════════════════════════════════════════════════
class _CreatePromoSheet extends StatefulWidget {
  const _CreatePromoSheet();
  @override
  State<_CreatePromoSheet> createState() => _CreatePromoSheetState();
}

class _CreatePromoSheetState extends State<_CreatePromoSheet> {
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _maxDiscountCtrl = TextEditingController();
  final _minAmountCtrl = TextEditingController();
  final _maxUsesCtrl = TextEditingController();
  final _maxPerUserCtrl = TextEditingController();
  PromoType _type = PromoType.percent;
  DateTime? _validUntil;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _descCtrl.dispose();
    _valueCtrl.dispose();
    _maxDiscountCtrl.dispose();
    _minAmountCtrl.dispose();
    _maxUsesCtrl.dispose();
    _maxPerUserCtrl.dispose();
    super.dispose();
  }

  double? _tryDouble(String s) =>
      s.trim().isEmpty ? null : double.tryParse(s.trim());
  int? _tryInt(String s) =>
      s.trim().isEmpty ? null : int.tryParse(s.trim());

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    final value = double.tryParse(_valueCtrl.text.trim());
    if (code.length < 3) {
      setState(() => _error = 'الكود يجب أن يكون 3 حروف على الأقل');
      return;
    }
    if (value == null || value <= 0) {
      setState(() => _error = 'قيمة الخصم غير صالحة');
      return;
    }
    if (_type == PromoType.percent && value > 100) {
      setState(() => _error = 'النسبة لا تتجاوز 100%');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await PromoCodeService.adminCreate(
        code: code,
        type: _type,
        value: value,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        maxDiscount: _tryDouble(_maxDiscountCtrl.text),
        minBookingAmount: _tryDouble(_minAmountCtrl.text),
        maxUses: _tryInt(_maxUsesCtrl.text),
        maxUsesPerUser: _tryInt(_maxPerUserCtrl.text),
        validUntil: _validUntil,
      );
      if (!mounted) return;
      Navigator.pop(context, created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickValidUntil() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const Text('كود خصم جديد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'الكود (مثل: SUMMER25)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'الوصف (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: SegmentedButton<PromoType>(
                    segments: const [
                      ButtonSegment(
                        value: PromoType.percent,
                        label: Text('نسبة %'),
                        icon: Icon(Icons.percent_rounded),
                      ),
                      ButtonSegment(
                        value: PromoType.fixed,
                        label: Text('مبلغ ثابت'),
                        icon: Icon(Icons.attach_money_rounded),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) =>
                        setState(() => _type = s.first),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _valueCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _type == PromoType.percent
                      ? 'نسبة الخصم (0–100)'
                      : 'قيمة الخصم (جنيه)',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_type == PromoType.percent) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _maxDiscountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الحد الأقصى للخصم (اختياري - جنيه)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _minAmountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الحد الأدنى للحجز (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _maxUsesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'عدد مرات الاستخدام الكلي',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxPerUserCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'لكل مستخدم',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickValidUntil,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ الانتهاء (اختياري)',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.event_rounded),
                  ),
                  child: Text(
                    _validUntil != null
                        ? intl.DateFormat('dd/MM/yyyy').format(_validUntil!)
                        : 'بدون تاريخ',
                    style: TextStyle(
                      color: _validUntil != null ? null : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,
                          ),
                        )
                      : const Text('إنشاء الكود',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
