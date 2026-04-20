// ═══════════════════════════════════════════════════════════════
//  TALAA — Wallet Page
//  User-facing balance + ledger + entry to referrals screen.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../services/wallet_service.dart';
import '../widgets/constants.dart';
import '../widgets/wallet_lottie.dart';
import 'referrals_page.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});
  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  WalletSummary? _summary;
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
      _summary = await WalletService.summary();
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
        title: const Text('محفظتي'),
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
              : _summary == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _balanceCard(_summary!),
                          const SizedBox(height: 14),
                          _topupCard(),
                          const SizedBox(height: 14),
                          _referralCard(_summary!),
                          const SizedBox(height: 14),
                          _historyHeader(),
                          const SizedBox(height: 8),
                          if (_summary!.recentTransactions.isEmpty)
                            _emptyHistory()
                          else
                            ..._summary!.recentTransactions
                                .map(_txnTile),
                        ],
                      ),
                    ),
    );
  }

  // ── balance card ──────────────────────────────────────
  Widget _balanceCard(WalletSummary s) {
    final fmt = intl.NumberFormat.currency(
      locale: 'ar_EG', symbol: 'ج.م ', decimalDigits: 2,
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF0077B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الرصيد الحالي',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(fmt.format(s.balance),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const WalletLottie.animated(size: 90),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: _miniStat(
                    label: 'مكتسب', value: fmt.format(s.lifetimeEarned))),
            Container(
              width: 1, height: 32, color: Colors.white24,
            ),
            Expanded(
                child: _miniStat(
                    label: 'مصروف', value: fmt.format(s.lifetimeSpent))),
          ]),
        ],
      ),
    );
  }

  Widget _miniStat({required String label, required String value}) =>
      Column(children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ]);

  // ── top-up card ─────────────────────────────────────
  Widget _topupCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openTopupSheet,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8A3D), Color(0xFFFF6D00)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6D00).withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.credit_card_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اشحن المحفظة',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                  SizedBox(height: 3),
                  Text('ادفع بالفيزا أو ماستركارد',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: Colors.white),
          ]),
        ),
      ),
    );
  }

  Future<void> _openTopupSheet() async {
    final added = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TopupSheet(),
    );
    if (added == null || added <= 0) return;
    try {
      _summary = await WalletService.topup(amount: added);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت إضافة ${added.toStringAsFixed(0)} ج.م إلى محفظتك'),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل الشحن: $e'),
          backgroundColor: const Color(0xFFEF5350),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ── referral promo card ──────────────────────────────
  Widget _referralCard(WalletSummary s) {
    final code = s.referralCode ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.kBorder),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.card_giftcard_rounded,
              color: AppColors.accent, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ادعُ صديقاً — اكسب 100 ج.م',
                  style: TextStyle(
                      color: context.kText,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('كودك: $code',
                  style: TextStyle(
                      color: context.kSub,
                      fontFamily: 'monospace',
                      fontSize: 12)),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReferralsPage()),
          ).then((_) => _load()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: const Text('ادعُ'),
        ),
      ]),
    );
  }

  // ── history ──────────────────────────────────────────
  Widget _historyHeader() => Row(children: [
        Icon(Icons.history_rounded, color: context.kSub, size: 18),
        const SizedBox(width: 6),
        Text('سجل العمليات',
            style: TextStyle(
                color: context.kText,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
      ]);

  Widget _emptyHistory() => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('لا توجد عمليات بعد',
              style: TextStyle(color: context.kSub)),
        ),
      );

  Widget _txnTile(WalletTxn t) {
    final isCredit = t.amount > 0;
    final color = isCredit ? Colors.green.shade600 : Colors.red.shade600;
    final fmt = intl.NumberFormat.currency(
      locale: 'ar_EG', symbol: 'ج.م ', decimalDigits: 2,
    );
    final sign = isCredit ? '+' : '-';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.kBorder),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: color, size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(walletTxnLabelAr(t.type),
                  style: TextStyle(
                      color: context.kText,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              if (t.description != null) ...[
                const SizedBox(height: 2),
                Text(t.description!,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.kSub, fontSize: 11)),
              ],
              const SizedBox(height: 2),
              Text(intl.DateFormat('dd/MM HH:mm').format(t.createdAt.toLocal()),
                  style: TextStyle(color: context.kSub, fontSize: 10)),
            ],
          ),
        ),
        Text('$sign${fmt.format(t.amount.abs())}',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Top-up bottom sheet
//
//  Quick-picks (100/200/500/1000 EGP) + custom amount, then returns
//  the chosen amount to the caller which posts it to /wallet/me/topup.
//  A real integration would route through the existing payment
//  gateway flow first; for the MVP we credit the wallet immediately.
// ══════════════════════════════════════════════════════════════
class _TopupSheet extends StatefulWidget {
  const _TopupSheet();
  @override
  State<_TopupSheet> createState() => _TopupSheetState();
}

class _TopupSheetState extends State<_TopupSheet> {
  static const _quickPicks = [100.0, 200.0, 500.0, 1000.0];
  double? _selected;
  final _customCtrl = TextEditingController();

  double? get _amount {
    if (_selected != null) return _selected;
    final parsed = double.tryParse(_customCtrl.text.trim());
    if (parsed != null && parsed > 0 && parsed <= 50000) return parsed;
    return null;
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.kBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(children: [
              const Icon(Icons.credit_card_rounded,
                  color: Color(0xFFFF6D00), size: 24),
              const SizedBox(width: 10),
              Text('اشحن المحفظة',
                  style: TextStyle(
                      color: context.kText,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 16),
            Text('اختر قيمة الشحن',
                style: TextStyle(color: context.kSub, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _quickPicks.map((amt) {
                final sel = _selected == amt;
                return ChoiceChip(
                  label: Text('${amt.toInt()} ج.م'),
                  selected: sel,
                  onSelected: (_) {
                    setState(() {
                      _selected = amt;
                      _customCtrl.clear();
                    });
                  },
                  selectedColor: const Color(0xFFFF6D00),
                  labelStyle: TextStyle(
                    color: sel ? Colors.white : context.kText,
                    fontWeight: FontWeight.w800,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _customCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              onChanged: (_) => setState(() => _selected = null),
              decoration: InputDecoration(
                labelText: 'أو اكتب مبلغاً آخر',
                hintText: 'مثلاً 750',
                suffixText: 'ج.م',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _amount == null
                    ? null
                    : () => Navigator.pop(context, _amount),
                icon: const Icon(Icons.lock_rounded, size: 18),
                label: Text(
                  _amount == null
                      ? 'ادفع الآن'
                      : 'ادفع ${_amount!.toStringAsFixed(0)} ج.م الآن',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6D00),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(0xFFFF6D00).withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text('دفع آمن عبر بوابة البنك',
                  style: TextStyle(color: context.kSub, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}
