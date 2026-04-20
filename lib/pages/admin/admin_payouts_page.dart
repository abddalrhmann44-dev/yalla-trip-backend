// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Payouts Page
//  List batches, create new batch for a cycle, mark paid/failed,
//  copy CSV download URL.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';

import '../../services/payout_service.dart';
import '../../widgets/constants.dart';

class AdminPayoutsPage extends StatefulWidget {
  const AdminPayoutsPage({super.key});
  @override
  State<AdminPayoutsPage> createState() => _AdminPayoutsPageState();
}

class _AdminPayoutsPageState extends State<AdminPayoutsPage> {
  List<PayoutModel> _rows = [];
  PayoutStatus? _filter;
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
      _rows = await PayoutService.adminList(status: _filter, limit: 200);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openCreateBatch() async {
    final result = await showModalBottomSheet<List<PayoutModel>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateBatchSheet(),
    );
    if (result != null) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.isEmpty
              ? 'لا توجد حجوزات مؤهلة في هذه الفترة'
              : 'تم إنشاء ${result.length} دفعة'),
          backgroundColor:
              result.isEmpty ? Colors.orange : Colors.green,
        ));
      }
    }
  }

  Future<void> _markPaid(PayoutModel p) async {
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الدفع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المبلغ: ${p.totalAmount.toStringAsFixed(0)} جنيه',
                style:
                    const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: refCtrl,
              decoration: const InputDecoration(
                labelText: 'المرجع البنكي',
                hintText: 'BANK-REF-XXXX',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد الدفع'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (refCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل المرجع البنكي أولاً')),
      );
      return;
    }
    try {
      await PayoutService.adminMarkPaid(
        p.id,
        referenceNumber: refCtrl.text.trim(),
        notes:
            notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('فشل التحديث: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _markFailed(PayoutModel p) async {
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعليم الدفعة كفاشلة'),
        content: TextField(
          controller: notesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'سبب الفشل',
            hintText: 'IBAN خاطئ، حساب مغلق...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تعليم كفاشلة'),
          ),
        ],
      ),
    );
    if (ok != true || notesCtrl.text.trim().isEmpty) return;
    try {
      await PayoutService.adminMarkFailed(
        p.id, notes: notesCtrl.text.trim(),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('فشل التحديث: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _openCsv(PayoutModel p) async {
    final url = PayoutService.adminCsvUrl(p.id);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ رابط CSV — يحتاج رمز admin للوصول')),
    );
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        title: const Text('دفعات المضيفين'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<PayoutStatus?>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (v) {
              setState(() => _filter = v);
              _load();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('الكل')),
              for (final s in PayoutStatus.values)
                PopupMenuItem(value: s, child: Text(s.labelAr)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateBatch,
        icon: const Icon(Icons.playlist_add_check_rounded),
        label: const Text('دفعة جديدة'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _rows.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(40),
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('لا توجد دفعات بعد',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.grey.shade600)),
                            const SizedBox(height: 4),
                            Text(
                                'اضغط "دفعة جديدة" لتجميع الحجوزات المستحقة',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12)),
                          ],
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(12, 12, 12, 100),
                          itemCount: _rows.length,
                          itemBuilder: (_, i) => _payoutTile(_rows[i]),
                        ),
                ),
    );
  }

  Widget _payoutTile(PayoutModel p) {
    final df = intl.DateFormat('dd/MM/yyyy');
    Color statusColor;
    switch (p.status) {
      case PayoutStatus.paid:
        statusColor = Colors.green;
        break;
      case PayoutStatus.failed:
        statusColor = Colors.red;
        break;
      case PayoutStatus.processing:
        statusColor = Colors.blue;
        break;
      case PayoutStatus.pending:
        statusColor = Colors.orange;
        break;
    }
    final canMark = p.status == PayoutStatus.pending ||
        p.status == PayoutStatus.processing;

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
            Expanded(
              child: Text(
                '${p.totalAmount.toStringAsFixed(0)} جنيه',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: context.kText,
                    fontSize: 18),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(p.status.labelAr,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Host #${p.hostId} · ${p.items.length} حجز',
              style: TextStyle(color: context.kSub, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            'الدورة: ${df.format(p.cycleStart)} → ${df.format(p.cycleEnd)}',
            style: TextStyle(color: context.kSub, fontSize: 11),
          ),
          if (p.referenceNumber != null) ...[
            const SizedBox(height: 2),
            Text('المرجع: ${p.referenceNumber}',
                style: TextStyle(
                    color: context.kSub,
                    fontSize: 11,
                    fontFamily: 'monospace')),
          ],
          if (p.adminNotes != null && p.adminNotes!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(p.adminNotes!,
                style: TextStyle(color: context.kSub, fontSize: 11)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openCsv(p),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('CSV'),
              ),
            ),
            if (canMark) ...[
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _markPaid(p),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('تم الدفع'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _markFailed(p),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('فشل'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════
//  Create-batch sheet
// ══════════════════════════════════════════════════════════════
class _CreateBatchSheet extends StatefulWidget {
  const _CreateBatchSheet();
  @override
  State<_CreateBatchSheet> createState() => _CreateBatchSheetState();
}

class _CreateBatchSheetState extends State<_CreateBatchSheet> {
  DateTime _start = DateTime.now().subtract(const Duration(days: 14));
  DateTime _end = DateTime.now();
  Map<String, dynamic>? _preview;
  bool _loading = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshPreview();
  }

  Future<void> _refreshPreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _preview = await PayoutService.adminEligiblePreview(
        cycleStart: _start, cycleEnd: _end,
      );
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        if (start) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
      await _refreshPreview();
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final created = await PayoutService.adminCreateBatch(
        cycleStart: _start, cycleEnd: _end,
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

  @override
  Widget build(BuildContext context) {
    final df = intl.DateFormat('dd/MM/yyyy');
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Text('إنشاء دفعة جديدة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(true),
                  child: Column(children: [
                    const Text('من'),
                    Text(df.format(_start),
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(false),
                  child: Column(children: [
                    const Text('إلى'),
                    Text(df.format(_end),
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              )
            else if (_preview != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('ستنشأ الدفعات التالية:',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  _statRow('إجمالي الحجوزات',
                      '${_preview!['total_bookings']}'),
                  _statRow('إجمالي المبلغ',
                      '${(_preview!['total_amount'] as num).toStringAsFixed(0)} جنيه'),
                  _statRow('عدد المضيفين',
                      '${(_preview!['hosts'] as List).length}'),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            if (_error != null) ...[
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
              const SizedBox(height: 10),
            ],
            SizedBox(
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary),
                onPressed: (_submitting ||
                        (_preview != null &&
                            (_preview!['total_bookings'] as int) == 0))
                    ? null
                    : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('إنشاء الدفعات',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );
}
