// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin API Keys Page  (Wave 30)
//
//  Mint, list, revoke and rotate the platform's partner / integration
//  API keys.  Plaintext is shown ONCE on creation in a copy-once
//  dialog; afterwards only the prefix and SHA-256 hash live in DB,
//  so the secret can never be recovered.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

import '../../services/api_key_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';

const _kOcean = Color(0xFFFF6B35);
const _kRed = Color(0xFFEF5350);
const _kGreen = Color(0xFF4CAF50);
const _kAmber = Color(0xFFFFB300);

class AdminApiKeysPage extends StatefulWidget {
  const AdminApiKeysPage({super.key});
  @override
  State<AdminApiKeysPage> createState() => _AdminApiKeysPageState();
}

class _AdminApiKeysPageState extends State<AdminApiKeysPage> {
  bool _loading = true;
  List<ApiKeyItem> _items = [];
  List<String> _allowedScopes = [];
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiKeyService.list(),
        ApiKeyService.allowedScopes(),
      ]);
      _items = results[0] as List<ApiKeyItem>;
      _allowedScopes = results[1] as List<String>;
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التحميل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_allowedScopes.isEmpty) {
      _snack('لم يتم تحميل الصلاحيات بعد', _kRed);
      return;
    }
    final created = await Navigator.push<ApiKeyItem?>(
      context,
      MaterialPageRoute(
        builder: (_) => _ApiKeyCreatorPage(scopes: _allowedScopes),
      ),
    );
    if (created == null) return;
    if (!mounted) return;
    await _showPlaintextDialog(created);
    setState(() => _items.insert(0, created));
  }

  Future<void> _showPlaintextDialog(ApiKeyItem k) async {
    final secret = k.plaintext ?? '';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('نسخ المفتاح الآن — لن يظهر مرة أخرى',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: _kAmber,
                fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'هذه هي المرة الوحيدة التي سيظهر فيها المفتاح الكامل. خزّنه في مكان آمن قبل إغلاق هذه النافذة.',
              style: TextStyle(fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.kSand.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kAmber.withValues(alpha: 0.5)),
              ),
              child: SelectableText(
                secret,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: secret));
              _snack('تم النسخ ✅', _kGreen);
            },
            icon: const Icon(Icons.copy_rounded, size: 16, color: _kOcean),
            label: const Text('نسخ',
                style: TextStyle(
                    color: _kOcean, fontWeight: FontWeight.w800)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOcean,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('فهمت',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _revoke(ApiKeyItem k) async {
    final ok = await _confirm(
      title: 'إلغاء المفتاح',
      msg:
          'سيتم إيقاف هذا المفتاح فوراً.  الـ partner لن يستطيع إجراء أي طلب باستخدامه.',
      cta: 'إلغاء المفتاح',
      ctaColor: _kAmber,
    );
    if (!ok) return;
    setState(() => _busy.add(k.id));
    try {
      final updated = await ApiKeyService.revoke(k.id);
      if (!mounted) return;
      setState(() {
        final i = _items.indexWhere((x) => x.id == k.id);
        if (i != -1) _items[i] = updated;
      });
      _snack('تم إلغاء المفتاح', _kGreen);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busy.remove(k.id));
    }
  }

  Future<void> _delete(ApiKeyItem k) async {
    final ok = await _confirm(
      title: 'حذف المفتاح نهائياً',
      msg:
          'الحذف يفقد الـ audit trail.  الأفضل استخدام "إلغاء" بدلاً من "حذف".  متأكد؟',
      cta: 'حذف',
      ctaColor: _kRed,
    );
    if (!ok) return;
    setState(() => _busy.add(k.id));
    try {
      await ApiKeyService.delete(k.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((x) => x.id == k.id));
      _snack('تم الحذف', _kGreen);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busy.remove(k.id));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String msg,
    required String cta,
    required Color ctaColor,
  }) async {
    return (await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: ctaColor)),
            content:
                Text(msg, style: const TextStyle(fontSize: 13, height: 1.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('إلغاء',
                    style: TextStyle(
                        color: context.kSub, fontWeight: FontWeight.w700)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ctaColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(cta,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        )) ??
        false;
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
        title: const Text('مفاتيح API للشركاء',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: _kOcean,
        icon: const Icon(Icons.vpn_key_rounded, color: Colors.white),
        label: const Text('مفتاح جديد',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOcean))
          : RefreshIndicator(
              color: _kOcean,
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 100),
                        Icon(Icons.vpn_key_off_rounded,
                            size: 64,
                            color: context.kSub.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Center(
                          child: Text('لا توجد مفاتيح بعد',
                              style: TextStyle(
                                  color: context.kSub,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(12, 12, 12, 100),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final k = _items[i];
                        final revoked = k.isRevoked;
                        final accent =
                            revoked ? _kRed : (k.isExpired ? _kAmber : _kGreen);
                        return Container(
                          decoration: BoxDecoration(
                            color: context.kCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: accent.withValues(alpha: 0.4)),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.vpn_key_rounded,
                                      color: accent, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(k.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              decoration: revoked
                                                  ? TextDecoration
                                                      .lineThrough
                                                  : null,
                                              color: context.kText)),
                                      Text(
                                          '${k.keyPrefix}••• • ${intl.DateFormat('y/MM/dd').format(k.createdAt.toLocal())}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: context.kSub,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                      revoked
                                          ? 'مُلغى'
                                          : (k.isExpired
                                              ? 'منتهى'
                                              : 'نشط'),
                                      style: TextStyle(
                                          color: accent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ]),
                              if ((k.description ?? '').isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(k.description!,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context.kSub,
                                        height: 1.5)),
                              ],
                              const SizedBox(height: 10),
                              if (k.scopes.isNotEmpty)
                                Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final s in k.scopes)
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _kOcean.withValues(
                                                alpha: 0.10),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(s,
                                              style: const TextStyle(
                                                  color: _kOcean,
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.w800,
                                                  fontFamily: 'monospace')),
                                        ),
                                    ]),
                              const SizedBox(height: 10),
                              Row(children: [
                                Icon(Icons.bar_chart_rounded,
                                    size: 13, color: context.kSub),
                                const SizedBox(width: 4),
                                Text(
                                    '${k.usageCount} طلب  •  آخر استخدام ${k.lastUsedAt != null ? intl.DateFormat('y/MM/dd HH:mm').format(k.lastUsedAt!.toLocal()) : 'لم يستخدم بعد'}',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: context.kSub,
                                        fontWeight: FontWeight.w600)),
                              ]),
                              const SizedBox(height: 12),
                              Row(children: [
                                if (!revoked)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _busy.contains(k.id)
                                          ? null
                                          : () => _revoke(k),
                                      icon: const Icon(Icons.block_rounded,
                                          color: _kAmber, size: 16),
                                      label: const Text('إلغاء',
                                          style: TextStyle(
                                              color: _kAmber,
                                              fontWeight: FontWeight.w800)),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                            color: _kAmber.withValues(
                                                alpha: 0.5)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(11)),
                                      ),
                                    ),
                                  ),
                                if (!revoked) const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _busy.contains(k.id)
                                        ? null
                                        : () => _delete(k),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: _kRed,
                                        size: 16),
                                    label: const Text('حذف',
                                        style: TextStyle(
                                            color: _kRed,
                                            fontWeight: FontWeight.w800)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: _kRed.withValues(
                                              alpha: 0.5)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(11)),
                                    ),
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Creator page
// ═══════════════════════════════════════════════════════════════
class _ApiKeyCreatorPage extends StatefulWidget {
  final List<String> scopes;
  const _ApiKeyCreatorPage({required this.scopes});
  @override
  State<_ApiKeyCreatorPage> createState() => _ApiKeyCreatorPageState();
}

class _ApiKeyCreatorPageState extends State<_ApiKeyCreatorPage> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final Set<String> _selectedScopes = {};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _snack('الاسم مطلوب', _kRed);
      return;
    }
    if (_selectedScopes.isEmpty) {
      _snack('اختر صلاحية واحدة على الأقل', _kRed);
      return;
    }
    setState(() => _busy = true);
    try {
      final created = await ApiKeyService.create(
        name: _name.text.trim(),
        description:
            _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        scopes: _selectedScopes.toList(),
      );
      if (!mounted) return;
      Navigator.pop(context, created);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل الإنشاء: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busy = false);
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
    ));
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String label) => InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kOcean, width: 2),
          ),
        );

    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('مفتاح جديد',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: dec('اسم المفتاح'),
            maxLength: 120,
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _desc,
              maxLines: 3,
              decoration: dec('وصف الاستخدام (اختياري)')),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(bottom: 8, right: 4),
            child: Text('الصلاحيات',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: context.kSub)),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.kBorder),
            ),
            child: Column(
              children: [
                for (var i = 0; i < widget.scopes.length; i++) ...[
                  CheckboxListTile(
                    value: _selectedScopes.contains(widget.scopes[i]),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedScopes.add(widget.scopes[i]);
                        } else {
                          _selectedScopes.remove(widget.scopes[i]);
                        }
                      });
                    },
                    activeColor: _kOcean,
                    title: Text(widget.scopes[i],
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                  if (i < widget.scopes.length - 1)
                    Divider(
                        height: 1, color: context.kBorder),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.vpn_key_rounded,
                    color: Colors.white, size: 18),
            label: const Text('إنشاء وعرض المفتاح',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOcean,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
