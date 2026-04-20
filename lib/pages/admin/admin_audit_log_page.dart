// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Audit Log Page
//  Forensic trail of every mutating admin action.
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

import '../../services/audit_log_service.dart';
import '../../widgets/constants.dart';

const _kActionGroups = <String, ({String label, Color color})>{
  'user.': (label: 'المستخدمون', color: Color(0xFF2563EB)),
  'property.': (label: 'العقارات', color: Color(0xFF059669)),
  'booking.': (label: 'الحجوزات', color: Color(0xFFF59E0B)),
  'review.': (label: 'التقييمات', color: Color(0xFFDB2777)),
  'promo.': (label: 'أكواد الخصم', color: Color(0xFF7C3AED)),
  'payout.': (label: 'الدفعات', color: Color(0xFF0891B2)),
  'report.': (label: 'البلاغات', color: Color(0xFFDC2626)),
};

class AdminAuditLogPage extends StatefulWidget {
  const AdminAuditLogPage({super.key});
  @override
  State<AdminAuditLogPage> createState() => _AdminAuditLogPageState();
}

class _AdminAuditLogPageState extends State<AdminAuditLogPage> {
  List<AuditEntry> _entries = [];
  AuditStats? _stats;
  String? _prefix;
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
        AuditLogService.list(actionPrefix: _prefix, limit: 200),
        AuditLogService.statsOverview(),
      ]);
      _entries = results[0] as List<AuditEntry>;
      _stats = results[1] as AuditStats;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  ({String label, Color color}) _meta(String action) {
    for (final e in _kActionGroups.entries) {
      if (action.startsWith(e.key)) return e.value;
    }
    return (label: 'عام', color: Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        title: const Text('سجل الإجراءات'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      if (_stats != null)
                        SliverToBoxAdapter(child: _statsHeader(_stats!)),
                      SliverToBoxAdapter(child: _filterChips()),
                      if (_entries.isEmpty)
                        SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'لا توجد سجلات لهذا الفلتر',
                              style: TextStyle(color: context.kSub),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                          sliver: SliverList.builder(
                            itemCount: _entries.length,
                            itemBuilder: (_, i) => _entryTile(_entries[i]),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  // ── stats header ──────────────────────────────────────
  Widget _statsHeader(AuditStats s) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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
            Icon(Icons.assessment_outlined, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('${s.totalEntries} إجراء مسجل',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: context.kText)),
          ]),
          if (s.topActions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('الأكثر تكراراً',
                style: TextStyle(fontSize: 11, color: context.kSub)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                for (final a in s.topActions.take(6))
                  _statChip(a.action, a.count, _meta(a.action).color),
              ],
            ),
          ],
          if (s.topActors.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('أكثر المسؤولين نشاطاً',
                style: TextStyle(fontSize: 11, color: context.kSub)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                for (final a in s.topActors.take(5))
                  _statChip(a.actor, a.count, Colors.blueGrey),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text('$label · $count',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  // ── filter chips ──────────────────────────────────────
  Widget _filterChips() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _chip(label: 'الكل', selected: _prefix == null, onTap: () {
            setState(() => _prefix = null);
            _load();
          }),
          for (final e in _kActionGroups.entries)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _chip(
                label: e.value.label,
                color: e.value.color,
                selected: _prefix == e.key,
                onTap: () {
                  setState(() => _prefix = e.key);
                  _load();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color color = Colors.grey,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          border: Border.all(color: color, width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
      ),
    );
  }

  // ── entry tile ────────────────────────────────────────
  Widget _entryTile(AuditEntry e) {
    final m = _meta(e.action);
    final df = intl.DateFormat('dd/MM HH:mm');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: m.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(e.action,
                  style: TextStyle(
                      color: m.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace')),
            ),
            const Spacer(),
            Text(df.format(e.createdAt.toLocal()),
                style: TextStyle(color: context.kSub, fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          Text('${e.actorEmail ?? "system"} · ${e.actorRole ?? "-"}',
              style: TextStyle(
                  color: context.kText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          if (e.targetType != null) ...[
            const SizedBox(height: 2),
            Text('target: ${e.targetType}${e.targetId != null ? "#${e.targetId}" : ""}',
                style: TextStyle(
                    color: context.kSub,
                    fontSize: 11,
                    fontFamily: 'monospace')),
          ],
          if (e.before != null || e.after != null) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _showDiff(e),
              child: Text('عرض التفاصيل ⌄',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
          if (e.ipAddress != null) ...[
            const SizedBox(height: 4),
            Text(e.ipAddress!,
                style: TextStyle(
                    color: context.kSub, fontSize: 10,
                    fontFamily: 'monospace')),
          ],
        ],
      ),
    );
  }

  Future<void> _showDiff(AuditEntry e) async {
    final encoder = const JsonEncoder.withIndent('  ');
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(16),
            child: Column(
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
                Text(e.action,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        fontFamily: 'monospace')),
                const SizedBox(height: 4),
                Text(
                  '${e.actorEmail ?? "system"} — '
                  '${intl.DateFormat('yyyy/MM/dd HH:mm:ss').format(e.createdAt.toLocal())}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                const Divider(height: 24),
                if (e.before != null) ...[
                  const Text('قبل:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 4),
                  _codeBox(encoder.convert(e.before)),
                  const SizedBox(height: 12),
                ],
                if (e.after != null) ...[
                  const Text('بعد:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 4),
                  _codeBox(encoder.convert(e.after)),
                  const SizedBox(height: 12),
                ],
                _metaRow('IP', e.ipAddress),
                _metaRow('User-Agent', e.userAgent),
                _metaRow('Request ID', e.requestId),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _codeBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
    );
  }

  Widget _metaRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        ),
        Expanded(
          child: InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم النسخ')),
              );
            },
            child: Text(value,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 11)),
          ),
        ),
      ]),
    );
  }
}
