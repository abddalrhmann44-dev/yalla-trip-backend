// ═══════════════════════════════════════════════════════════════
//  TALAA — Referrals Page
//  Displays the user's referral code, share link, and history.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:share_plus/share_plus.dart';

import '../services/wallet_service.dart';
import '../widgets/constants.dart';

class ReferralsPage extends StatefulWidget {
  const ReferralsPage({super.key});
  @override
  State<ReferralsPage> createState() => _ReferralsPageState();
}

class _ReferralsPageState extends State<ReferralsPage> {
  ReferralSummary? _summary;
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
      _summary = await WalletService.referrals();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الكود')),
    );
  }

  Future<void> _share(ReferralSummary s) async {
    final msg = '''
انضم إلي على تالاا واحصل على أفضل الأماكن للإيجار!
كودي: ${s.referralCode}
${s.referralLink}
''';
    await Share.share(msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        title: const Text('ادعُ صديقاً'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
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
                          _hero(_summary!),
                          const SizedBox(height: 18),
                          _stats(_summary!),
                          const SizedBox(height: 20),
                          _historyHeader(),
                          const SizedBox(height: 8),
                          if (_summary!.referrals.isEmpty)
                            _empty()
                          else
                            ..._summary!.referrals.map(_refTile),
                        ],
                      ),
                    ),
    );
  }

  // ── hero card ────────────────────────────────────────
  Widget _hero(ReferralSummary s) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, Color(0xFFFF8A00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.card_giftcard_rounded,
              color: Colors.white, size: 32),
          const SizedBox(height: 10),
          const Text('احصل على 100 ج.م',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text(
            'عن كل صديق يسجّل بكودك ويُكمل أول حجز.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white38),
            ),
            child: Row(children: [
              Expanded(
                child: SelectableText(
                  s.referralCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Colors.white),
                onPressed: () => _copy(s.referralCode),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _share(s),
              icon: const Icon(Icons.share_rounded),
              label: const Text('مشاركة الدعوة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats(ReferralSummary s) {
    final fmt = intl.NumberFormat.currency(
      locale: 'ar_EG', symbol: 'ج.م ', decimalDigits: 2,
    );
    return Row(children: [
      Expanded(
          child: _statCard(
              label: 'الإجمالي',
              value: '${s.totalReferrals}',
              color: Colors.blueGrey)),
      const SizedBox(width: 8),
      Expanded(
          child: _statCard(
              label: 'مكافآت',
              value: '${s.rewardedCount}',
              color: Colors.green)),
      const SizedBox(width: 8),
      Expanded(
          child: _statCard(
              label: 'قيد',
              value: '${s.pendingCount}',
              color: Colors.orange)),
      const SizedBox(width: 8),
      Expanded(
          child: _statCard(
              label: 'أرباحك',
              value: fmt.format(s.totalEarned),
              color: AppColors.primary)),
    ]);
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.kBorder),
        ),
        child: Column(children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: context.kSub, fontSize: 10)),
        ]),
      );

  Widget _historyHeader() => Row(children: [
        Icon(Icons.people_alt_outlined, color: context.kSub, size: 18),
        const SizedBox(width: 6),
        Text('الأصدقاء المدعوون',
            style: TextStyle(
                color: context.kText,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
      ]);

  Widget _empty() => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(children: [
            Icon(Icons.hourglass_empty_rounded,
                size: 48, color: context.kSub),
            const SizedBox(height: 6),
            Text('لا يوجد دعوات بعد',
                style: TextStyle(color: context.kSub)),
          ]),
        ),
      );

  Widget _refTile(ReferralEntry r) {
    Color color;
    switch (r.status) {
      case ReferralStatus.rewarded:
        color = Colors.green;
        break;
      case ReferralStatus.pending:
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }
    final fmt = intl.NumberFormat.currency(
      locale: 'ar_EG', symbol: 'ج.م ', decimalDigits: 2,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.kBorder),
      ),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.person_rounded, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.inviteeName ?? 'صديق #${r.inviteeId}',
                  style: TextStyle(
                      color: context.kText,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                intl.DateFormat('dd/MM/yyyy').format(r.createdAt.toLocal()),
                style: TextStyle(color: context.kSub, fontSize: 11),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(referralStatusLabelAr(r.status),
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 11)),
            ),
            if (r.rewardAmount != null) ...[
              const SizedBox(height: 4),
              Text('+${fmt.format(r.rewardAmount!)}',
                  style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ]),
    );
  }
}
