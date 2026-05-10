// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Disputes Page  (Wave 30)
//
//  A "dispute" in TALAA = any user report whose target is a booking
//  (host vs guest disagreement, payment issue, not-as-described,
//  fraud accusation).  We re-use the generic ``Report`` model with
//  ``target_type=booking`` so the data layer stays uniform — but
//  this page surfaces only the booking-level conflicts so the ops
//  team has a focused queue separate from review/spam reports.
//
//  Tabs:  Pending  |  Resolved  |  Dismissed
//  Per row: reporter • reason badge • details body • timestamp •
//           Open booking, Resolve, Dismiss actions.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

import '../../services/report_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';

const _kOcean = Color(0xFFFF6B35);
const _kRed = Color(0xFFEF5350);
const _kGreen = Color(0xFF4CAF50);
const _kAmber = Color(0xFFFFB300);

class AdminDisputesPage extends StatefulWidget {
  const AdminDisputesPage({super.key});
  @override
  State<AdminDisputesPage> createState() => _AdminDisputesPageState();
}

class _AdminDisputesPageState extends State<AdminDisputesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final List<String> _statuses = const ['pending', 'resolved', 'dismissed'];

  final Map<String, List<ReportModel>> _data = {};
  final Map<String, bool> _loading = {};
  final Set<int> _busyIds = {};

  String get _currentStatus => _statuses[_tab.index];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _statuses.length, vsync: this)
      ..addListener(() {
        if (_tab.indexIsChanging) return;
        setState(() {});
        if (_data[_currentStatus] == null) _load(_currentStatus);
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
      // Filter the generic report queue down to booking-level
      // disputes only — this is the whole point of the dedicated
      // page (vs ``admin_reports_page`` which shows everything).
      final rows = await ReportService.adminList(
        status: status,
        targetType: 'booking',
        limit: 100,
      );
      if (!mounted) return;
      setState(() => _data[status] = rows);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل تحميل النزاعات: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading[status] = false);
    }
  }

  Future<void> _resolveDispute(ReportModel r, {required bool dismiss}) async {
    final notes = await _showNotesDialog(
      title: dismiss ? 'تجاهل النزاع' : 'حل النزاع',
      hint: dismiss
          ? 'سبب التجاهل (اختياري)'
          : 'ملخص الحل (اختياري) — يُسجَّل في الـ audit log',
      cta: dismiss ? 'تجاهل' : 'تأكيد الحل',
      ctaColor: dismiss ? _kAmber : _kGreen,
    );
    if (notes == null) return;
    if (!mounted) return;

    HapticFeedback.lightImpact();
    setState(() => _busyIds.add(r.id));
    try {
      final updated = dismiss
          ? await ReportService.adminDismiss(r.id, notes: notes)
          : await ReportService.adminResolve(r.id, notes: notes);
      if (!mounted) return;
      setState(() {
        _data['pending']?.removeWhere((x) => x.id == r.id);
        // Push into the appropriate destination tab cache (so
        // switching to "resolved" / "dismissed" shows it instantly
        // without a full reload).
        final destBucket = updated.status;
        if (_data[destBucket] != null) {
          _data[destBucket]!.insert(0, updated);
        }
      });
      _snack(
        dismiss ? 'تم تجاهل النزاع' : 'تم حل النزاع',
        _kGreen,
      );
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل العملية: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busyIds.remove(r.id));
    }
  }

  Future<String?> _showNotesDialog({
    required String title,
    required String hint,
    required String cta,
    required Color ctaColor,
  }) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء',
                style: TextStyle(
                    color: context.kSub, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: ctaColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(cta,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('إدارة النزاعات',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'منتظرة'),
            Tab(text: 'محلولة'),
            Tab(text: 'مُتجاهلة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: _statuses.map(_buildList).toList(),
      ),
    );
  }

  Widget _buildList(String status) {
    final loading = _loading[status] ?? false;
    final rows = _data[status];
    if (loading && rows == null) {
      return const Center(child: CircularProgressIndicator(color: _kOcean));
    }
    if (rows == null) return const SizedBox.shrink();
    return RefreshIndicator(
      color: _kOcean,
      onRefresh: () => _load(status),
      child: rows.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 100),
                Icon(Icons.gavel_rounded,
                    size: 64, color: context.kSub.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    status == 'pending'
                        ? 'لا توجد نزاعات منتظرة 🎉'
                        : status == 'resolved'
                            ? 'لم يتم حل أي نزاع بعد'
                            : 'لا توجد نزاعات تم تجاهلها',
                    style: TextStyle(
                        color: context.kSub,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final r = rows[i];
                return _DisputeCard(
                  report: r,
                  busy: _busyIds.contains(r.id),
                  showActions: status == 'pending',
                  onResolve: () => _resolveDispute(r, dismiss: false),
                  onDismiss: () => _resolveDispute(r, dismiss: true),
                );
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Single dispute row card
// ═══════════════════════════════════════════════════════════════
class _DisputeCard extends StatelessWidget {
  final ReportModel report;
  final bool busy;
  final bool showActions;
  final VoidCallback onResolve;
  final VoidCallback onDismiss;

  const _DisputeCard({
    required this.report,
    required this.busy,
    required this.showActions,
    required this.onResolve,
    required this.onDismiss,
  });

  Color get _statusColor {
    switch (report.status) {
      case 'resolved':
        return _kGreen;
      case 'dismissed':
        return _kAmber;
      default:
        return _kRed;
    }
  }

  String get _arabicReason {
    switch (report.reason) {
      case 'spam':
        return 'سبام';
      case 'inappropriate':
        return 'غير لائق';
      case 'fraud':
        return 'احتيال';
      case 'fake_listing':
        return 'عقار وهمي';
      case 'abuse':
        return 'إساءة';
      case 'not_as_described':
        return 'غير مطابق للوصف';
      case 'payment_issue':
        return 'مشكلة دفع';
      default:
        return report.reason;
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = intl.DateFormat('y/MM/dd – HH:mm')
        .format(report.createdAt.toLocal());
    return Container(
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: _statusColor.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.gavel_rounded,
                  color: _statusColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نزاع على حجز #${report.targetId}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: context.kText)),
                  const SizedBox(height: 2),
                  Text('بلاغ #${report.id} • $created',
                      style: TextStyle(
                          fontSize: 10,
                          color: context.kSub,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            _reasonChip(),
          ]),
          const SizedBox(height: 12),
          if ((report.details ?? '').trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.kSand.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                report.details!.trim(),
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: context.kText),
              ),
            ),
          if ((report.resolutionNotes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kGreen.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.notes_rounded, color: _kGreen, size: 14),
                    SizedBox(width: 6),
                    Text('ملاحظات الإدارة',
                        style: TextStyle(
                            color: _kGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 4),
                  Text(report.resolutionNotes!.trim(),
                      style: TextStyle(
                          fontSize: 12,
                          color: context.kText,
                          height: 1.4)),
                ],
              ),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy ? null : onResolve,
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16),
                  label: const Text('حل',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onDismiss,
                  icon: const Icon(Icons.cancel_outlined,
                      color: _kAmber, size: 16),
                  label: const Text('تجاهل',
                      style: TextStyle(
                          color: _kAmber,
                          fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(
                    side:
                        BorderSide(color: _kAmber.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11)),
                  ),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _reasonChip() {
    Color c;
    switch (report.reason) {
      case 'fraud':
      case 'payment_issue':
        c = _kRed;
        break;
      case 'not_as_described':
      case 'abuse':
        c = _kAmber;
        break;
      default:
        c = _kOcean;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(_arabicReason,
          style: TextStyle(
              color: c, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}
