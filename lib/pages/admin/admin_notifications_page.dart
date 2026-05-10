// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Notifications Page  (Wave 30)
//
//  Compose & broadcast push notification campaigns.  Wraps the
//  ``/campaigns`` admin endpoints — every campaign is fanned out via
//  the existing ``push_to_user`` pipeline so deliveries land on the
//  user's phone (FCM) and inside the in-app inbox.
//
//  Workflow:
//    1) Tap the floating "+ بث جديد" button.
//    2) Compose title + body (Arabic required, English optional).
//    3) Pick audience (all / hosts / guests / by area / recent
//       bookers) and any filters that apply.
//    4) Preview audience size.
//    5) Send.  Once sent, the row flips to ``sent`` with delivery
//       stats (target_count, success_count).
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

import '../../services/campaign_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';

const _kOcean = Color(0xFFFF6B35);
const _kRed = Color(0xFFEF5350);
const _kGreen = Color(0xFF4CAF50);
const _kAmber = Color(0xFFFFB300);

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});
  @override
  State<AdminNotificationsPage> createState() =>
      _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  bool _loading = true;
  List<CampaignModel> _list = [];
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _list = await CampaignService.list();
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل تحميل الحملات: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openComposer() async {
    final created = await Navigator.push<CampaignModel?>(
      context,
      MaterialPageRoute(builder: (_) => const _ComposerPage()),
    );
    if (created != null && mounted) {
      setState(() => _list.insert(0, created));
    }
  }

  Future<void> _sendCampaign(CampaignModel c) async {
    final count = await _previewAudience(c);
    if (count == null) return;
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد الإرسال',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          'سيتم إرسال هذا الإشعار إلى $count مستخدم. هل تريد المتابعة؟',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
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
              backgroundColor: _kGreen,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('إرسال الآن',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;

    HapticFeedback.lightImpact();
    setState(() => _busyIds.add(c.id));
    try {
      final updated = await CampaignService.send(c.id);
      if (!mounted) return;
      setState(() {
        final idx = _list.indexWhere((x) => x.id == c.id);
        if (idx != -1) _list[idx] = updated;
      });
      _snack('تم إرسال الحملة بنجاح ✅', _kGreen);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل الإرسال: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busyIds.remove(c.id));
    }
  }

  Future<int?> _previewAudience(CampaignModel c) async {
    try {
      return await CampaignService.previewAudience(c.id);
    } catch (e) {
      _snack('فشل حساب الجمهور: $e', _kRed);
      return null;
    }
  }

  Future<void> _deleteCampaign(CampaignModel c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف الحملة',
            style: TextStyle(fontWeight: FontWeight.w900, color: _kRed)),
        content: const Text(
          'لا يمكن حذف حملة تم إرسالها بالفعل. هل تريد حذف هذه المسودة؟',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
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
              backgroundColor: _kRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('حذف',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busyIds.add(c.id));
    try {
      await CampaignService.delete(c.id);
      if (!mounted) return;
      setState(() => _list.removeWhere((x) => x.id == c.id));
      _snack('تم حذف الحملة', _kGreen);
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل الحذف: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busyIds.remove(c.id));
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
        title: const Text('الإشعارات الجماعية',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        backgroundColor: _kOcean,
        icon: const Icon(Icons.send_rounded, color: Colors.white),
        label: const Text('بث جديد',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOcean))
          : RefreshIndicator(
              color: _kOcean,
              onRefresh: _load,
              child: _list.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 100),
                        Icon(Icons.campaign_rounded,
                            size: 64,
                            color: context.kSub.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Center(
                          child: Text('لا توجد حملات إشعارات بعد',
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
                      itemCount: _list.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) => _CampaignCard(
                        campaign: _list[i],
                        busy: _busyIds.contains(_list[i].id),
                        onSend: _list[i].status == CampaignStatus.draft
                            ? () => _sendCampaign(_list[i])
                            : null,
                        onDelete:
                            _list[i].status == CampaignStatus.draft ||
                                    _list[i].status ==
                                        CampaignStatus.cancelled
                                ? () => _deleteCampaign(_list[i])
                                : null,
                      ),
                    ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Single campaign card
// ═══════════════════════════════════════════════════════════════
class _CampaignCard extends StatelessWidget {
  final CampaignModel campaign;
  final bool busy;
  final VoidCallback? onSend;
  final VoidCallback? onDelete;

  const _CampaignCard({
    required this.campaign,
    required this.busy,
    this.onSend,
    this.onDelete,
  });

  Color get _statusColor => switch (campaign.status) {
        CampaignStatus.sent => _kGreen,
        CampaignStatus.sending => _kAmber,
        CampaignStatus.failed => _kRed,
        CampaignStatus.cancelled => _kRed,
        CampaignStatus.scheduled => _kOcean,
        _ => _kAmber,
      };

  @override
  Widget build(BuildContext context) {
    final created = intl.DateFormat('y/MM/dd – HH:mm')
        .format(campaign.createdAt.toLocal());
    return Container(
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.kBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.campaign_rounded,
                  color: _statusColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                campaign.titleAr,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: context.kText),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(campaign.status.arabic,
                  style: TextStyle(
                      color: _statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            campaign.bodyAr,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: context.kSub),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _meta(context, Icons.group_rounded, campaign.audience.arabic),
            if (campaign.filterArea != null &&
                campaign.filterArea!.isNotEmpty)
              _meta(context, Icons.location_on_rounded,
                  campaign.filterArea!),
            if (campaign.filterRecentDays != null)
              _meta(context, Icons.calendar_today_rounded,
                  '${campaign.filterRecentDays} يوم'),
            _meta(context, Icons.event_rounded, created),
            if (campaign.status == CampaignStatus.sent)
              _meta(
                context,
                Icons.send_and_archive_rounded,
                'وصل إلى ${campaign.successCount} / ${campaign.targetCount}',
                color: _kGreen,
              ),
          ]),
          if (onSend != null || onDelete != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              if (onSend != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : onSend,
                    icon: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 16),
                    label: const Text('إرسال',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGreen,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11)),
                    ),
                  ),
                ),
              if (onSend != null && onDelete != null)
                const SizedBox(width: 8),
              if (onDelete != null)
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
                      side:
                          BorderSide(color: _kRed.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11)),
                    ),
                  ),
                ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text,
      {Color? color}) {
    final c = color ?? context.kSub;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.kSand.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: c, size: 12),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                color: c, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Composer page — create a new draft campaign
// ═══════════════════════════════════════════════════════════════
class _ComposerPage extends StatefulWidget {
  const _ComposerPage();
  @override
  State<_ComposerPage> createState() => _ComposerPageState();
}

class _ComposerPageState extends State<_ComposerPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleAr = TextEditingController();
  final _bodyAr = TextEditingController();
  final _titleEn = TextEditingController();
  final _bodyEn = TextEditingController();
  final _filterArea = TextEditingController();
  final _filterRecentDays = TextEditingController();
  final _deeplink = TextEditingController();

  CampaignAudience _audience = CampaignAudience.allUsers;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _titleAr,
      _bodyAr,
      _titleEn,
      _bodyEn,
      _filterArea,
      _filterRecentDays,
      _deeplink,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_audience == CampaignAudience.byArea) &&
        _filterArea.text.trim().isEmpty) {
      _snack('اكتب اسم المنطقة المستهدفة', _kRed);
      return;
    }
    if (_audience == CampaignAudience.recentBookers &&
        _filterRecentDays.text.trim().isEmpty) {
      _snack('حدد عدد الأيام (مثلاً 30)', _kRed);
      return;
    }
    setState(() => _busy = true);
    try {
      final created = await CampaignService.create(
        titleAr: _titleAr.text.trim(),
        bodyAr: _bodyAr.text.trim(),
        titleEn: _titleEn.text.trim().isEmpty ? null : _titleEn.text.trim(),
        bodyEn: _bodyEn.text.trim().isEmpty ? null : _bodyEn.text.trim(),
        audience: _audience,
        filterArea: _audience == CampaignAudience.byArea
            ? _filterArea.text.trim()
            : null,
        filterRecentDays: _audience == CampaignAudience.recentBookers
            ? int.tryParse(_filterRecentDays.text.trim())
            : null,
        deeplink:
            _deeplink.text.trim().isEmpty ? null : _deeplink.text.trim(),
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
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('بث جديد',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('المحتوى (إجباري)'),
            _field(_titleAr, 'العنوان بالعربية', maxLength: 200),
            const SizedBox(height: 10),
            _field(_bodyAr, 'النص بالعربية', maxLines: 4),
            const SizedBox(height: 16),
            _section('المحتوى بالإنجليزية (اختياري)'),
            _field(_titleEn, 'Title (EN)',
                maxLength: 200, required: false),
            const SizedBox(height: 10),
            _field(_bodyEn, 'Body (EN)', maxLines: 4, required: false),
            const SizedBox(height: 16),
            _section('الجمهور المستهدف'),
            DropdownButtonFormField<CampaignAudience>(
              initialValue: _audience,
              decoration: _decoration('الفئة'),
              items: CampaignAudience.values
                  .map((a) => DropdownMenuItem(
                      value: a, child: Text(a.arabic)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _audience = v);
              },
            ),
            if (_audience == CampaignAudience.byArea) ...[
              const SizedBox(height: 10),
              _field(_filterArea, 'اسم المنطقة (مثلاً: الساحل الشمالي)',
                  required: false),
            ],
            if (_audience == CampaignAudience.recentBookers) ...[
              const SizedBox(height: 10),
              _field(_filterRecentDays, 'الحاجزون خلال آخر (أيام)',
                  keyboardType: TextInputType.number, required: false),
            ],
            const SizedBox(height: 16),
            _section('Deep link (اختياري)'),
            _field(_deeplink, 'مثال: talaa://property/123', required: false),
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
              label: const Text('حفظ كمسودة',
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
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 13, color: _kOcean)),
      );

  Widget _field(
    TextEditingController c,
    String label, {
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool required = true,
  }) {
    return TextFormField(
      controller: c,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _decoration(label),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null
          : null,
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kOcean, width: 2),
        ),
      );
}
