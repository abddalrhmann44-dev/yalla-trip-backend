// ═══════════════════════════════════════════════════════════════
//  TALAA — Write Review Page  (احترافي)
//  • اختيار النجوم مع تأثيرات بصرية
//  • بانر ذهبي عند 5 نجوم "هتكسب 100 ج.م"
//  • شاشة احتفالية بعد الإرسال مع رصيد المحفظة
// ═══════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/review_model.dart';
import '../services/review_service.dart';
import '../services/wallet_service.dart';
import '../utils/api_client.dart';
import '../utils/error_handler.dart';
import '../widgets/constants.dart';

const _kAmber   = Color(0xFFF59E0B);
const _kGold    = Color(0xFFFF8F00);
const _kGreen   = Color(0xFF43A047);
const _kPrimary = Color(0xFFFF6B35);
const _kRed     = Color(0xFFEF5350);

const _kBonus = 100.0; // جنيه مكافأة 5 نجوم

// ── تاجات سريعة ──────────────────────────────────────────────
const _kTags = [
  '✨ نظيف جداً',
  '📍 موقع ممتاز',
  '📸 مطابق للصور',
  '😊 تعامل ممتاز',
  '💰 يستاهل سعره',
  '🔁 هأرجعله تاني',
];

// ══════════════════════════════════════════════════════════════
class WriteReviewPage extends StatefulWidget {
  final PendingReview pending;
  const WriteReviewPage({super.key, required this.pending});

  @override
  State<WriteReviewPage> createState() => _WriteReviewPageState();
}

class _WriteReviewPageState extends State<WriteReviewPage>
    with SingleTickerProviderStateMixin {
  double _rating = 0;
  final _comment = TextEditingController();
  final Set<String> _selectedTags = {};
  bool _submitting = false;

  late final AnimationController _bonusCtrl;
  late final Animation<double> _bonusFade;
  late final Animation<Offset> _bonusSlide;

  @override
  void initState() {
    super.initState();
    _bonusCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bonusFade  = CurvedAnimation(parent: _bonusCtrl, curve: Curves.easeOut);
    _bonusSlide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _bonusCtrl, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _bonusCtrl.dispose();
    _comment.dispose();
    super.dispose();
  }

  void _onStarTap(double v) {
    HapticFeedback.selectionClick();
    setState(() => _rating = v);
    if (v >= 5) {
      _bonusCtrl.forward();
    } else {
      _bonusCtrl.reverse();
    }
  }

  // ── إرسال التقييم ─────────────────────────────────────────
  Future<void> _submit() async {
    if (_rating < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('اختار عدد النجوم أولاً'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _submitting = true);
    try {
      final fullComment = [
        if (_selectedTags.isNotEmpty) _selectedTags.join('  '),
        if (_comment.text.trim().isNotEmpty) _comment.text.trim(),
      ].join('\n').trim();

      await ReviewService.create(
        bookingId: widget.pending.bookingId,
        rating: _rating,
        comment: fullComment.isEmpty ? null : fullComment,
      );
      HapticFeedback.mediumImpact();

      // ── مكافأة 5 نجوم ────────────────────────────────────
      double? newBalance;
      if (_rating >= 5) {
        try {
          final wallet = await WalletService.topup(
            amount: _kBonus,
            gatewayReference:
                'review_5star_${widget.pending.bookingId}',
          );
          newBalance = wallet.balance;
        } catch (_) {
          // إذا فشل الـ topup عرض النجاح عادي
        }
      }

      if (!mounted) return;
      setState(() => _submitting = false);

      if (newBalance != null) {
        _showCelebration(newBalance);
      } else {
        _showSimpleSuccess();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ErrorHandler.getMessage(e)),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSimpleSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('تم إرسال تقييمك، شكراً! ✅'),
      behavior: SnackBarBehavior.floating,
    ));
    Navigator.of(context).pop(true);
  }

  void _showCelebration(double balance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CelebrationSheet(
        bonus: _kBonus,
        newBalance: balance,
        onClose: () {
          Navigator.of(context).pop(); // close sheet
          Navigator.of(context).pop(true); // close review page
        },
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────
  String _ratingLabel(double r) {
    if (r >= 5) return 'ممتاز 🤩';
    if (r >= 4) return 'جيد جداً 😊';
    if (r >= 3) return 'جيد 🙂';
    if (r >= 2) return 'مقبول 😐';
    if (r >= 1) return 'سيء 😕';
    return 'اختر تقييمك';
  }

  Color _ratingColor(double r) {
    if (r >= 5) return _kGold;
    if (r >= 4) return _kGreen;
    if (r >= 3) return _kAmber;
    if (r >= 2) return Colors.orange;
    if (r >= 1) return _kRed;
    return Colors.grey;
  }

  // ═══════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final p = widget.pending;
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: context.kCard,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'قيّم إقامتك',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.kBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── بطاقة العقار ──────────────────────────────
            _PropertyCard(p: p),
            const SizedBox(height: 28),

            // ── اختيار النجوم ─────────────────────────────
            _StarSection(
              rating: _rating,
              onChanged: _onStarTap,
              label: _ratingLabel(_rating),
              labelColor: _ratingColor(_rating),
            ),
            const SizedBox(height: 14),

            // ── بانر 5 نجوم ───────────────────────────────
            SlideTransition(
              position: _bonusSlide,
              child: FadeTransition(
                opacity: _bonusFade,
                child: const _BonusBanner(),
              ),
            ),
            if (_rating >= 5) const SizedBox(height: 14),

            // ── تاجات سريعة ──────────────────────────────
            _TagsSection(
              selected: _selectedTags,
              onToggle: (t) => setState(
                  () => _selectedTags.contains(t)
                      ? _selectedTags.remove(t)
                      : _selectedTags.add(t)),
            ),
            const SizedBox(height: 20),

            // ── تعليق ─────────────────────────────────────
            Text('شارك تفاصيل إقامتك (اختياري)',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.kText)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: context.kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.kBorder),
              ),
              child: TextField(
                controller: _comment,
                minLines: 4,
                maxLines: 8,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText:
                      'احكي تجربتك، النظافة، الموقع، الخدمة…',
                  hintStyle: TextStyle(
                      color: context.kSub, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── زرار الإرسال ──────────────────────────────
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _rating >= 5 ? _kGold : _kPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _rating >= 5
                                ? Icons.workspace_premium_rounded
                                : Icons.send_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _rating >= 5
                                ? 'إرسال وكسب 100 ج.م 🎉'
                                : 'إرسال التقييم',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  بطاقة العقار
// ══════════════════════════════════════════════════════════════
class _PropertyCard extends StatelessWidget {
  final PendingReview p;
  const _PropertyCard({required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: p.propertyImage != null
              ? CachedNetworkImage(
                  imageUrl: p.propertyImage!,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _fallback(),
                )
              : _fallback(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              p.propertyName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: context.kText),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.nights_stay_rounded,
                  size: 14, color: context.kSub),
              const SizedBox(width: 4),
              Text('${p.nights} ليلة',
                  style:
                      TextStyle(fontSize: 12, color: context.kSub)),
              const SizedBox(width: 12),
              Icon(Icons.confirmation_number_rounded,
                  size: 14, color: context.kSub),
              const SizedBox(width: 4),
              Text(p.bookingCode,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.kSub)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _fallback() => Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
            color: _kPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.villa_rounded, color: _kPrimary, size: 30),
      );
}

// ══════════════════════════════════════════════════════════════
//  قسم النجوم
// ══════════════════════════════════════════════════════════════
class _StarSection extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onChanged;
  final String label;
  final Color labelColor;

  const _StarSection({
    required this.rating,
    required this.onChanged,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: rating >= 5
              ? _kGold.withValues(alpha: 0.4)
              : context.kBorder,
          width: rating >= 5 ? 2 : 1,
        ),
        boxShadow: [
          if (rating >= 5)
            BoxShadow(
              color: _kGold.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(children: [
        Text('كيف كانت إقامتك؟',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: context.kText)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final filled = rating - i;
            final isFull = filled >= 1;
            return GestureDetector(
              onTap: () => onChanged((i + 1).toDouble()),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  isFull
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: isFull ? 48 : 44,
                  color: isFull ? _kAmber : context.kBorder,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: rating == 0 ? context.kSub : labelColor,
          ),
          child: Text(label),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  بانر المكافأة الذهبي (5 نجوم)
// ══════════════════════════════════════════════════════════════
class _BonusBanner extends StatelessWidget {
  const _BonusBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8F00), Color(0xFFFFC107)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _kGold.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('🎉', style: TextStyle(fontSize: 22)),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مبروك! بكسب 100 ج.م في محفظتك 🎊',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'المبلغ بيتحط تلقائياً وتقدر تستخدمه في أي حجز جاي',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const Text('💰', style: TextStyle(fontSize: 28)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  تاجات سريعة
// ══════════════════════════════════════════════════════════════
class _TagsSection extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _TagsSection({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('ما الأكثر مميزاً؟ (اختياري)',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: context.kText)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _kTags.map((tag) {
          final sel = selected.contains(tag);
          return GestureDetector(
            onTap: () => onToggle(tag),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: sel
                    ? _kAmber.withValues(alpha: 0.12)
                    : context.kCard,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color:
                      sel ? _kAmber : context.kBorder,
                  width: sel ? 2 : 1.5,
                ),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      sel ? FontWeight.w800 : FontWeight.w600,
                  color: sel ? _kGold : context.kText,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
//  شاشة احتفالية بعد 5 نجوم
// ══════════════════════════════════════════════════════════════
class _CelebrationSheet extends StatelessWidget {
  final double bonus;
  final double newBalance;
  final VoidCallback onClose;

  const _CelebrationSheet({
    required this.bonus,
    required this.newBalance,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      decoration: BoxDecoration(
        color: context.kCard,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── مقبض ──
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: context.kBorder,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 24),

        // ── أيقونة ──
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8F00), Color(0xFFFFC107)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _kGold.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text('🎉', style: TextStyle(fontSize: 42)),
          ),
        ),
        const SizedBox(height: 20),

        // ── العنوان ──
        const Text(
          'مبروك عليك! 🌟',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Text(
          'شكراً على تقييمك الممتاز\nاتحط ${bonus.toStringAsFixed(0)} ج.م في محفظتك!',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15, color: context.kSub, height: 1.5),
        ),
        const SizedBox(height: 24),

        // ── بطاقة الرصيد ──
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8F00), Color(0xFFFFC107)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            const Text('💰', style: TextStyle(fontSize: 36)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'رصيد محفظتك الآن',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${newBalance.toStringAsFixed(0)} ج.م',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '+${bonus.toStringAsFixed(0)} ج.م',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kGreen.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Icon(Icons.check_circle_rounded,
                color: _kGreen, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تقدر تستخدم الرصيد ده في أي حجز جاي لأي شاليه',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _kGreen),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        // ── زرار ──
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGold,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            child: const Text(
              'رائع! جزيل الشكر 🙌',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ]),
    );
  }
}
