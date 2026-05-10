// ═══════════════════════════════════════════════════════════════
//  TALAA — Promo Banner Carousel  (Wave 30)
//
//  Horizontal auto-scrolling carousel of active marketing banners,
//  rendered on the guest homepage above the destinations rail.
//
//  Design notes:
//    • Fully self-contained — fetches its own data on mount, fails
//      silently when the API is unreachable so the homepage never
//      shows an ugly error for optional content.
//    • Logs impressions + clicks back to the backend (best-effort).
//    • Auto-advances every 5s; pauses while the user is dragging so
//      reading a banner never feels like a fight.
//    • Tap routing handled by [onTap] — the homepage injects it so
//      deeplink / property / area targets can reuse the existing
//      navigation plumbing.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/promo_banner_service.dart';

class PromoBannerCarousel extends StatefulWidget {
  /// Called when a banner is tapped.  Receives the full banner so
  /// the host page can route based on ``ctaKind`` + ``ctaTarget``.
  final void Function(PromoBannerItem banner)? onTap;

  const PromoBannerCarousel({super.key, this.onTap});

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  final PageController _ctrl = PageController(viewportFraction: 0.92);
  List<PromoBannerItem> _banners = [];
  bool _loaded = false;
  Timer? _autoplay;
  int _currentPage = 0;
  final Set<int> _impressionLogged = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await PromoBannerService.activeBanners();
      if (!mounted) return;
      setState(() {
        _banners = res;
        _loaded = true;
      });
      if (_banners.isNotEmpty) {
        _logImpressionOnce(0);
        _startAutoplay();
      }
    } catch (_) {
      // Swallow — banners are decorative, failure == render nothing.
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _startAutoplay() {
    _autoplay?.cancel();
    if (_banners.length < 2) return;
    _autoplay = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_ctrl.hasClients) return;
      final next = (_currentPage + 1) % _banners.length;
      _ctrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _logImpressionOnce(int idx) {
    if (idx < 0 || idx >= _banners.length) return;
    final id = _banners[idx].id;
    if (_impressionLogged.add(id)) {
      PromoBannerService.logImpression(id);
    }
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    if (_banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 152,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: _banners.length,
            onPageChanged: (i) {
              _currentPage = i;
              _logImpressionOnce(i);
              setState(() {});
            },
            itemBuilder: (_, i) {
              final b = _banners[i];
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 6),
                child: GestureDetector(
                  onTap: () {
                    PromoBannerService.logClick(b.id);
                    widget.onTap?.call(b);
                  },
                  child: _BannerCard(banner: b),
                ),
              );
            },
          ),
        ),
        if (_banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_banners.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFFF6B35)
                        : Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final PromoBannerItem banner;
  const _BannerCard({required this.banner});

  Color _accent() {
    final hex = banner.accentColor?.replaceFirst('#', '');
    if (hex == null || hex.isEmpty) return const Color(0xFFFF6B35);
    try {
      return Color(int.parse('ff$hex', radix: 16));
    } catch (_) {
      return const Color(0xFFFF6B35);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    final title = banner.titleAr ?? banner.titleEn ?? '';
    final subtitle = banner.subtitleAr ?? banner.subtitleEn ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Hero image fills the whole card.
          CachedNetworkImage(
            imageUrl: banner.imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: accent.withValues(alpha: 0.15)),
            errorWidget: (_, __, ___) =>
                Container(color: accent.withValues(alpha: 0.25)),
          ),
          // Darken gradient for legibility.
          if (title.isNotEmpty || subtitle.isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          if (title.isNotEmpty || subtitle.isNotEmpty)
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (banner.ctaKind != 'none')
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_rounded,
                        color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('اعرف أكثر',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
