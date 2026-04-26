// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Reports / Dispute Queue
//  Lists pending reports filed by users and lets the admin resolve
//  or dismiss each one.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../services/report_service.dart';
import '../../widgets/constants.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});
  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final Map<String, List<ReportModel>> _data = {};
  final Map<String, bool> _loading = {};
  String _currentStatus = 'pending';

  static const _statuses = <String>['pending', 'resolved', 'dismissed'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _statuses.length, vsync: this)
      ..addListener(() {
        if (_tab.indexIsChanging) return;
        setState(() => _currentStatus = _statuses[_tab.index]);
        _load(_currentStatus);
      });
    _load(_currentStatus);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load(String status) async {
    setState(() => _loading[status] = true);
    try {
      final rows = await ReportService.adminList(status: status);
      _data[status] = rows;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('فشل تحميل البلاغات: $e'),
          backgroundColor: const Color(0xFFE53935),
        ));
      }
    }
    if (mounted) setState(() => _loading[status] = false);
  }

  Future<void> _act(ReportModel r, bool resolve) async {
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(resolve ? 'تأكيد الحل' : 'رفض البلاغ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(resolve
                ? 'سيتم تسجيل البلاغ كـ "تم حله"'
                : 'سيتم تسجيل البلاغ كـ "تم رفضه"'),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'ملاحظات (اختياري)',
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
            style: FilledButton.styleFrom(
              backgroundColor: resolve ? Colors.green : Colors.orange,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(resolve ? 'حل' : 'رفض'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (resolve) {
        await ReportService.adminResolve(r.id, notes: notesCtrl.text);
      } else {
        await ReportService.adminDismiss(r.id, notes: notesCtrl.text);
      }
      await _load('pending');
      if (_currentStatus != 'pending') await _load(_currentStatus);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('فشل التنفيذ: $e'),
        backgroundColor: const Color(0xFFE53935),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        title: const Text('البلاغات والنزاعات'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'قيد المعالجة'),
            Tab(text: 'تم الحل'),
            Tab(text: 'مرفوض'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: _statuses.map(_buildTab).toList(),
      ),
    );
  }

  Widget _buildTab(String status) {
    if (_loading[status] == true) {
      return const Center(child: CircularProgressIndicator());
    }
    final rows = _data[status] ?? const <ReportModel>[];
    if (rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'لا توجد بلاغات',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(status),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _reportCard(rows[i]),
      ),
    );
  }

  Widget _reportCard(ReportModel r) {
    final df = intl.DateFormat('dd/MM/yyyy HH:mm');
    final isPending = r.status == 'pending';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${r.id}',
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text('${r.targetType} #${r.targetId}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(df.format(r.createdAt.toLocal()),
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text('السبب: ${r.reason}',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          if (r.details != null && r.details!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r.details!,
                style: TextStyle(color: context.kSub, fontSize: 13)),
          ],
          if (r.resolutionNotes != null &&
              r.resolutionNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.kInputFill,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('ملاحظات المشرف: ${r.resolutionNotes}',
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _act(r, false),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('رفض البلاغ'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _act(r, true),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('حل البلاغ'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
