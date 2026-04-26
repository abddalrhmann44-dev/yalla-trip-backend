// ═══════════════════════════════════════════════════════════════
//  TALAA — Report bottom-sheet
//  Lets a user file a moderation report on any target.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../services/report_service.dart';
import '../widgets/constants.dart';

/// Show the report sheet and return ``true`` if a report was filed.
Future<bool> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
  required int targetId,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportSheet(target: target, targetId: targetId),
  );
  return result ?? false;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.target, required this.targetId});
  final ReportTarget target;
  final int targetId;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _selected;
  final _details = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _selected;
    if (reason == null) return;
    setState(() => _submitting = true);
    try {
      await ReportService.create(
        target: widget.target,
        targetId: widget.targetId,
        reason: reason,
        details: _details.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم إرسال البلاغ — شكراً لك'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('فشل إرسال البلاغ: $e'),
        backgroundColor: const Color(0xFFE53935),
      ));
    }
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
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const Text(
                'الإبلاغ عن مشكلة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'اختر سبب البلاغ وسنتواصل معك قريباً',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in ReportReason.values)
                    ChoiceChip(
                      label: Text(r.labelAr),
                      selected: _selected == r,
                      onSelected: (_) => setState(() => _selected = r),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: _selected == r
                            ? AppColors.primary
                            : Colors.black87,
                        fontWeight: _selected == r
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _details,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'تفاصيل إضافية (اختياري)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: (_submitting || _selected == null) ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,
                          ),
                        )
                      : const Text(
                          'إرسال البلاغ',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
