// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin A/B Testing & Feature Flags  (Wave 30)
//
//  CRUD over the ``feature_flags`` table.  Each flag drives a
//  rollout / experiment in the public app:
//
//    • boolean  — straight on/off (e.g. "new_search_page").
//    • rollout  — gradual % rollout (0-100).
//    • ab_test  — split traffic between two variants.
//
//  Sticky per-user assignments live in
//  ``feature_flag_assignments``; the admin can wipe them with
//  "Reset assignments" when an experiment ends.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

import '../../services/feature_flag_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';

const _kOcean = Color(0xFFFF6B35);
const _kRed = Color(0xFFEF5350);
const _kGreen = Color(0xFF4CAF50);
const _kAmber = Color(0xFFFFB300);
const _kPurple = Color(0xFF7E57C2);

class AdminAbTestingPage extends StatefulWidget {
  const AdminAbTestingPage({super.key});
  @override
  State<AdminAbTestingPage> createState() => _AdminAbTestingPageState();
}

class _AdminAbTestingPageState extends State<AdminAbTestingPage> {
  bool _loading = true;
  List<FeatureFlagItem> _items = [];
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await FeatureFlagService.list();
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التحميل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(FeatureFlagItem f) async {
    HapticFeedback.lightImpact();
    setState(() => _busy.add(f.id));
    try {
      final updated = await FeatureFlagService.update(
        f.id,
        enabled: !f.enabled,
        note: 'Toggled via admin dashboard',
      );
      if (!mounted) return;
      setState(() {
        final i = _items.indexWhere((x) => x.id == f.id);
        if (i != -1) _items[i] = updated;
      });
      _snack(
        updated.enabled ? 'تم تفعيل ${f.key}' : 'تم تعطيل ${f.key}',
        _kGreen,
      );
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التعديل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busy.remove(f.id));
    }
  }

  Future<void> _editRollout(FeatureFlagItem f) async {
    final ctrl =
        TextEditingController(text: f.rolloutPercent.toString());
    final newVal = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تعديل نسبة الروول-أوت',
            style:
                TextStyle(fontWeight: FontWeight.w900, color: context.kText)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(f.key,
              style: const TextStyle(
                  fontSize: 12,
                  color: _kOcean,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'نسبة (0-100)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء',
                style: TextStyle(
                    color: context.kSub, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim()) ?? -1;
              if (v < 0 || v > 100) return;
              Navigator.pop(context, v);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOcean,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('حفظ',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (newVal == null) return;
    setState(() => _busy.add(f.id));
    try {
      final updated = await FeatureFlagService.update(
        f.id,
        rolloutPercent: newVal,
      );
      if (!mounted) return;
      setState(() {
        final i = _items.indexWhere((x) => x.id == f.id);
        if (i != -1) _items[i] = updated;
      });
      _snack('تم تعديل النسبة إلى $newVal%', _kGreen);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busy.remove(f.id));
    }
  }

  Future<void> _delete(FeatureFlagItem f) async {
    final ok = await _confirm(
      title: 'حذف العلامة',
      msg: 'سيتم حذف "${f.key}" نهائياً مع كل التعيينات (${f.assignmentCount}). متأكد؟',
      ctaColor: _kRed,
      cta: 'حذف',
    );
    if (!ok) return;
    setState(() => _busy.add(f.id));
    try {
      await FeatureFlagService.delete(f.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((x) => x.id == f.id));
      _snack('تم الحذف', _kGreen);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busy.remove(f.id));
    }
  }

  Future<void> _resetAssignments(FeatureFlagItem f) async {
    final ok = await _confirm(
      title: 'إعادة ضبط التعيينات',
      msg: 'سيتم مسح ${f.assignmentCount} تعيين. الـ A/B buckets ستـ rebuild من جديد عند الـ evaluations القادمة.',
      ctaColor: _kAmber,
      cta: 'تأكيد',
    );
    if (!ok) return;
    setState(() => _busy.add(f.id));
    try {
      await FeatureFlagService.resetAssignments(f.id);
      if (!mounted) return;
      _snack('تم مسح التعيينات', _kGreen);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busy.remove(f.id));
    }
  }

  Future<void> _openCreator() async {
    final created = await Navigator.push<FeatureFlagItem?>(
      context,
      MaterialPageRoute(builder: (_) => const _FeatureFlagCreatorPage()),
    );
    if (created != null && mounted) {
      setState(() => _items.insert(0, created));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String msg,
    required Color ctaColor,
    required String cta,
  }) async {
    return (await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title:
                Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: ctaColor)),
            content: Text(msg,
                style: const TextStyle(fontSize: 13, height: 1.5)),
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
                        color: Colors.white,
                        fontWeight: FontWeight.w800)),
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

  Color _kindColor(String kind) => switch (kind) {
        'rollout' => _kAmber,
        'ab_test' => _kPurple,
        _ => _kOcean,
      };

  String _kindAr(String kind) => switch (kind) {
        'rollout' => 'تدريجي',
        'ab_test' => 'A/B تجربة',
        _ => 'تشغيل/إيقاف',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('Feature Flags / A-B Testing',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreator,
        backgroundColor: _kOcean,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('علامة جديدة',
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
                        Icon(Icons.flag_rounded,
                            size: 64,
                            color: context.kSub.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Center(
                          child: Text('لا توجد علامات بعد — أضف أول علامة',
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
                        final f = _items[i];
                        final kc = _kindColor(f.kind);
                        return Container(
                          decoration: BoxDecoration(
                            color: context.kCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: context.kBorder),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        kc.withValues(alpha: 0.12),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.flag_rounded,
                                      color: kc, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(f.key,
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: context.kText)),
                                      if ((f.description ?? '').isNotEmpty)
                                        Text(f.description!,
                                            maxLines: 2,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: context.kSub,
                                                fontWeight:
                                                    FontWeight.w500,
                                                height: 1.4)),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: f.enabled,
                                  activeThumbColor: _kGreen,
                                  onChanged: _busy.contains(f.id)
                                      ? null
                                      : (_) => _toggle(f),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              Wrap(spacing: 6, runSpacing: 6, children: [
                                _chip(_kindAr(f.kind), kc),
                                if (f.kind == 'rollout' ||
                                    f.kind == 'ab_test')
                                  GestureDetector(
                                    onTap: _busy.contains(f.id)
                                        ? null
                                        : () => _editRollout(f),
                                    child: _chip(
                                        '${f.rolloutPercent}%', _kAmber,
                                        leadingIcon:
                                            Icons.percent_rounded),
                                  ),
                                _chip('${f.assignmentCount} تعيين',
                                    context.kSub),
                                _chip(
                                    intl.DateFormat('y/MM/dd')
                                        .format(f.updatedAt.toLocal()),
                                    context.kSub,
                                    leadingIcon: Icons.update_rounded),
                              ]),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _busy.contains(f.id)
                                        ? null
                                        : () => _resetAssignments(f),
                                    icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 16,
                                        color: _kAmber),
                                    label: const Text(
                                        'مسح التعيينات',
                                        style: TextStyle(
                                            color: _kAmber,
                                            fontWeight:
                                                FontWeight.w800)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: _kAmber.withValues(
                                              alpha: 0.5)),
                                      padding:
                                          const EdgeInsets.symmetric(
                                              vertical: 10),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(11)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _busy.contains(f.id)
                                        ? null
                                        : () => _delete(f),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                        color: _kRed),
                                    label: const Text('حذف',
                                        style: TextStyle(
                                            color: _kRed,
                                            fontWeight:
                                                FontWeight.w800)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: _kRed.withValues(
                                              alpha: 0.5)),
                                      padding:
                                          const EdgeInsets.symmetric(
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

  Widget _chip(String text, Color color, {IconData? leadingIcon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, color: color, size: 12),
          const SizedBox(width: 4),
        ],
        Text(text,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Creator page
// ═══════════════════════════════════════════════════════════════
class _FeatureFlagCreatorPage extends StatefulWidget {
  const _FeatureFlagCreatorPage();
  @override
  State<_FeatureFlagCreatorPage> createState() =>
      _FeatureFlagCreatorPageState();
}

class _FeatureFlagCreatorPageState
    extends State<_FeatureFlagCreatorPage> {
  final _key = TextEditingController();
  final _desc = TextEditingController();
  final _variantA = TextEditingController(text: 'control');
  final _variantB = TextEditingController(text: 'experiment');
  final _rollout = TextEditingController(text: '0');
  String _kind = 'boolean';
  bool _enabled = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_key, _desc, _variantA, _variantB, _rollout]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final key = _key.text.trim().toLowerCase();
    if (key.isEmpty) {
      _snack('المفتاح مطلوب', _kRed);
      return;
    }
    final pct = int.tryParse(_rollout.text.trim()) ?? 0;
    if (pct < 0 || pct > 100) {
      _snack('النسبة يجب أن تكون 0-100', _kRed);
      return;
    }
    setState(() => _busy = true);
    try {
      final created = await FeatureFlagService.create(
        key: key,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        kind: _kind,
        enabled: _enabled,
        rolloutPercent: pct,
        variantA: _kind == 'ab_test' ? _variantA.text.trim() : null,
        variantB: _kind == 'ab_test' ? _variantB.text.trim() : null,
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
        title: const Text('علامة جديدة',
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
            controller: _key,
            decoration: dec('Key (lower_snake_case)'),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _desc,
              maxLines: 3,
              decoration: dec('وصف مختصر')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: dec('النوع'),
            items: const [
              DropdownMenuItem(value: 'boolean', child: Text('تشغيل / إيقاف')),
              DropdownMenuItem(
                  value: 'rollout', child: Text('تدريجي (نسبة %)')),
              DropdownMenuItem(value: 'ab_test', child: Text('A/B تجربة')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _kind = v);
            },
          ),
          if (_kind == 'rollout' || _kind == 'ab_test') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _rollout,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: dec('النسبة الابتدائية (%)'),
            ),
          ],
          if (_kind == 'ab_test') ...[
            const SizedBox(height: 12),
            TextField(
                controller: _variantA, decoration: dec('Variant A')),
            const SizedBox(height: 12),
            TextField(
                controller: _variantB, decoration: dec('Variant B')),
          ],
          const SizedBox(height: 16),
          SwitchListTile(
            value: _enabled,
            activeThumbColor: _kGreen,
            onChanged: (v) => setState(() => _enabled = v),
            title: const Text('تفعيل فوراً',
                style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              'إذا أُلغيت، الـ flag يتم إنشاؤه لكنه يبقى inactive حتى الموافقة لاحقاً.',
              style: TextStyle(fontSize: 11, color: context.kSub),
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
                : const Icon(Icons.save_rounded,
                    color: Colors.white, size: 18),
            label: const Text('حفظ',
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
