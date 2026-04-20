// ═══════════════════════════════════════════════════════════════
//  TALAA — Pending Reviews Page
//  Lists completed bookings the user still has to rate.
// ═══════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/review_model.dart';
import '../services/review_service.dart';
import '../utils/api_client.dart';
import '../utils/error_handler.dart';
import '../widgets/constants.dart';
import 'write_review_page.dart';

const _kOcean = Color(0xFF1B4D5C);
const _kAmber = Color(0xFFF59E0B);

class PendingReviewsPage extends StatefulWidget {
  const PendingReviewsPage({super.key});

  @override
  State<PendingReviewsPage> createState() => _PendingReviewsPageState();
}

class _PendingReviewsPageState extends State<PendingReviewsPage> {
  bool _loading = true;
  String? _error;
  List<PendingReview> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ReviewService.myPending();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.getMessage(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر التحميل';
        _loading = false;
      });
    }
  }

  Future<void> _writeReview(PendingReview p) async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WriteReviewPage(pending: p)),
    );
    if (submitted == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kSand,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'قيّم إقاماتك',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kOcean));
    }
    if (_error != null) {
      return _centered(
        icon: Icons.wifi_off_rounded,
        title: 'تعذر التحميل',
        body: _error!,
        action: _load,
        actionLabel: 'إعادة المحاولة',
      );
    }
    if (_items.isEmpty) {
      return _centered(
        icon: Icons.check_circle_outline_rounded,
        title: 'لا توجد تقييمات في الانتظار',
        body: 'هتلاقي هنا إقاماتك اللي خلصت ومفيش ليها تقييم.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (_, i) => _tile(_items[i]),
    );
  }

  Widget _tile(PendingReview p) {
    return GestureDetector(
      onTap: () => _writeReview(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.kCard,
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
                    style: TextStyle(fontSize: 12, color: context.kSub),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: _kAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 14, color: _kAmber),
                  SizedBox(width: 4),
                  Text(
                    'قيّم',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: _kAmber,
                    ),
                  ),
                ],
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

  Widget _centered({
    required IconData icon,
    required String title,
    required String body,
    VoidCallback? action,
    String? actionLabel,
  }) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 72, color: context.kSub),
        const SizedBox(height: 20),
        Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: context.kText,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.kSub),
            ),
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: action,
              child: Text(actionLabel ?? 'إعادة المحاولة'),
            ),
          ),
        ],
      ],
    );
  }
}
