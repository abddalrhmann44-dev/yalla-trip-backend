// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Host Verification Page  (Wave 30)
//
//  Hosts upload proof-of-ownership documents through the property
//  flow (``PropertyVerification`` model).  This page lets the admin
//  drain the pending queue: tap a row → review docs → Approve /
//  Request edit / Reject.  Approving flips the linked Property's
//  ``is_verified`` flag so the public app shows the "موثق" badge.
// ═══════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

import '../../services/verification_admin_service.dart';
import '../../utils/api_client.dart';
import '../../utils/error_handler.dart';
import '../../widgets/constants.dart';
import '../photo_viewer_page.dart';

const _kOcean = Color(0xFFFF6B35);
const _kRed = Color(0xFFEF5350);
const _kGreen = Color(0xFF4CAF50);
const _kAmber = Color(0xFFFFB300);

class AdminHostVerificationPage extends StatefulWidget {
  const AdminHostVerificationPage({super.key});
  @override
  State<AdminHostVerificationPage> createState() =>
      _AdminHostVerificationPageState();
}

class _AdminHostVerificationPageState
    extends State<AdminHostVerificationPage> {
  bool _loading = true;
  List<VerificationItem> _items = [];
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await VerificationAdminService.listPending();
    } on ApiException catch (e) {
      if (mounted) _snack(ErrorHandler.getMessage(e), _kRed);
    } catch (e) {
      if (mounted) _snack('فشل التحميل: $e', _kRed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(VerificationItem v, String decision) async {
    final isApprove = decision == 'approve';
    final note = await _askNote(
      title: isApprove
          ? 'الموافقة على التوثيق'
          : decision == 'reject'
              ? 'رفض التوثيق'
              : 'طلب تعديل',
      hint: isApprove ? 'ملاحظة (اختياري)' : 'سبب القرار (إجباري)',
      cta: isApprove ? 'موافقة' : decision == 'reject' ? 'رفض' : 'طلب تعديل',
      ctaColor: isApprove ? _kGreen : decision == 'reject' ? _kRed : _kAmber,
      requireText: !isApprove,
    );
    if (note == null) return;
    if (!isApprove && note.trim().isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() => _busy.add(v.id));
    try {
      final updated = decision == 'approve'
          ? await VerificationAdminService.approve(v.id,
              note: note.isEmpty ? null : note)
          : decision == 'reject'
              ? await VerificationAdminService.reject(v.id, note: note)
              : await VerificationAdminService.needsEdit(v.id, note: note);
      if (!mounted) return;
      // Pending queue drops the row no matter the decision (it leaves
      // the pending bucket).
      setState(() => _items.removeWhere((x) => x.id == updated.id));
      _snack(
        decision == 'approve'
            ? 'تم اعتماد التوثيق ✅'
            : decision == 'reject'
                ? 'تم رفض التوثيق'
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

  void _openDocs(VerificationItem v) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewerPage(
          images: v.documentUrls,
          title: 'وثائق العقار #${v.propertyId}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: _kOcean,
        elevation: 0,
        title: const Text('توثيق المضيفين',
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
                        Icon(Icons.verified_user_rounded,
                            size: 64,
                            color: context.kSub.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                              'لا توجد طلبات توثيق منتظرة 🎉',
                              style: TextStyle(
                                  color: context.kSub,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) => _VerificationCard(
                        item: _items[i],
                        busy: _busy.contains(_items[i].id),
                        onApprove: () => _decide(_items[i], 'approve'),
                        onReject: () => _decide(_items[i], 'reject'),
                        onNeedsEdit: () =>
                            _decide(_items[i], 'needs_edit'),
                        onOpenDocs: () => _openDocs(_items[i]),
                      ),
                    ),
            ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  final VerificationItem item;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onNeedsEdit;
  final VoidCallback onOpenDocs;

  const _VerificationCard({
    required this.item,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onNeedsEdit,
    required this.onOpenDocs,
  });

  String _arabicDocType(String t) {
    switch (t) {
      case 'ownership_contract':
        return 'عقد ملكية';
      case 'utility_bill':
        return 'فاتورة مرافق';
      case 'id_card':
        return 'بطاقة شخصية';
      case 'commercial_register':
        return 'سجل تجاري';
      default:
        return 'مستند آخر';
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitted = intl.DateFormat('y/MM/dd – HH:mm')
        .format(item.submittedAt.toLocal());
    return Container(
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kAmber.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_user_rounded,
                  color: _kAmber, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('عقار #${item.propertyId}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: context.kText)),
                  const SizedBox(height: 2),
                  Text(
                      '${_arabicDocType(item.primaryDocumentType)} • $submitted',
                      style: TextStyle(
                          fontSize: 10,
                          color: context.kSub,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('قيد المراجعة',
                  style: TextStyle(
                      color: _kAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
          if ((item.hostNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.kSand.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ملاحظة المضيف',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.kSub)),
                  const SizedBox(height: 4),
                  Text(item.hostNote!.trim(),
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: context.kText)),
                ],
              ),
            ),
          ],
          if (item.documentUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: item.documentUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: onOpenDocs,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 92,
                      height: 92,
                      child: CachedNetworkImage(
                        imageUrl: item.documentUrls[i],
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            color: context.kBorder,
                            child: const Center(
                                child: CircularProgressIndicator(
                                    color: _kOcean, strokeWidth: 2))),
                        errorWidget: (_, __, ___) => Container(
                            color: _kRed.withValues(alpha: 0.1),
                            child: const Icon(Icons.broken_image_rounded,
                                color: _kRed)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: busy ? null : onApprove,
                icon: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16),
                label: const Text('موافقة',
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
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onNeedsEdit,
                icon: const Icon(Icons.edit_note_rounded,
                    color: _kAmber, size: 16),
                label: const Text('تعديل',
                    style: TextStyle(
                        color: _kAmber, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _kAmber.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onReject,
                icon: const Icon(Icons.close_rounded,
                    color: _kRed, size: 16),
                label: const Text('رفض',
                    style: TextStyle(
                        color: _kRed, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _kRed.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
