// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Admin Promo Code Manager
//  CRUD: Create, Update, Delete, Activate/Deactivate promos
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../widgets/constants.dart';
import '../../data/models/promo_code_model.dart';
import '../providers/booking_providers.dart';

const _kOcean  = Color(0xFF1565C0);
const _kGreen  = Color(0xFF4CAF50);
const _kRed    = Color(0xFFEF5350);

class AdminPromoManagerPage extends ConsumerWidget {
  const AdminPromoManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promosAsync = ref.watch(promoCodesStreamProvider);

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
        title: Text('إدارة أكواد الخصم',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
        backgroundColor: _kOcean,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('إضافة كود',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: promosAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kOcean)),
        error: (e, _) => Center(
            child: Text('خطأ: $e',
                style: TextStyle(color: context.kSub))),
        data: (promos) {
          if (promos.isEmpty) {
            return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Icon(Icons.local_offer_outlined,
                    size: 48, color: context.kBorder),
                const SizedBox(height: 12),
                Text('لا توجد أكواد خصم',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.kText)),
              ]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: promos.length,
            itemBuilder: (_, i) =>
                _promoTile(context, ref, promos[i]),
          );
        },
      ),
    );
  }

  Widget _promoTile(
      BuildContext context, WidgetRef ref, PromoCodeModel promo) {
    final expiryStr = DateFormat('dd/MM/yyyy').format(promo.expiryDate);
    final isExpired = promo.isExpired;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: !promo.isActive
              ? context.kBorder
              : isExpired
                  ? _kRed.withValues(alpha: 0.3)
                  : _kGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Code
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kOcean.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(promo.code,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _kOcean,
                    letterSpacing: 2)),
          ),
          const Spacer(),
          // Discount
          Text('${promo.discountPercent.toStringAsFixed(0)}%',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _kGreen)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          // Status badges
          _badge(
              promo.isActive ? 'نشط' : 'معطل',
              promo.isActive ? _kGreen : _kRed),
          const SizedBox(width: 6),
          if (isExpired)
            _badge('منتهي', _kRed),
          const Spacer(),
          Text('انتهاء: $expiryStr',
              style: TextStyle(fontSize: 11, color: context.kSub)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text(
              'الاستخدام: ${promo.usageCount}${promo.maxUsage != null ? " / ${promo.maxUsage}" : ""}',
              style: TextStyle(fontSize: 12, color: context.kSub)),
          const Spacer(),
          // Toggle active
          GestureDetector(
            onTap: () {
              ref.read(adminConfigServiceProvider).togglePromoActive(
                  promo.id, !promo.isActive);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (promo.isActive ? _kRed : _kGreen)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(promo.isActive ? 'تعطيل' : 'تفعيل',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: promo.isActive ? _kRed : _kGreen)),
            ),
          ),
          const SizedBox(width: 6),
          // Delete
          GestureDetector(
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: const Text('حذف الكود؟',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _kRed),
                      child: const Text('حذف',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                ref
                    .read(adminConfigServiceProvider)
                    .deletePromoCode(promo.id);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 16, color: _kRed),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color)),
      );

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    final codeCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    final maxUsageCtrl = TextEditingController();
    DateTime expiry = DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: BoxDecoration(
            color: context.kCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: context.kBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text('إضافة كود خصم',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: context.kText)),
              const SizedBox(height: 20),
              _sheetField(codeCtrl, 'الكود (مثل SUMMER25)',
                  TextInputType.text, context),
              const SizedBox(height: 12),
              _sheetField(discountCtrl, 'نسبة الخصم %',
                  TextInputType.number, context),
              const SizedBox(height: 12),
              _sheetField(maxUsageCtrl, 'أقصى استخدام (اختياري)',
                  TextInputType.number, context),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: expiry,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setSheetState(() => expiry = date);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.kSand,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.kBorder),
                  ),
                  child: Text(
                      'تاريخ الانتهاء: ${DateFormat('dd/MM/yyyy').format(expiry)}',
                      style: TextStyle(
                          fontSize: 14, color: context.kText)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final code = codeCtrl.text.trim().toUpperCase();
                    final discount =
                        double.tryParse(discountCtrl.text) ?? 0;
                    if (code.isEmpty || discount <= 0) return;

                    final maxUsage =
                        int.tryParse(maxUsageCtrl.text.trim());

                    ref
                        .read(adminConfigServiceProvider)
                        .createPromoCode(PromoCodeModel(
                          id: '',
                          code: code,
                          discountPercent: discount,
                          isActive: true,
                          expiryDate: expiry,
                          createdAt: DateTime.now(),
                          maxUsage: maxUsage,
                        ));

                    Navigator.pop(ctx);
                    HapticFeedback.mediumImpact();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kOcean,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('إنشاء الكود',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String hint,
          TextInputType type, BuildContext context) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        textCapitalization: type == TextInputType.text
            ? TextCapitalization.characters
            : TextCapitalization.none,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: context.kSand,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _kOcean, width: 1.5)),
        ),
      );
}
