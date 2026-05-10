// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Refunds Page  (Wave 30)
//
//  Finance queue: every paid booking that owes a refund.  Admin can
//  see who, how much, why, then mark the refund as processed once
//  it has actually been pushed through the gateway (or to reconcile
//  a chargeback).
//
//  Three tabs:
//    • Pending   — paid + cancelled, refund not yet processed
//    • Processed — already refunded / partially refunded
//    • All       — both
//
//  Per row:
//    • Property + guest summary, refund amount, gateway ref
//    • "Mark as processed" action (full or partial) with confirm
//    • Open booking → admin booking detail (re-uses existing flow)
// ═══════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

import '../../models/admin_refund_row.dart';
import '../../services/admin_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';

const _kOcean = Color(0xFFFF6B35);
const _kRed = Color(0xFFEF5350);
const _kGreen = Color(0xFF4CAF50);
const _kAmber = Color(0xFFFFB300);

enum _RefundTab { pending, processed, all }

extension on _RefundTab {
  String get apiState => switch (this) {
        _RefundTab.pending => 'pending',
        _RefundTab.processed => 'processed',
        _RefundTab.all => 'all',
      };
  String get arabicLabel => switch (this) {
        _RefundTab.pending => 'تحت المعالجة',
        _RefundTab.processed => 'تم استردادها',
        _RefundTab.all => 'الكل',
      };
}

class AdminRefundsPage extends StatefulWidget {
  const AdminRefundsPage({super.key});
  @override
  State<AdminRefundsPage> createState() => _AdminRefundsPageState();
}

class _AdminRefundsPageState extends State<AdminRefundsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  _RefundTab _current = _RefundTab.pending;

  final Map<_RefundTab, List<AdminRefundRow>> _data = {};
  final Map<_RefundTab, bool> _loading = {};
  final Map<_RefundTab, int> _total = {};
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _RefundTab.values.length, vsync: this)
      ..addListener(() {
        if (_tab.indexIsChanging) return;
        setState(() => _current = _RefundTab.values[_tab.index]);
        if (_data[_current] == null) _load(_current);
      });
    _load(_current);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load(_RefundTab tab) async {
    setState(() => _loading[tab] = true);
    try {
      final res = await AdminService.getRefunds(state: tab.apiState, limit: 50);
      if (!mounted) return;
      setState(() {
        _data[tab] = res.items;
        _total[tab] = res.total;
      });
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل تحميل المستردات: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading[tab] = false);
    }
  }

  Future<void> _markProcessed(AdminRefundRow row) async {
    HapticFeedback.lightImpact();
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProcessRefundSheet(row: row),
    );
    if (action == null) return;
    if (!mounted) return;
    final partial = action == 'partial';

    setState(() => _busyIds.add(row.bookingId));
    try {
      final updated = await AdminService.markRefundProcessed(
        row.bookingId,
        partial: partial,
      );
      if (!mounted) return;
      setState(() {
        for (final tab in _RefundTab.values) {
          final list = _data[tab];
          if (list == null) continue;
          final idx =
              list.indexWhere((x) => x.bookingId == row.bookingId);
          if (idx == -1) continue;
          // Drop pending row when it's no longer pending.
          if (tab == _RefundTab.pending && updated.isProcessed) {
            list.removeAt(idx);
          } else {
            list[idx] = updated;
          }
        }
      });
      _snack(
        partial
            ? 'تم تسجيل الاسترداد الجزئي'
            : 'تم تسجيل الاسترداد بالكامل',
        _kGreen,
      );
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل تسجيل الاسترداد: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busyIds.remove(row.bookingId));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('إدارة المستردات',
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
          tabs:
              _RefundTab.values.map((t) => Tab(text: t.arabicLabel)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: _RefundTab.values.map(_buildList).toList(),
      ),
    );
  }

  Widget _buildList(_RefundTab tab) {
    final loading = _loading[tab] ?? false;
    final rows = _data[tab];
    if (loading && rows == null) {
      return const Center(child: CircularProgressIndicator(color: _kOcean));
    }
    if (rows == null) return const SizedBox.shrink();
    return RefreshIndicator(
      color: _kOcean,
      onRefresh: () => _load(tab),
      child: rows.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 100),
                Icon(Icons.receipt_long_rounded,
                    size: 64,
                    color: context.kSub.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    tab == _RefundTab.pending
                        ? 'لا توجد عمليات استرداد منتظرة 🎉'
                        : tab == _RefundTab.processed
                            ? 'لم يتم استرداد أي حجز بعد'
                            : 'لا توجد عمليات استرداد',
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
              itemCount: rows.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _SummaryHeader(
                    rows: rows,
                    label: tab.arabicLabel,
                  );
                }
                final r = rows[i - 1];
                return _RefundCard(
                  row: r,
                  busy: _busyIds.contains(r.bookingId),
                  onMarkProcessed: () => _markProcessed(r),
                );
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Summary header — total amount owed in the current tab
// ═══════════════════════════════════════════════════════════════
class _SummaryHeader extends StatelessWidget {
  final List<AdminRefundRow> rows;
  final String label;
  const _SummaryHeader({required this.rows, required this.label});

  @override
  Widget build(BuildContext context) {
    final totalRefund = rows.fold<double>(
      0,
      (s, r) => s + (r.refundAmount ?? r.totalPrice),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kOcean.withValues(alpha: 0.92),
            const Color(0xFFE85A24).withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.account_balance_wallet_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${rows.length} حجز',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('الإجمالي',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            Text('${totalRefund.toStringAsFixed(0)} ج.م',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Single refund row card
// ═══════════════════════════════════════════════════════════════
class _RefundCard extends StatelessWidget {
  final AdminRefundRow row;
  final bool busy;
  final VoidCallback onMarkProcessed;

  const _RefundCard({
    required this.row,
    required this.busy,
    required this.onMarkProcessed,
  });

  @override
  Widget build(BuildContext context) {
    final refundAmt = row.refundAmount ?? row.totalPrice;
    final dateLabel = row.cancelledAt != null
        ? intl.DateFormat('y/MM/dd – HH:mm')
            .format(row.cancelledAt!.toLocal())
        : '—';
    final stayLabel =
        (row.checkIn != null && row.checkOut != null)
            ? '${intl.DateFormat('MMM d').format(row.checkIn!)} – '
                '${intl.DateFormat('MMM d, y').format(row.checkOut!)}'
            : '—';

    return Container(
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: row.isProcessed
                ? _kGreen.withValues(alpha: 0.4)
                : _kAmber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — property + status
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: row.propertyImage == null
                      ? Container(
                          color: _kOcean.withValues(alpha: 0.15),
                          child: const Icon(Icons.villa_rounded,
                              color: _kOcean, size: 20),
                        )
                      : CachedNetworkImage(
                          imageUrl: row.propertyImage!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: context.kBorder),
                          errorWidget: (_, __, ___) => Container(
                            color: _kOcean.withValues(alpha: 0.15),
                            child: const Icon(Icons.villa_rounded,
                                color: _kOcean, size: 20),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.propertyName ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: context.kText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'حجز #${row.bookingId} • ألغى $dateLabel',
                      style: TextStyle(
                          fontSize: 10,
                          color: context.kSub,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              _statusChip(row),
            ]),
          ),
          const Divider(height: 1, thickness: 0.5),

          // Body — amounts + guest + payment ref
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: _kvBlock(
                      context,
                      label: 'المبلغ المسترد',
                      value: '${refundAmt.toStringAsFixed(0)} ج.م',
                      valueColor: _kAmber,
                      bold: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _kvBlock(
                      context,
                      label: 'إجمالي الحجز',
                      value: '${row.totalPrice.toStringAsFixed(0)} ج.م',
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                _kvBlock(
                  context,
                  label: 'الإقامة',
                  value: stayLabel,
                ),
                const SizedBox(height: 8),
                _kvBlock(
                  context,
                  label: 'الضيف',
                  value:
                      '${row.guestName ?? '—'} • ${row.guestPhone ?? '—'}',
                ),
                if (row.paymentProvider != null) ...[
                  const SizedBox(height: 8),
                  _kvBlock(
                    context,
                    label:
                        'بوابة الدفع (${row.paymentProvider!.toUpperCase()})',
                    value: row.paymentProviderRef ?? '—',
                  ),
                ],
              ],
            ),
          ),

          // Action footer
          if (!row.isProcessed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: busy ? null : onMarkProcessed,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ))
                      : const Icon(Icons.task_alt_rounded,
                          color: Colors.white, size: 18),
                  label: const Text('تم تنفيذ الاسترداد',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(AdminRefundRow r) {
    final IconData icon;
    final Color color;
    final String text;
    switch (r.paymentStatus) {
      case 'refunded':
        icon = Icons.check_circle_rounded;
        color = _kGreen;
        text = 'تم الاسترداد';
        break;
      case 'partially_refunded':
        icon = Icons.timelapse_rounded;
        color = _kAmber;
        text = 'استرداد جزئي';
        break;
      default:
        icon = Icons.pending_rounded;
        color = _kAmber;
        text = 'منتظر';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _kvBlock(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
    bool bold = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.kSand.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: context.kSub,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: bold ? 14 : 12,
                color: valueColor ?? context.kText,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Bottom sheet for choosing full / partial refund
// ═══════════════════════════════════════════════════════════════
class _ProcessRefundSheet extends StatelessWidget {
  final AdminRefundRow row;
  const _ProcessRefundSheet({required this.row});

  @override
  Widget build(BuildContext context) {
    final amt = row.refundAmount ?? row.totalPrice;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.kBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('تأكيد تنفيذ الاسترداد',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: context.kText)),
            const SizedBox(height: 6),
            Text(
              'تأكد إن البوابة (${row.paymentProvider?.toUpperCase() ?? '—'}) '
              'فعلاً ردت ${amt.toStringAsFixed(0)} ج.م قبل التأكيد. هذا '
              'الإجراء يُسجَّل في الـ audit log ولا يمكن التراجع عنه.',
              style: TextStyle(
                  fontSize: 12, color: context.kSub, height: 1.5),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, 'full'),
              icon: const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              label: Text('استرداد كامل (${amt.toStringAsFixed(0)} ج.م)',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'partial'),
              icon: const Icon(Icons.timelapse_rounded,
                  color: _kAmber, size: 18),
              label: const Text('استرداد جزئي',
                  style: TextStyle(
                      color: _kAmber,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _kAmber.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء',
                  style: TextStyle(
                      color: context.kSub, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
