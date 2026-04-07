// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Admin Financial Settings
//  Update appFeePercent in real-time
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/constants.dart';
import '../providers/booking_providers.dart';

const _kOcean  = Color(0xFF1565C0);
const _kGreen  = Color(0xFF4CAF50);

class AdminFinancialSettingsPage extends ConsumerStatefulWidget {
  final double currentFee;
  const AdminFinancialSettingsPage({super.key, required this.currentFee});

  @override
  ConsumerState<AdminFinancialSettingsPage> createState() =>
      _AdminFinancialSettingsPageState();
}

class _AdminFinancialSettingsPageState
    extends ConsumerState<AdminFinancialSettingsPage> {
  late final TextEditingController _feeCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _feeCtrl = TextEditingController(
        text: widget.currentFee.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _feeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final val = double.tryParse(_feeCtrl.text.trim());
    if (val == null || val < 0 || val > 100) {
      _snack('أدخل قيمة صحيحة بين 0 و 100', const Color(0xFFEF5350));
      return;
    }

    setState(() => _saving = true);

    try {
      await ref.read(adminConfigServiceProvider).updateAppFee(val);
      if (mounted) {
        setState(() => _saving = false);
        HapticFeedback.mediumImpact();
        _snack('تم الحفظ بنجاح ✅', _kGreen);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('حدث خطأ: $e', const Color(0xFFEF5350));
      }
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text('إعدادات الرسوم',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        centerTitle: true,
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // ── Current fee (live) ─────────────────────────────
        feeAsync.when(
          data: (fee) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kOcean.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kOcean.withValues(alpha: 0.15)),
            ),
            child: Column(children: [
              Text('الرسوم الحالية',
                  style: TextStyle(fontSize: 14, color: context.kSub)),
              const SizedBox(height: 8),
              Text('${fee.toStringAsFixed(1)}%',
                  style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: _kOcean)),
              const SizedBox(height: 4),
              Text('من كل حجز',
                  style: TextStyle(fontSize: 13, color: context.kSub)),
            ]),
          ),
          loading: () => const Center(
              child: CircularProgressIndicator(color: _kOcean)),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(height: 24),

        // ── Edit section ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.kBorder),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('تعديل نسبة الرسوم',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: context.kText)),
            const SizedBox(height: 6),
            Text('النسبة المئوية التي تأخذها المنصة من كل حجز',
                style: TextStyle(fontSize: 12, color: context.kSub)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _feeCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,1}')),
                  ],
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: context.kText),
                  decoration: InputDecoration(
                    suffixText: '%',
                    suffixStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _kOcean),
                    filled: true,
                    fillColor: context.kSand,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.kBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.kBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: _kOcean, width: 2)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 18),
                  decoration: BoxDecoration(
                    color: _saving
                        ? _kOcean.withValues(alpha: 0.5)
                        : _kOcean,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Info ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Colors.amber.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  'التغيير يتم تطبيقه فوراً على كل الحجوزات الجديدة',
                  style: TextStyle(
                      fontSize: 12, color: context.kSub)),
            ),
          ]),
        ),
      ]),
    );
  }
}
