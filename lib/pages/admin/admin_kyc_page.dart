// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin KYC Page  (Wave 30)
//
//  Drain the queue of pending guest KYC submissions.  Each row shows
//  the ID doc + back + selfie thumbnails (tap to enlarge), plus
//  Approve / Reject / Needs-edit actions.  Approving flips the
//  user's ``is_verified`` flag so hosts who require verified guests
//  start seeing the booking come through.
// ═══════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

import '../../services/user_verification_admin_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';
import '../photo_viewer_page.dart';

const _kOcean = Color(0xFFFF6B35);
const _kRed = Color(0xFFEF5350);
const _kGreen = Color(0xFF4CAF50);
const _kAmber = Color(0xFFFFB300);

class AdminKycPage extends StatefulWidget {
  const AdminKycPage({super.key});
  @override
  State<AdminKycPage> createState() => _AdminKycPageState();
}

class _AdminKycPageState extends State<AdminKycPage> {
  bool _loading = true;
  List<UserVerificationItem> _items = [];
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await UserVerificationAdminService.listPending();
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التحميل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(UserVerificationItem v, String decision) async {
    final isApprove = decision == 'approve';
    final note = await _askNote(
      title: isApprove
          ? 'الموافقة على التوثيق'
          : decision == 'reject'
              ? 'رفض التوثيق'
              : 'طلب تعديل',
      hint: isApprove ? 'ملاحظة (اختياري)' : 'سبب القرار (إجباري)',
      cta: isApprove
          ? 'موافقة'
          : decision == 'reject'
              ? 'رفض'
              : 'طلب تعديل',
      ctaColor: isApprove
          ? _kGreen
          : decision == 'reject'
              ? _kRed
              : _kAmber,
      requireText: !isApprove,
    );
    if (note == null) return;
    if (!isApprove && note.trim().isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() => _busy.add(v.id));
    try {
      final updated = decision == 'approve'
          ? await UserVerificationAdminService.approve(v.id,
              note: note.isEmpty ? null : note)
          : decision == 'reject'
              ? await UserVerificationAdminService.reject(v.id, note: note)
              : await UserVerificationAdminService.needsEdit(v.id,
                  note: note);
      if (!mounted) return;
      setState(() => _items.removeWhere((x) => x.id == updated.id));
      _snack(
        decision == 'approve'
            ? 'تم اعتماد الهوية ✅'
            : decision == 'reject'
                ? 'تم رفض الهوية'
                : 'تم طلب التعديل',
        _kGreen,
      );
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل القرار: $e', _kRed);
    } finally {
      if (mounted) setState(() => _busy.remove(v.id));
    }
  }

  Future<String?> _askNote({
    required String title,
    required String hint,
    required String cta,
    required Color ctaColor,
    required bool requireText,
  }) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: ctaColor)),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            maxLength: 2000,
            onChanged: (_) => setSt(() {}),
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء',
                  style: TextStyle(
                      color: context.kSub,
                      fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              onPressed: requireText && ctrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, ctrl.text.trim()),
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
        );
      }),
    );
  }

  void _openPhotos(UserVerificationItem v) {
    final imgs = <String>[
      v.idFrontUrl,
      if (v.idBackUrl != null) v.idBackUrl!,
      v.selfieUrl,
    ].where((s) => s.isNotEmpty).toList();
    if (imgs.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewerPage(
          images: imgs,
          title: 'وثائق المستخدم #${v.userId}',
        ),
      ),
    );
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

  String _arabicDocType(String t) => switch (t) {
        'national_id' => 'بطاقة شخصية',
        'passport' => 'جواز سفر',
        'driver_license' => 'رخصة قيادة',
        _ => t,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('توثيق هوية المستخدمين (KYC)',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 17)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
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
                        Icon(Icons.badge_rounded,
                            size: 64,
                            color: context.kSub.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                              'لا توجد طلبات توثيق هوية منتظرة 🎉',
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
                        final v = _items[i];
                        return Container(
                          decoration: BoxDecoration(
                            color: context.kCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: _kAmber.withValues(alpha: 0.4)),
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
                                        _kAmber.withValues(alpha: 0.12),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.badge_rounded,
                                      color: _kAmber, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('مستخدم #${v.userId}',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: context.kText)),
                                      Text(
                                          '${_arabicDocType(v.idDocType)} • ${intl.DateFormat('y/MM/dd HH:mm').format(v.submittedAt.toLocal())}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: context.kSub,
                                              fontWeight:
                                                  FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => _openPhotos(v),
                                child: Row(children: [
                                  Expanded(
                                      child: _docThumb(
                                          context, v.idFrontUrl,
                                          'وجه البطاقة')),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: _docThumb(
                                          context,
                                          v.idBackUrl ?? '',
                                          'ظهر البطاقة')),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: _docThumb(
                                          context, v.selfieUrl, 'سيلفي')),
                                ]),
                              ),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _busy.contains(v.id)
                                        ? null
                                        : () => _decide(v, 'approve'),
                                    icon: _busy.contains(v.id)
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child:
                                                CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white))
                                        : const Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 16),
                                    label: const Text('موافقة',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                                FontWeight.w800)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _kGreen,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 11),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(11)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _busy.contains(v.id)
                                        ? null
                                        : () =>
                                            _decide(v, 'needs_edit'),
                                    icon: const Icon(
                                        Icons.edit_note_rounded,
                                        color: _kAmber,
                                        size: 16),
                                    label: const Text('تعديل',
                                        style: TextStyle(
                                            color: _kAmber,
                                            fontWeight:
                                                FontWeight.w800)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: _kAmber.withValues(
                                              alpha: 0.5)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 11),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(11)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _busy.contains(v.id)
                                        ? null
                                        : () => _decide(v, 'reject'),
                                    icon: const Icon(Icons.close_rounded,
                                        color: _kRed, size: 16),
                                    label: const Text('رفض',
                                        style: TextStyle(
                                            color: _kRed,
                                            fontWeight:
                                                FontWeight.w800)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: _kRed.withValues(
                                              alpha: 0.5)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 11),
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

  Widget _docThumb(BuildContext context, String url, String label) {
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 80,
          width: double.infinity,
          child: url.isEmpty
              ? Container(
                  color: context.kBorder,
                  child: const Center(
                      child: Icon(Icons.image_not_supported_rounded,
                          color: Colors.grey, size: 24)),
                )
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: context.kBorder),
                  errorWidget: (_, __, ___) => Container(
                    color: _kRed.withValues(alpha: 0.1),
                    child: const Icon(Icons.broken_image_rounded,
                        color: _kRed),
                  ),
                ),
        ),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(
              color: context.kSub,
              fontSize: 10,
              fontWeight: FontWeight.w700)),
    ]);
  }
}
