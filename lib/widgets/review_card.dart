// ═══════════════════════════════════════════════════════════════
//  TALAA — Review Card
//  Displays a single review + optional host reply.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../models/review_model.dart';
import '../services/review_service.dart';
import '../utils/api_client.dart';
import '../utils/error_handler.dart';
import 'constants.dart';
import 'star_rating.dart';

class ReviewCard extends StatefulWidget {
  final ReviewModel review;

  /// If ``true`` the current user is the property owner → show the
  /// "reply to review" CTA when no response exists yet.
  final bool isOwnerView;

  /// Called after a successful reply so the parent can refresh its
  /// local list.
  final ValueChanged<ReviewModel>? onResponded;

  const ReviewCard({
    super.key,
    required this.review,
    this.isOwnerView = false,
    this.onResponded,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  bool _reporting = false;

  ReviewModel get r => widget.review;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()} سنة';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} شهر';
    if (diff.inDays > 0) return '${diff.inDays} يوم';
    if (diff.inHours > 0) return '${diff.inHours} ساعة';
    if (diff.inMinutes > 0) return '${diff.inMinutes} دقيقة';
    return 'الآن';
  }

  Future<void> _report() async {
    setState(() => _reporting = true);
    try {
      await ReviewService.report(r.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم الإبلاغ عن التقييم'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.getMessage(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  Future<void> _openReply() async {
    final controller = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('الرد على التقييم'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText: 'اكتب ردك للضيف…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    if (res == null || res.isEmpty) return;

    try {
      final updated =
          await ReviewService.respond(reviewId: r.id, response: res);
      widget.onResponded?.call(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال ردك'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.getMessage(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = r.reviewer?.avatarUrl;
    final initial =
        (r.reviewer?.name.isNotEmpty ?? false) ? r.reviewer!.name[0] : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage:
                    avatar != null ? NetworkImage(avatar) : null,
                backgroundColor: context.kBorder,
                child: avatar == null
                    ? Text(initial,
                        style: const TextStyle(fontWeight: FontWeight.w900))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.reviewer?.name ?? 'مستخدم',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: context.kText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeAgo(r.createdAt),
                      style: TextStyle(fontSize: 11, color: context.kSub),
                    ),
                  ],
                ),
              ),
              StarRating(value: r.rating, size: 16),
              if (!widget.isOwnerView)
                IconButton(
                  tooltip: 'إبلاغ',
                  icon: Icon(
                    Icons.flag_outlined,
                    size: 18,
                    color: context.kSub,
                  ),
                  onPressed: _reporting ? null : _report,
                ),
            ],
          ),
          if (r.comment != null && r.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              r.comment!,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: context.kText,
              ),
            ),
          ],
          if (r.hasOwnerResponse) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.kSand,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.reply_rounded,
                          size: 14, color: context.kSub),
                      const SizedBox(width: 6),
                      Text(
                        'رد مالك العقار',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: context.kSub,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r.ownerResponse!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: context.kText,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (widget.isOwnerView) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.reply_rounded, size: 16),
                label: const Text('الرد على التقييم'),
                onPressed: _openReply,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
