// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Withdrawal Requests
//  List pending/all owner withdrawal requests, approve or reject.
//  Approval triggers automatic Paymob disbursement on the backend.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

import '../../services/payout_service.dart';
import '../../widgets/constants.dart';

const _kOcean  = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF4CAF50);
const _kRed    = Color(0xFFEF5350);
const _kAmber  = Color(0xFFFFA726);
const _kPurple = Color(0xFF7E57C2);

class AdminWithdrawalRequestsPage extends StatefulWidget {
  const AdminWithdrawalRequestsPage({super.key});
  @override
  State<AdminWithdrawalRequestsPage> createState() =>
      _AdminWithdrawalRequestsPageState();
}

class _AdminWithdrawalRequestsPageState
    extends State<AdminWithdrawalRequestsPage> {
  List<WithdrawalRequest> _rows = [];
  WithdrawalStatus? _filter;
  bool _loading = true;
  String? _error;

  static const _filterLabels = <WithdrawalStatus?, String>{
    null: 'الكل',
    WithdrawalStatus.pendingAdminApproval: 'بانتظار الموافقة',
    WithdrawalStatus.approved: 'موافق عليه',
    WithdrawalStatus.completed: 'مكتمل',
    WithdrawalStatus.rejected: 'مرفوض',
    WithdrawalStatus.failed: 'فشل',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _rows = await PayoutService.adminListWithdrawals(status: _filter);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── Approve ────────────────────────────────────────────
  Future<void> _approve(WithdrawalRequest w) async {
    String notes = '';
    final confirmed = await _showActionDialog(
      title: 'الموافقة على طلب السحب؟',
      body:
          'سيتم تحويل ${w.amount.toStringAsFixed(0)} جنيه لـ ${w.ownerName ?? 'المالك'} عبر Paymob تلقائياً.',
      confirmLabel: 'موافقة ✅',
      confirmColor: _kGreen,
      notesHint: 'ملاحظات اختيارية...',
      onNotesChanged: (v) => notes = v,
    );
    if (confirmed != true) return;
    try {
      await PayoutService.adminApproveWithdrawal(w.id,
          notes: notes.trim().isNotEmpty ? notes.trim() : null);
      HapticFeedback.mediumImpact();
      _snack('تمت الموافقة — جاري إرسال التحويل', _kGreen);
      _load();
    } catch (e) {
      _snack('خطأ: ${e.toString().replaceAll("Exception: ", "")}', _kRed);
    }
  }

  // ── Reject ─────────────────────────────────────────────
  Future<void> _reject(WithdrawalRequest w) async {
    String notes = '';
    final confirmed = await _showActionDialog(
      title: 'رفض طلب السحب؟',
      body:
          'سيتم رفض الطلب وإعادة ${w.amount.toStringAsFixed(0)} جنيه للرصيد المتاح.',
      confirmLabel: 'رفض ❌',
      confirmColor: _kRed,
      notesHint: 'سبب الرفض (إجباري)...',
      notesRequired: true,
      onNotesChanged: (v) => notes = v,
    );
    if (confirmed != true) return;
    if (notes.trim().isEmpty) {
      _snack('يجب إدخال سبب الرفض', _kAmber);
      return;
    }
    try {
      await PayoutService.adminRejectWithdrawal(w.id, notes: notes.trim());
      HapticFeedback.mediumImpact();
      _snack('تم الرفض وإعادة الرصيد للمالك', _kAmber);
      _load();
    } catch (e) {
      _snack('خطأ: ${e.toString().replaceAll("Exception: ", "")}', _kRed);
    }
  }

  Future<bool?> _showActionDialog({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
    required String notesHint,
    bool notesRequired = false,
    required ValueChanged<String> onNotesChanged,
  }) {
    final ctrl = TextEditingController();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(body,
              style: TextStyle(fontSize: 13, color: context.kSub, height: 1.5)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            maxLines: 2,
            onChanged: onNotesChanged,
            decoration: InputDecoration(
              hintText: notesHint,
              hintStyle: const TextStyle(fontSize: 12),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _rows
        .where((r) => r.status == WithdrawalStatus.pendingAdminApproval)
        .length;

    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('طلبات السحب',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Colors.white)),
          if (pendingCount > 0)
            Text('$pendingCount طلب ينتظر موافقتك',
                style:
                    const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(children: [
        // ── Filter chips ──────────────────────────────────
        Container(
          color: _kOcean,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterLabels.entries.map((e) {
                final active = _filter == e.key;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _filter = e.key);
                      _load();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(e.value,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: active ? _kOcean : Colors.white)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // ── Body ──────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _kOcean))
              : _error != null
                  ? _errorState()
                  : _rows.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          color: _kOcean,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            itemCount: _rows.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) =>
                                _requestCard(_rows[i]),
                          ),
                        ),
        ),
      ]),
    );
  }

  // ── Request Card ──────────────────────────────────────
  Widget _requestCard(WithdrawalRequest w) {
    final df = intl.DateFormat('dd/MM/yyyy HH:mm');
    final isPending =
        w.status == WithdrawalStatus.pendingAdminApproval;

    Color statusColor;
    switch (w.status) {
      case WithdrawalStatus.pendingAdminApproval:
        statusColor = _kAmber;
        break;
      case WithdrawalStatus.approved:
      case WithdrawalStatus.disbursing:
        statusColor = _kPurple;
        break;
      case WithdrawalStatus.completed:
        statusColor = _kGreen;
        break;
      case WithdrawalStatus.rejected:
      case WithdrawalStatus.failed:
        statusColor = _kRed;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending
              ? _kAmber.withValues(alpha: 0.4)
              : context.kBorder,
          width: isPending ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.account_balance_wallet_rounded,
                  color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.ownerName ?? 'مالك #${w.ownerId}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: context.kText)),
                    Text(df.format(w.createdAt),
                        style:
                            TextStyle(fontSize: 11, color: context.kSub)),
                  ]),
            ),
            // Amount chip
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${w.amount.toStringAsFixed(0)} جنيه',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: statusColor),
              ),
            ),
          ]),

          // ── Status badge ───────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(w.status.labelAr,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor)),
              ),
            ]),
          ),

          // ── Bank snapshot ──────────────────────────────
          if (w.bankSnapshot != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _infoRow(Icons.person_rounded, 'اسم الحساب',
                w.bankSnapshot!.accountName),
            _infoRow(Icons.account_balance_rounded, 'تفاصيل البنك',
                w.bankSnapshot!.displayDetail),
          ],

          // ── Admin notes ────────────────────────────────
          if (w.adminNotes != null && w.adminNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.notes_rounded, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('ملاحظة: ${w.adminNotes}',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: context.kSub,
                          height: 1.4)),
                ),
              ]),
            ),
          ],

          // ── Disburse ref ───────────────────────────────
          if (w.disburseRef != null) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.receipt_rounded, 'مرجع التحويل',
                w.disburseRef!),
          ],

          // ── Action buttons (pending only) ──────────────
          if (isPending) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kRed,
                    side: const BorderSide(color: _kRed),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: () => _reject(w),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('رفض',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: () => _approve(w),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('موافقة وتحويل',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Icon(icon, size: 14, color: context.kSub),
        const SizedBox(width: 6),
        Text('$label: ',
            style: TextStyle(fontSize: 11.5, color: context.kSub)),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: context.kText)),
        ),
      ]),
    );
  }

  Widget _emptyState() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _kOcean.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                size: 34, color: _kOcean),
          ),
          const SizedBox(height: 14),
          Text('لا توجد طلبات سحب',
              style: TextStyle(
                  color: context.kText,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            _filter != null
                ? 'لا توجد طلبات بهذه الحالة'
                : 'لم يطلب أي مالك سحباً بعد',
            style: TextStyle(color: context.kSub, fontSize: 12.5),
          ),
        ]),
      );

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 52, color: Colors.grey),
            const SizedBox(height: 12),
            Text('تعذر تحميل البيانات',
                style: TextStyle(
                    color: context.kText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(_error ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.kSub, fontSize: 12)),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _kOcean),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ]),
        ),
      );
}
