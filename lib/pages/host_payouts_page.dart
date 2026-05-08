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
        title: const Text(
          'أرباحي',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        // Critical fix — explicit label colors so the tab text stops
        // “disappearing” against the orange app bar (default labelColor
        // pulls from ColorScheme.primary which collides here).
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
          tabs: const [
            Tab(text: 'الأرصدة'),
            Tab(text: 'الحسابات'),
            Tab(text: 'السجل'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _errorState()
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

  // ── Error state ─────────────────────────────────────────────
  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 56, color: context.kSub),
            const SizedBox(height: 12),
            Text(
              'تعذّر تحميل بيانات الأرباح',
              style: TextStyle(
                color: context.kText,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.kSub, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Balances ───────────────────────────────────
  // Hero card on top (the number the host actually cares about),
  // followed by two compact stat tiles and an inline call-to-action
  // when no payout method is on file.  Generous spacing + soft
  // shadows keep the page calm to read.
  Widget _balancesTab() {
    final s = _summary!;
    final df = intl.DateFormat('dd/MM/yyyy');
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          _heroBalanceCard(
            value: s.pendingBalance,
            eligibleBookings: s.eligibleBookingCount,
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _statTile(
                icon: Icons.sync_rounded,
                color: Colors.orange.shade700,
                title: 'قيد التحويل',
                value: s.queuedBalance.toStringAsFixed(0),
                suffix: 'جنيه',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statTile(
                icon: Icons.verified_rounded,
                color: AppColors.primary,
                title: 'إجمالي المسحوب',
                value: s.paidTotal.toStringAsFixed(0),
                suffix: 'جنيه',
              ),
            ),
          ]),
          const SizedBox(height: 8),
          if (s.lastPaidAt != null)
            Padding(
              padding: const EdgeInsets.only(right: 4, top: 4),
              child: Text(
                'آخر تحويل: ${df.format(s.lastPaidAt!)}',
                style: TextStyle(color: context.kSub, fontSize: 11.5),
              ),
            ),
          if (_accounts.isEmpty) ...[
            const SizedBox(height: 18),
            _ctaCard(
              icon: Icons.account_balance_rounded,
              title: 'أضف حسابك البنكي',
              body:
                  'علشان نقدر نحوّللك الأرباح فور استحقاقها، سجّل IBAN جديد.',
              cta: 'إضافة حساب الآن',
              onTap: () {
                _tabs.animateTo(1);
                _openAddAccountSheet();
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Big gradient card that anchors the page — the available balance
  /// is the single most important number for the host so we give it
  /// a confident, branded treatment.
  Widget _heroBalanceCard({
    required double value,
    required int eligibleBookings,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFF8A65), Color(0xFFFF6B35)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'الرصيد المتاح للسحب',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.toStringAsFixed(0),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'جنيه',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.event_available_rounded,
                  color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(
                '$eligibleBookings حجز مكتمل',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  /// Compact stat tile used in the row beneath the hero card.
  Widget _statTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String suffix,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.kSub,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  color: context.kText,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: ' $suffix',
                style: TextStyle(
                  color: context.kSub,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  /// Full-width call-to-action panel — used in the Balances tab when
  /// the host has zero registered payout methods.
  Widget _ctaCard({
    required IconData icon,
    required String title,
    required String body,
    required String cta,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.kText,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              color: context.kSub,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onTap,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                cta,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Accounts ───────────────────────────────────
  Widget _accountsTab() {
    return Stack(children: [
      RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _accounts.isEmpty
            ? _accountsEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                itemCount: _accounts.length,
                itemBuilder: (_, i) => _accountTile(_accounts[i]),
              ),
      ),
      Positioned(
        bottom: 16,
        right: 16,
        child: FloatingActionButton.extended(
          onPressed: _openAddAccountSheet,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'حساب جديد',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 3,
        ),
      ),
    ]);
  }

  /// Friendlier empty state for the Accounts tab — the previous one
  /// was just a faint icon + line which the user could miss.  Now we
  /// surface a centred panel + a primary action so the next step is
  /// unmistakable.
  Widget _accountsEmptyState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 60),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: context.kCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.kBorder),
          ),
          child: Column(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_outlined,
                  size: 38,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'مفيش حساب بنكي لسّة',
                style: TextStyle(
                  color: context.kText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'سجّل حساب IBAN عشان نقدر نحوّللك الأرباح فور استحقاقها.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.kSub,
                  fontSize: 12.5,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _openAddAccountSheet,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'إضافة حساب بنكي',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: a.isDefault
              ? AppColors.primary.withValues(alpha: 0.5)
              : context.kBorder,
          width: a.isDefault ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
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
  // Wave 27 (UX): The "wallet" and "instapay" payout channels were
  // removed from the UI by product decision — hosts can only register
  // a bank IBAN now.  We deliberately keep ``BankAccountType.wallet``
  // and ``BankAccountType.instapay`` alive in the service layer so
  // any legacy accounts created before this change still display
  // correctly in the list above (with their own icon + masked
  // detail).  New accounts always submit as ``BankAccountType.iban``.
  static const _kType = BankAccountType.iban;

  final _nameCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  bool _isDefault = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bankCtrl.dispose();
    _ibanCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().length < 2) {
      setState(() => _error = 'اسم الحساب قصير جداً');
      return;
    }
    final iban = _ibanCtrl.text.replaceAll(' ', '').trim();
    if (iban.length < 15) {
      setState(() => _error = 'رقم الـ IBAN غير صحيح');
      return;
    }
    if (_bankCtrl.text.trim().isEmpty) {
      setState(() => _error = 'اكتب اسم البنك');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await PayoutService.addBankAccount(
        type: _kType,
        accountName: _nameCtrl.text.trim(),
        bankName: _bankCtrl.text.trim(),
        iban: iban,
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
              const SizedBox(height: 6),
              Text(
                'الأرباح تتحوّل على حسابك البنكى عبر IBAN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم صاحب الحساب',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bankCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم البنك (CIB / NBE / QNB...)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_rounded),
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
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
              ),
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
