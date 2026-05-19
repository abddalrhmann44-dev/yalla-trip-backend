// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Wallet Management Page
//
//  قائمة بجميع محافظ المستخدمين مع إمكانية:
//  • البحث بالاسم / الهاتف / الإيميل
//  • عرض الرصيد + إجمالي المكتسب + إجمالي المنفق
//  • فتح تفاصيل محفظة أي مستخدم وسجل معاملاته
//  • تعديل رصيد يدوي (إضافة / خصم) مع وصف السبب
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/wallet_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';

const _kOcean = Color(0xFFFF6B35);
const _kGreen = Color(0xFF4CAF50);
const _kRed   = Color(0xFFEF5350);

class AdminWalletManagementPage extends StatefulWidget {
  const AdminWalletManagementPage({super.key});
  @override
  State<AdminWalletManagementPage> createState() =>
      _AdminWalletManagementPageState();
}

class _AdminWalletManagementPageState
    extends State<AdminWalletManagementPage> {
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  List<AdminWalletRow> _rows = [];

  // ── Global stats (from /wallet/admin/stats) ───────────────
  double _outstanding = 0;
  double _lifetimeEarned = 0;
  double _lifetimeSpent = 0;
  int _totalWallets = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({String search = ''}) async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        WalletService.adminListWallets(search: search.isEmpty ? null : search),
        WalletService.adminStats(),
      ]);
      final rows = results[0] as List<AdminWalletRow>;
      final stats = results[1] as Map<String, dynamic>;
      setState(() {
        _rows = rows;
        _outstanding = (stats['outstanding_credit'] as num?)?.toDouble() ?? 0;
        _lifetimeEarned = (stats['lifetime_earned'] as num?)?.toDouble() ?? 0;
        _lifetimeSpent = (stats['lifetime_spent'] as num?)?.toDouble() ?? 0;
        _totalWallets = (stats['total_wallets'] as num?)?.toInt() ?? 0;
      });
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التحميل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading = false);
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

  // ── Open user wallet detail sheet ─────────────────────────
  void _openDetail(AdminWalletRow row) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _WalletDetailPage(row: row),
      ),
    ).then((_) => _load(search: _searchCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('إدارة المحافظ',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => _load(search: _searchCtrl.text.trim()),
          ),
        ],
      ),
      body: Column(children: [
        // ── Stats row ────────────────────────────────────────
        Container(
          color: _kOcean,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(children: [
            Row(children: [
              _statChip('المحافظ', '$_totalWallets', Icons.account_balance_wallet_rounded),
              const SizedBox(width: 8),
              _statChip('الرصيد القائم', '${_outstanding.toStringAsFixed(0)} ج.م',
                  Icons.savings_rounded),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _statChip('إجمالي المكتسب', '${_lifetimeEarned.toStringAsFixed(0)} ج.م',
                  Icons.trending_up_rounded),
              const SizedBox(width: 8),
              _statChip('إجمالي المنفق', '${_lifetimeSpent.toStringAsFixed(0)} ج.م',
                  Icons.shopping_cart_rounded),
            ]),
          ]),
        ),

        // ── Search ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: _searchCtrl,
            onSubmitted: (v) => _load(search: v.trim()),
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو الهاتف أو الإيميل...',
              hintStyle: TextStyle(
                  fontSize: 13, color: context.kSub),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _load();
                      })
                  : null,
              isDense: true,
              filled: true,
              fillColor: context.kCard,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),

        // ── List ─────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _kOcean))
              : _rows.isEmpty
                  ? Center(
                      child: Text('لا توجد نتائج',
                          style: TextStyle(
                              color: context.kSub,
                              fontWeight: FontWeight.w600)))
                  : RefreshIndicator(
                      color: _kOcean,
                      onRefresh: () =>
                          _load(search: _searchCtrl.text.trim()),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _walletTile(_rows[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _statChip(String label, String value, IconData icon) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: Colors.white70, size: 15),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      );

  Widget _walletTile(AdminWalletRow row) {
    final initials = (row.userName?.isNotEmpty == true)
        ? row.userName![0].toUpperCase()
        : '?';
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _openDetail(row);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.kBorder),
        ),
        child: Row(children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _kOcean.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(
                      color: _kOcean,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.userName ?? 'مستخدم #${row.userId}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: context.kText)),
                  const SizedBox(height: 2),
                  Text(row.userPhone ?? row.userEmail ?? '—',
                      style: TextStyle(
                          fontSize: 11,
                          color: context.kSub)),
                ]),
          ),
          // Balance
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: row.balance > 0
                    ? _kGreen.withValues(alpha: 0.1)
                    : context.kBorder,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${row.balance.toStringAsFixed(0)} ج.م',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: row.balance > 0 ? _kGreen : context.kSub),
              ),
            ),
            const SizedBox(height: 4),
            Text('منفق: ${row.lifetimeSpent.toStringAsFixed(0)} ج.م',
                style: TextStyle(fontSize: 10, color: context.kSub)),
          ]),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 13, color: context.kSub),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Wallet Detail Page
// ══════════════════════════════════════════════════════════════
class _WalletDetailPage extends StatefulWidget {
  final AdminWalletRow row;
  const _WalletDetailPage({required this.row});
  @override
  State<_WalletDetailPage> createState() => _WalletDetailPageState();
}

class _WalletDetailPageState extends State<_WalletDetailPage> {
  bool _loading = true;
  bool _adjusting = false;
  AdminWalletDetail? _detail;

  final _amountCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    try {
      final d = await WalletService.adminGetUserWallet(widget.row.userId);
      if (mounted) setState(() => _detail = d);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التحميل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _adjust(bool isCredit) async {
    final raw = _amountCtrl.text.trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      _snack('أدخل مبلغ صحيح أكبر من صفر', _kRed);
      return;
    }
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      _snack('أدخل سبب التعديل', _kRed);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(
            isCredit ? 'تأكيد إضافة رصيد' : 'تأكيد خصم رصيد',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
            '${isCredit ? '+' : '-'}${amount.toStringAsFixed(0)} ج.م\n$desc',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCredit ? _kGreen : _kRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isCredit ? 'إضافة' : 'خصم',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _adjusting = true);
    try {
      await WalletService.adminAdjust(
        userId: widget.row.userId,
        amount: isCredit ? amount : -amount,
        description: desc,
      );
      _amountCtrl.clear();
      _descCtrl.clear();
      HapticFeedback.mediumImpact();
      _snack(
          isCredit ? 'تم إضافة الرصيد ✅' : 'تم خصم الرصيد ✅', _kGreen);
      await _loadDetail();
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التعديل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _adjusting = false);
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
    final d = _detail;
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: Text(
            d?.userName ?? widget.row.userName ?? 'محفظة المستخدم',
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 16)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOcean))
          : d == null
              ? Center(
                  child: Text('تعذّر تحميل المحفظة',
                      style: TextStyle(color: context.kSub)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Balance card ──────────────────────────
                    _balanceCard(d),
                    const SizedBox(height: 16),

                    // ── Manual adjust ─────────────────────────
                    _adjustCard(),
                    const SizedBox(height: 20),

                    // ── Transactions ──────────────────────────
                    Text('سجل المعاملات',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: context.kText)),
                    const SizedBox(height: 10),
                    if (d.transactions.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text('لا توجد معاملات',
                              style: TextStyle(color: context.kSub)),
                        ),
                      )
                    else
                      ...d.transactions.map(_txnTile),
                  ],
                ),
    );
  }

  Widget _balanceCard(AdminWalletDetail d) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFE65100), _kOcean]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('الرصيد الحالي',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text('${d.balance.toStringAsFixed(2)} ج.م',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Row(children: [
            _miniStat('المكتسب', d.lifetimeEarned),
            const SizedBox(width: 16),
            _miniStat('المنفق', d.lifetimeSpent),
            if (d.referralCode != null) ...[
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('كود الإحالة',
                    style: TextStyle(color: Colors.white60, fontSize: 10)),
                const SizedBox(height: 2),
                Text(d.referralCode!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
              ]),
            ],
          ]),
        ]),
      );

  Widget _miniStat(String label, double val) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
        const SizedBox(height: 2),
        Text('${val.toStringAsFixed(0)} ج.م',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      ]);

  Widget _adjustCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.kBorder),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Icon(Icons.tune_rounded, color: _kOcean, size: 18),
            const SizedBox(width: 8),
            Text('تعديل رصيد يدوي',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: context.kText)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            decoration: InputDecoration(
              labelText: 'المبلغ (ج.م)',
              prefixText: 'ج.م  ',
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: _kOcean, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descCtrl,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: 'سبب التعديل',
              hintText: 'مثلاً: تعويض عن مشكلة في الحجز',
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: _kOcean, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _adjusting ? null : () => _adjust(false),
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    size: 17, color: _kRed),
                label: const Text('خصم',
                    style: TextStyle(
                        color: _kRed, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kRed),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _adjusting ? null : () => _adjust(true),
                icon: _adjusting
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_circle_outline_rounded,
                        size: 17, color: Colors.white),
                label: const Text('إضافة',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ]),
      );

  Widget _txnTile(WalletTxn txn) {
    final isCredit = txn.amount > 0;
    final color = isCredit ? _kGreen : _kRed;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.kBorder),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isCredit
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(walletTxnLabelAr(txn.type),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.kText)),
            if (txn.description != null)
              Text(txn.description!,
                  style: TextStyle(fontSize: 11, color: context.kSub),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            Text(
                '${txn.createdAt.day}/${txn.createdAt.month}/${txn.createdAt.year}',
                style: TextStyle(fontSize: 10, color: context.kSub)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '${isCredit ? '+' : ''}${txn.amount.toStringAsFixed(0)} ج.م',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: color),
          ),
          Text('رصيد: ${txn.balanceAfter.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 10, color: context.kSub)),
        ]),
      ]),
    );
  }
}
