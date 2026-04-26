// ═══════════════════════════════════════════════════════════════
//  TALAA — Write Review Page
//  Submit a rating + optional comment for a completed booking.
// ═══════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/review_model.dart';
import '../services/review_service.dart';
import '../utils/api_client.dart';
import '../utils/error_handler.dart';
import '../widgets/constants.dart';
import '../widgets/star_rating.dart';

const _kOcean = Color(0xFFB54414);

class WriteReviewPage extends StatefulWidget {
  final PendingReview pending;

  const WriteReviewPage({super.key, required this.pending});

  @override
  State<WriteReviewPage> createState() => _WriteReviewPageState();
}

class _WriteReviewPageState extends State<WriteReviewPage> {
  double _rating = 0;
  final _comment = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار تقييم أولاً'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ReviewService.create(
        bookingId: widget.pending.bookingId,
        rating: _rating,
        comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
      );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pop(true); // signal success
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.getMessage(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _ratingLabel(double r) {
    if (r >= 5) return 'ممتاز 🤩';
    if (r >= 4) return 'جيد جداً 😊';
    if (r >= 3) return 'جيد 🙂';
    if (r >= 2) return 'مقبول 😐';
    if (r >= 1) return 'سيء 😕';
    return 'اختر تقييمك';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pending;
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'اكتب تقييمك',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Property preview card ──────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.kBorder),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: p.propertyImage != null
                        ? CachedNetworkImage(
                            imageUrl: p.propertyImage!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _fallback(),
                          )
                        : _fallback(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.propertyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: context.kText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${p.nights} ليلة · كود ${p.bookingCode}',
                          style:
                              TextStyle(fontSize: 12, color: context.kSub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            Center(
              child: Text(
                'كيف كانت إقامتك؟',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: context.kText,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: StarRating(
                value: _rating,
                size: 40,
                onChanged: (v) => setState(() => _rating = v),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _ratingLabel(_rating),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.kSub,
                ),
              ),
            ),

            const SizedBox(height: 28),
            Text(
              'شارك تجربتك (اختياري)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: context.kText,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.kBorder),
              ),
              child: TextField(
                controller: _comment,
                minLines: 4,
                maxLines: 8,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: 'احكي تفاصيل إقامتك، النظافة، الموقع…',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOcean,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'إرسال التقييم',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        width: 64,
        height: 64,
        color: _kOcean.withValues(alpha: 0.08),
        child: const Icon(Icons.villa_rounded, color: _kOcean),
      );
}
