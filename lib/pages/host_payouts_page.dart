// ═══════════════════════════════════════════════════════════════
//  TALAA — Host Payouts Page
//  Balance summary + bank accounts + payout history
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';

import '../services/payout_service.dart';
import '../widgets/constants.dart';

class HostPayoutsPage extends StatefulWidget {
  const HostPayoutsPage({super.key});
  @override
  State<HostPayoutsPage> createState() => _HostPayoutsPageState();
}

class _HostPayoutsPageState extends State<HostPayoutsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  HostPayoutSummary? _summary;
  List<BankAccount> _accounts = [];
  List<PayoutModel> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        PayoutService.mySummary(),
        PayoutService.listBankAccounts(),
        PayoutService.myPayouts(),
      ]);
      _summary = results[0] as HostPayoutSummary;
      _accounts = results[1] as List<BankAccount>;
      _history = results[2] as List<PayoutModel>;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        title: const Text('أرباحي'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'الأرصدة'),
            Tab(text: 'الحسابات'),
            Tab(text: 'السجل'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _balancesTab(),
                    _accountsTab(),
                    _historyTab(),
                  ],
                ),
    );
  }

  // ── Tab 1: Balances ─────────────────────────────────────
  Widget _balancesTab() {
    final s = _summary!;
    final df = intl.DateFormat('dd/MM/yyyy');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _balanceCard(
            title: 'الرصيد المتاح للسحب',
            value: s.pendingBalance,
            icon: Icons.account_balance_wallet_rounded,
            color: Colors.green,
            note:
                '${s.eligibleBookingCount} حجز مكتمل بعد فترة الحجز الاحتياطية',
          ),
          const SizedBox(height: 10),
          _balanceCard(
            title: 'قيد التحويل',
            value: s.queuedBalance,
            icon: Icons.sync_rounded,
            color: Colors.orange,
            note: 'في دفعات قيد المعالجة من الإدارة',
          ),
          const SizedBox(height: 10),
          _balanceCard(
            title: 'إجمالي المسحوب',
            value: s.paidTotal,
            icon: Icons.verified_rounded,
            color: AppColors.primary,
            note: s.lastPaidAt != null
                ? 'آخر تحويل: ${df.format(s.lastPaidAt!)}'
                : 'لم يتم تحويل أي مبلغ بعد',
          ),
          const SizedBox(height: 24),
          if (_accounts.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.orange.shade300, width: 1),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'أضف حساب بنكي أو محفظة قبل استحقاق أول تحويل',
                    style: TextStyle(color: Colors.orange.shade900),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _balanceCard({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: context.kSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${value.toStringAsFixed(0)} جنيه',
                  style: TextStyle(
                      color: context.kText,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(note,
                  style:
                      TextStyle(color: context.kSub, fontSize: 11)),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Tab 2: Accounts ─────────────────────────────────────
  Widget _accountsTab() {
    return Stack(children: [
      RefreshIndicator(
        onRefresh: _load,
        child: _accounts.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(40),
                children: [
                  Icon(Icons.account_balance_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('لم تضف حساب بنكي بعد',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _accounts.length,
                itemBuilder: (_, i) => _accountTile(_accounts[i]),
              ),
      ),
      Positioned(
        bottom: 16,
        right: 16,
        child: FloatingActionButton.extended(
          onPressed: _openAddAccountSheet,
          icon: const Icon(Icons.add),
          label: const Text('حساب جديد'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
    ]);
  }

  Widget _accountTile(BankAccount a) {
    IconData icon;
    switch (a.type) {
      case BankAccountType.iban:
        icon = Icons.account_balance_rounded;
        break;
      case BankAccountType.wallet:
        icon = Icons.phone_android_rounded;
        break;
      case BankAccountType.instapay:
        icon = Icons.flash_on_rounded;
        break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: a.isDefault
              ? AppColors.primary.withValues(alpha: 0.5)
              : context.kBorder,
          width: a.isDefault ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.primary, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(a.accountName,
                    style: TextStyle(
                        color: context.kText,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                const SizedBox(width: 6),
                if (a.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('افتراضي',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
              ]),
              const SizedBox(height: 2),
              Text(a.type.labelAr,
                  style: TextStyle(color: context.kSub, fontSize: 11)),
              const SizedBox(height: 2),
              Text(a.displayDetail,
                  style: TextStyle(
                      color: context.kSub,
                      fontSize: 12,
                      fontFamily: 'monospace')),
            ],
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'default' && !a.isDefault) {
              await PayoutService.updateBankAccount(a.id, isDefault: true);
              await _load();
            } else if (v == 'delete') {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('حذف الحساب'),
                  content: Text('هل تريد حذف "${a.accountName}"؟'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء')),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935)),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('حذف'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await PayoutService.deleteBankAccount(a.id);
                await _load();
              }
            }
          },
          itemBuilder: (_) => [
            if (!a.isDefault)
              const PopupMenuItem(
                  value: 'default', child: Text('تعيين كافتراضي')),
            const PopupMenuItem(
                value: 'delete',
                child: Text('حذف', style: TextStyle(color: Colors.red))),
          ],
        ),
      ]),
    );
  }

  Future<void> _openAddAccountSheet() async {
    final added = await showModalBottomSheet<BankAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddBankAccountSheet(),
    );
    if (added != null) await _load();
  }

  // ── Tab 3: History ──────────────────────────────────────
  Widget _historyTab() {
    if (_history.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(40),
          children: [
            Icon(Icons.history_rounded,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('لا يوجد سجل تحويلات بعد',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    final df = intl.DateFormat('dd MMM yyyy', 'ar');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        itemBuilder: (_, i) {
          final p = _history[i];
          Color statusColor;
          switch (p.status) {
            case PayoutStatus.paid:
              statusColor = Colors.green;
              break;
            case PayoutStatus.failed:
              statusColor = Colors.red;
              break;
            case PayoutStatus.processing:
              statusColor = const Color(0xFFFF6B35); // brand orange
              break;
            case PayoutStatus.pending:
              statusColor = Colors.orange;
              break;
          }
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
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: context.kText),
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
                Text(
                  '${df.format(p.cycleStart)} → ${df.format(p.cycleEnd)}',
                  style: TextStyle(color: context.kSub, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text('${p.items.length} حجز في هذا التحويل',
                    style: TextStyle(color: context.kSub, fontSize: 11)),
                if (p.referenceNumber != null) ...[
                  const SizedBox(height: 4),
                  Text('المرجع البنكي: ${p.referenceNumber}',
                      style: TextStyle(
                          color: context.kSub,
                          fontSize: 11,
                          fontFamily: 'monospace')),
                ],
                if (p.processedAt != null) ...[
                  const SizedBox(height: 2),
                  Text('تاريخ التحويل: ${df.format(p.processedAt!)}',
                      style: TextStyle(color: context.kSub, fontSize: 11)),
                ],
                // Wave 26 — automated disbursement proof block.  Only
                // shown when there's *something* to show (ie. not the
                // legacy ``not_started`` placeholder) so old manual
                // payouts keep their cleaner card layout.
                if (p.disburseStatus != DisburseStatus.not_started) ...[
                  const SizedBox(height: 10),
                  _disburseEvidenceCard(p),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Inline "proof of payment" card.
  ///
  /// On a **succeeded** disburse this is the strongest receipt the
  /// app can show: a green strip with the gateway reference, the
  /// timestamp, and (when the gateway returned one) a clickable
  /// receipt link the host can save / forward to their accountant.
  /// Failures get a red strip with a retry hint instead.
  Widget _disburseEvidenceCard(PayoutModel p) {
    final df = intl.DateFormat('dd MMM yyyy · HH:mm', 'ar');
    final isSuccess = p.disburseStatus.isTerminalSuccess;
    final isFailed = p.disburseStatus == DisburseStatus.failed;

    // Pick the accent based on the terminal state.  Pending /
    // initiated / processing share a neutral blue tone.
    final Color accent = isSuccess
        ? Colors.green.shade600
        : isFailed
            ? Colors.red.shade600
            : const Color(0xFFFF6B35); // brand orange
    final IconData icon = isSuccess
        ? Icons.verified_rounded
        : isFailed
            ? Icons.error_outline_rounded
            : Icons.sync_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                p.disburseStatus.labelAr,
                style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800),
              ),
            ),
            // Provider chip — small + muted; surfaces "Kashier" /
            // "mock" without dominating the row.
            if (p.disburseProvider != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  p.disburseProvider!.toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ]),
          if (p.disburseRef != null) ...[
            const SizedBox(height: 6),
            // Tappable to copy — hosts paste this into bank chat
            // when they want to chase a transfer.
            InkWell(
              onTap: () async {
                await Clipboard.setData(
                    ClipboardData(text: p.disburseRef!));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم نسخ رقم العملية'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: Row(children: [
                Icon(Icons.tag_rounded,
                    size: 13, color: context.kSub),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    p.disburseRef!,
                    style: TextStyle(
                        color: context.kText,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.copy_rounded,
                    size: 13, color: context.kSub),
              ]),
            ),
          ],
          if (p.disbursedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'تم التحويل: ${df.format(p.disbursedAt!)}',
              style: TextStyle(color: context.kSub, fontSize: 11),
            ),
          ],
          if (p.disburseReceiptUrl != null) ...[
            const SizedBox(height: 8),
            // Receipt button — opens the PDF / image in the browser
            // or PDF viewer.  Hidden when the gateway didn't return
            // one (Kashier IBAN transfers usually do; wallet pushes
            // sometimes don't).
            SizedBox(
              height: 32,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent.withValues(alpha: 0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => _openReceipt(p.disburseReceiptUrl!),
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text('فتح إيصال التحويل',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
          if (isFailed) ...[
            const SizedBox(height: 6),
            Text(
              'سيقوم فريق الدعم بإعادة المحاولة قريباً، أو تواصل معنا.',
              style: TextStyle(color: context.kSub, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openReceipt(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح الإيصال')),
      );
    }
  }
}


// ══════════════════════════════════════════════════════════════
//  Bottom-sheet: add bank account
// ══════════════════════════════════════════════════════════════
class _AddBankAccountSheet extends StatefulWidget {
  const _AddBankAccountSheet();
  @override
  State<_AddBankAccountSheet> createState() => _AddBankAccountSheetState();
}

class _AddBankAccountSheetState extends State<_AddBankAccountSheet> {
  BankAccountType _type = BankAccountType.iban;
  final _nameCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _instapayCtrl = TextEditingController();
  bool _isDefault = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bankCtrl.dispose();
    _ibanCtrl.dispose();
    _phoneCtrl.dispose();
    _instapayCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().length < 2) {
      setState(() => _error = 'اسم الحساب قصير جداً');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await PayoutService.addBankAccount(
        type: _type,
        accountName: _nameCtrl.text.trim(),
        bankName: _bankCtrl.text.trim().isEmpty
            ? null
            : _bankCtrl.text.trim(),
        iban: _type == BankAccountType.iban
            ? _ibanCtrl.text.replaceAll(' ', '').trim()
            : null,
        walletPhone: _type == BankAccountType.wallet
            ? _phoneCtrl.text.trim()
            : null,
        instapayAddress: _type == BankAccountType.instapay
            ? _instapayCtrl.text.trim()
            : null,
        isDefault: _isDefault,
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
              const Text('إضافة وسيلة استلام الأرباح',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              SegmentedButton<BankAccountType>(
                segments: const [
                  ButtonSegment(
                    value: BankAccountType.iban,
                    label: Text('بنك'),
                    icon: Icon(Icons.account_balance_rounded),
                  ),
                  ButtonSegment(
                    value: BankAccountType.wallet,
                    label: Text('محفظة'),
                    icon: Icon(Icons.phone_android_rounded),
                  ),
                  ButtonSegment(
                    value: BankAccountType.instapay,
                    label: Text('إنستا باي'),
                    icon: Icon(Icons.flash_on_rounded),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم صاحب الحساب',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_type == BankAccountType.iban) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _bankCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم البنك (CIB / NBE...)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _ibanCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'IBAN',
                    hintText: 'EG38…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_type == BankAccountType.wallet) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _bankCtrl,
                  decoration: const InputDecoration(
                    labelText: 'مزوّد المحفظة (Vodafone / Etisalat...)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم المحفظة',
                    hintText: '010xxxxxxxx',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_type == BankAccountType.instapay) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _instapayCtrl,
                  decoration: const InputDecoration(
                    labelText: 'عنوان إنستا باي',
                    hintText: 'name@bank',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('جعله الحساب الافتراضي'),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                contentPadding: EdgeInsets.zero,
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 14),
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
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('حفظ',
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
