// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Promo Banner Page  (Wave 30)
//
//  CRUD over the homepage carousel banners.  Each row shows:
//    • thumbnail of the hero image
//    • title (Arabic, fallback English)
//    • priority + active flag + scheduling window
//    • engagement (impressions/clicks)
//
//  The activation toggle is the most-used action — kept inline on
//  each card.  Editing opens a full editor sheet with image preview,
//  CTA picker, and date scheduling.
// ═══════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

import '../../services/promo_banner_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';

const _kOcean = Color(0xFFFF6B35);
const _kRed = Color(0xFFEF5350);
const _kGreen = Color(0xFF4CAF50);
const _kAmber = Color(0xFFFFB300);

class AdminPromoBannerPage extends StatefulWidget {
  const AdminPromoBannerPage({super.key});
  @override
  State<AdminPromoBannerPage> createState() =>
      _AdminPromoBannerPageState();
}

class _AdminPromoBannerPageState extends State<AdminPromoBannerPage> {
  bool _loading = true;
  List<PromoBannerItem> _items = [];
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await PromoBannerService.adminList();
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التحميل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(PromoBannerItem b) async {
    HapticFeedback.lightImpact();
    setState(() => _busy.add(b.id));
    try {
      final updated = await PromoBannerService.update(
          b.id, {'is_active': !b.isActive});
      if (!mounted) return;
      setState(() {
        final i = _items.indexWhere((x) => x.id == b.id);
        if (i != -1) _items[i] = updated;
      });
      _snack(
          updated.isActive ? 'تم تفعيل البانر' : 'تم تعطيل البانر', _kGreen);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busy.remove(b.id));
    }
  }

  Future<void> _openEditor({PromoBannerItem? existing}) async {
    final result = await Navigator.push<PromoBannerItem?>(
      context,
      MaterialPageRoute(
        builder: (_) => _BannerEditorPage(existing: existing),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        final idx = _items.indexWhere((x) => x.id == result.id);
        if (idx != -1) {
          _items[idx] = result;
        } else {
          _items.insert(0, result);
        }
      });
    }
  }

  Future<void> _delete(PromoBannerItem b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف البانر',
            style: TextStyle(fontWeight: FontWeight.w900, color: _kRed)),
        content: const Text(
            'لا يمكن استرجاع البانر بعد الحذف. متأكد؟',
            style: TextStyle(fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('إلغاء',
                  style: TextStyle(
                      color: context.kSub, fontWeight: FontWeight.w700))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('حذف',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy.add(b.id));
    try {
      await PromoBannerService.delete(b.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((x) => x.id == b.id));
      _snack('تم الحذف', _kGreen);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busy.remove(b.id));
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
        title: const Text('بانرات الواجهة الرئيسية',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: _kOcean,
        icon: const Icon(Icons.add_photo_alternate_rounded,
            color: Colors.white),
        label: const Text('بانر جديد',
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
                        Icon(Icons.image_outlined,
                            size: 64,
                            color: context.kSub.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Center(
                          child: Text('لا توجد بانرات بعد',
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
                        final b = _items[i];
                        return _BannerCard(
                          banner: b,
                          busy: _busy.contains(b.id),
                          onToggle: () => _toggleActive(b),
                          onEdit: () => _openEditor(existing: b),
                          onDelete: () => _delete(b),
                        );
                      },
                    ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Single banner card
// ═══════════════════════════════════════════════════════════════
class _BannerCard extends StatelessWidget {
  final PromoBannerItem banner;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BannerCard({
    required this.banner,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = banner.titleAr ??
        banner.titleEn ??
        '(بدون عنوان — بانر #${banner.id})';
    return Container(
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: banner.isActive
                ? _kGreen.withValues(alpha: 0.5)
                : context.kBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 7,
            child: Stack(fit: StackFit.expand, children: [
              CachedNetworkImage(
                imageUrl: banner.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: context.kBorder),
                errorWidget: (_, __, ___) => Container(
                  color: _kRed.withValues(alpha: 0.1),
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded,
                        color: _kRed, size: 40),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (banner.isActive ? _kGreen : context.kSub)
                        .withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(banner.isActive ? 'نشط' : 'متوقف',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.priority_high_rounded,
                            color: Colors.white, size: 12),
                        const SizedBox(width: 2),
                        Text('${banner.priority}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ]),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: context.kText)),
                if ((banner.subtitleAr ?? banner.subtitleEn ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        (banner.subtitleAr ?? banner.subtitleEn)!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: context.kSub,
                            height: 1.4)),
                  ),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _chip(context, Icons.touch_app_rounded,
                      _ctaArabic(banner.ctaKind), _kOcean),
                  _chip(context, Icons.visibility_rounded,
                      '${banner.impressions}', context.kSub),
                  _chip(context, Icons.ads_click_rounded,
                      '${banner.clicks}', context.kSub),
                  if (banner.startAt != null)
                    _chip(
                        context,
                        Icons.event_rounded,
                        'من ${intl.DateFormat('y/MM/dd').format(banner.startAt!.toLocal())}',
                        _kAmber),
                  if (banner.endAt != null)
                    _chip(
                        context,
                        Icons.event_busy_rounded,
                        'حتى ${intl.DateFormat('y/MM/dd').format(banner.endAt!.toLocal())}',
                        _kAmber),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: busy ? null : onToggle,
                      icon: busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Icon(
                              banner.isActive
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 16),
                      label: Text(banner.isActive ? 'تعطيل' : 'تفعيل',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            banner.isActive ? _kAmber : _kGreen,
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onEdit,
                      icon: const Icon(Icons.edit_rounded,
                          color: _kOcean, size: 16),
                      label: const Text('تعديل',
                          style: TextStyle(
                              color: _kOcean,
                              fontWeight: FontWeight.w800)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: _kOcean.withValues(alpha: 0.5)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onDelete,
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: _kRed, size: 16),
                      label: const Text('حذف',
                          style: TextStyle(
                              color: _kRed,
                              fontWeight: FontWeight.w800)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: _kRed.withValues(alpha: 0.5)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: c, size: 12),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                color: c, fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  String _ctaArabic(String kind) => switch (kind) {
        'deeplink' => 'رابط داخلي',
        'url' => 'رابط خارجي',
        'property' => 'عقار',
        'area' => 'منطقة',
        _ => 'بدون',
      };
}

// ═══════════════════════════════════════════════════════════════
//  Editor page (create + edit)
// ═══════════════════════════════════════════════════════════════
class _BannerEditorPage extends StatefulWidget {
  final PromoBannerItem? existing;
  const _BannerEditorPage({this.existing});
  @override
  State<_BannerEditorPage> createState() => _BannerEditorPageState();
}

class _BannerEditorPageState extends State<_BannerEditorPage> {
  late final _imageUrl =
      TextEditingController(text: widget.existing?.imageUrl ?? '');
  late final _titleAr =
      TextEditingController(text: widget.existing?.titleAr ?? '');
  late final _titleEn =
      TextEditingController(text: widget.existing?.titleEn ?? '');
  late final _subAr =
      TextEditingController(text: widget.existing?.subtitleAr ?? '');
  late final _subEn =
      TextEditingController(text: widget.existing?.subtitleEn ?? '');
  late final _accent =
      TextEditingController(text: widget.existing?.accentColor ?? '');
  late final _ctaTarget =
      TextEditingController(text: widget.existing?.ctaTarget ?? '');
  late final _priority = TextEditingController(
      text: (widget.existing?.priority ?? 0).toString());

  String _ctaKind = 'none';
  bool _isActive = false;
  DateTime? _startAt;
  DateTime? _endAt;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _ctaKind = widget.existing!.ctaKind;
      _isActive = widget.existing!.isActive;
      _startAt = widget.existing!.startAt;
      _endAt = widget.existing!.endAt;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _imageUrl,
      _titleAr,
      _titleEn,
      _subAr,
      _subEn,
      _accent,
      _ctaTarget,
      _priority,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = (isStart ? _startAt : _endAt) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startAt = picked;
      } else {
        _endAt = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_imageUrl.text.trim().isEmpty) {
      _snack('رابط الصورة مطلوب', _kRed);
      return;
    }
    final priority = int.tryParse(_priority.text.trim()) ?? 0;
    setState(() => _busy = true);
    try {
      PromoBannerItem result;
      if (widget.existing == null) {
        result = await PromoBannerService.create(
          imageUrl: _imageUrl.text.trim(),
          titleAr: _titleAr.text.trim().isEmpty ? null : _titleAr.text.trim(),
          titleEn: _titleEn.text.trim().isEmpty ? null : _titleEn.text.trim(),
          subtitleAr: _subAr.text.trim().isEmpty ? null : _subAr.text.trim(),
          subtitleEn: _subEn.text.trim().isEmpty ? null : _subEn.text.trim(),
          accentColor:
              _accent.text.trim().isEmpty ? null : _accent.text.trim(),
          ctaKind: _ctaKind,
          ctaTarget: _ctaTarget.text.trim().isEmpty
              ? null
              : _ctaTarget.text.trim(),
          priority: priority,
          isActive: _isActive,
          startAt: _startAt,
          endAt: _endAt,
        );
      } else {
        result = await PromoBannerService.update(widget.existing!.id, {
          'image_url': _imageUrl.text.trim(),
          'title_ar': _titleAr.text.trim().isEmpty ? null : _titleAr.text.trim(),
          'title_en': _titleEn.text.trim().isEmpty ? null : _titleEn.text.trim(),
          'subtitle_ar':
              _subAr.text.trim().isEmpty ? null : _subAr.text.trim(),
          'subtitle_en':
              _subEn.text.trim().isEmpty ? null : _subEn.text.trim(),
          'accent_color':
              _accent.text.trim().isEmpty ? null : _accent.text.trim(),
          'cta_kind': _ctaKind,
          'cta_target': _ctaTarget.text.trim().isEmpty
              ? null
              : _ctaTarget.text.trim(),
          'priority': priority,
          'is_active': _isActive,
          'start_at': _startAt?.toIso8601String(),
          'end_at': _endAt?.toIso8601String(),
        });
      }
      if (!mounted) return;
      Navigator.pop(context, result);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل: $e', _kRed);
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

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kOcean, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: Text(widget.existing == null ? 'بانر جديد' : 'تعديل البانر',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_imageUrl.text.trim().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: CachedNetworkImage(
                  imageUrl: _imageUrl.text.trim(),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: context.kBorder),
                  errorWidget: (_, __, ___) => Container(
                    color: _kRed.withValues(alpha: 0.1),
                    child: const Center(
                        child: Icon(Icons.broken_image_rounded,
                            color: _kRed, size: 32)),
                  ),
                ),
              ),
            ),
          if (_imageUrl.text.trim().isNotEmpty) const SizedBox(height: 14),
          TextField(
            controller: _imageUrl,
            decoration: _dec('رابط الصورة (URL)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(controller: _titleAr, decoration: _dec('العنوان عربى')),
          const SizedBox(height: 12),
          TextField(controller: _titleEn, decoration: _dec('Title (EN)')),
          const SizedBox(height: 12),
          TextField(
              controller: _subAr,
              maxLines: 2,
              decoration: _dec('السطر الفرعى عربى')),
          const SizedBox(height: 12),
          TextField(
              controller: _subEn,
              maxLines: 2,
              decoration: _dec('Subtitle (EN)')),
          const SizedBox(height: 12),
          TextField(
            controller: _accent,
            decoration: _dec('لون التركيز (Hex مثل #FF6B35)'),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _ctaKind,
            decoration: _dec('عند النقر'),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('بدون')),
              DropdownMenuItem(
                  value: 'deeplink', child: Text('رابط داخلي')),
              DropdownMenuItem(value: 'url', child: Text('رابط خارجى')),
              DropdownMenuItem(value: 'property', child: Text('عقار')),
              DropdownMenuItem(value: 'area', child: Text('منطقة')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _ctaKind = v);
            },
          ),
          if (_ctaKind != 'none') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _ctaTarget,
              decoration: _dec(_ctaTargetHint()),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _priority,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _dec('الأولوية (الأكبر يظهر أولاً)'),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(true),
                icon:
                    const Icon(Icons.event_rounded, color: _kOcean, size: 16),
                label: Text(
                    _startAt == null
                        ? 'بدء (افتراضى الآن)'
                        : 'بدء: ${intl.DateFormat('y/MM/dd').format(_startAt!)}',
                    style: const TextStyle(
                        color: _kOcean,
                        fontWeight: FontWeight.w800,
                        fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _kOcean.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(false),
                icon: const Icon(Icons.event_busy_rounded,
                    color: _kAmber, size: 16),
                label: Text(
                    _endAt == null
                        ? 'انتهاء (مفتوح)'
                        : 'انتهاء: ${intl.DateFormat('y/MM/dd').format(_endAt!)}',
                    style: const TextStyle(
                        color: _kAmber,
                        fontWeight: FontWeight.w800,
                        fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _kAmber.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          SwitchListTile(
            value: _isActive,
            activeThumbColor: _kGreen,
            onChanged: (v) => setState(() => _isActive = v),
            title: const Text('نشط',
                style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              'إذا أُلغيت، البانر يحفظ كمسودة ولا يظهر للمستخدمين.',
              style: TextStyle(fontSize: 11, color: context.kSub),
            ),
          ),
          const SizedBox(height: 18),
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

  String _ctaTargetHint() => switch (_ctaKind) {
        'deeplink' => 'مثال: talaa://property/123',
        'url' => 'مثال: https://example.com',
        'property' => 'رقم العقار (مثلاً: 123)',
        'area' => 'اسم المنطقة (مثلاً: الساحل الشمالى)',
        _ => '',
      };
}
