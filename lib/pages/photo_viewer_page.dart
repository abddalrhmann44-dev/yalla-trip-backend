// ═══════════════════════════════════════════════════════════════
//  TALAA — Full-Screen Photo Viewer
//  Pinch-to-zoom, swipe, double-tap reset. Zero external deps.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhotoViewerPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String? title;

  const PhotoViewerPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.title,
  });

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late PageController _pageCtrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageCtrl = PageController(initialPage: _index);
    // Immersive mode — hide status/nav bars for photo viewing
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // ── Zoomable PageView ─────────────────────────────────
        PageView.builder(
          controller: _pageCtrl,
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => _ZoomableImage(url: widget.images[i]),
        ),

        // ── Top bar — back + counter ──────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                _circleBtn(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const Spacer(),
                if (widget.images.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const Spacer(),
                const SizedBox(width: 40),
              ]),
            ),
          ),
        ),

        // ── Bottom title ──────────────────────────────────────
        if (widget.title != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.title!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _circleBtn({required IconData icon, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
//  Single zoomable image with double-tap reset.
// ═══════════════════════════════════════════════════════════════
class _ZoomableImage extends StatefulWidget {
  final String url;
  const _ZoomableImage({required this.url});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final TransformationController _tc = TransformationController();
  late AnimationController _animCtrl;
  Animation<Matrix4>? _anim;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220))
      ..addListener(() {
        if (_anim != null) _tc.value = _anim!.value;
      });
  }

  @override
  void dispose() {
    _tc.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition;
    final isZoomed = _tc.value != Matrix4.identity();
    final Matrix4 end;
    if (isZoomed) {
      end = Matrix4.identity();
    } else if (position != null) {
      const zoom = 2.5;
      final x = -position.dx * (zoom - 1);
      final y = -position.dy * (zoom - 1);
      end = Matrix4.identity()
        ..translateByDouble(x, y, 0, 1)
        ..scaleByDouble(zoom, zoom, 1, 1);
    } else {
      end = Matrix4.identity()..scaleByDouble(2.5, 2.5, 1, 1);
    }
    _anim = Matrix4Tween(begin: _tc.value, end: end)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _tc,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Hero(
            tag: widget.url,
            child: Image.network(
              widget.url,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_rounded,
                    color: Colors.white54, size: 80),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
