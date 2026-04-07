import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _taglineCtrl;
  late final AnimationController _dotsCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _orbitCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoRotate;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _dotsOpacity;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
    _logoRotate = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));

    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    _taglineCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut));
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut));

    _dotsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _dotsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dotsCtrl, curve: Curves.easeOut));

    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _orbitCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    await _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    await _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 80));
    await _taglineCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    await _dotsCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context).pushReplacementNamed('/auth');
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _taglineCtrl.dispose();
    _dotsCtrl.dispose();
    _shimmerCtrl.dispose();
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF020B18),
      body: Stack(children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF020B18), Color(0xFF0A1628), Color(0xFF0D2142), Color(0xFF1A3A6E)],
              stops: [0.0, 0.3, 0.65, 1.0],
            ),
          ),
        ),

        // Decorative circles
        Positioned(
          top: -size.width * 0.2, right: -size.width * 0.2,
          child: Container(
            width: size.width * 0.8, height: size.width * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE8A838).withValues(alpha: 0.08), width: 1),
            ),
          ),
        ),
        Positioned(
          bottom: -size.width * 0.3, left: -size.width * 0.3,
          child: Container(
            width: size.width * 1.2, height: size.width * 1.2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.12), width: 1),
            ),
          ),
        ),
        Positioned(
          top: size.height * 0.18, right: size.width * 0.08,
          child: Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1565C0).withValues(alpha: 0.05),
            ),
          ),
        ),

        // Gold accent line
        Positioned(
          top: MediaQuery.of(context).padding.top, left: 0, right: 0,
          child: Container(height: 1.5, color: const Color(0xFFE8A838).withValues(alpha: 0.35)),
        ),

        // Center content
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: _logoCtrl,
              builder: (_, __) => Opacity(
                opacity: _logoOpacity.value,
                child: Transform.scale(
                  scale: _logoScale.value,
                  child: Transform.rotate(angle: _logoRotate.value, child: _buildLogo()),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(opacity: _textOpacity, child: _buildAppName()),
            ),
            const SizedBox(height: 12),
            SlideTransition(
              position: _taglineSlide,
              child: FadeTransition(
                opacity: _taglineOpacity,
                child: Text(
                  'اكتشف  •  احجز  •  استمتع',
                  style: TextStyle(
                    fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.5), letterSpacing: 2.5,
                  ),
                ),
              ),
            ),
          ]),
        ),

        // Bottom loading dots
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 40,
          left: 0, right: 0,
          child: FadeTransition(
            opacity: _dotsOpacity,
            child: Column(children: [
              _buildLoadingDots(),
              const SizedBox(height: 14),
              Text('v1.0.0', style: TextStyle(
                fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.2), letterSpacing: 1.2,
              )),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      width: 130, height: 130,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: 130, height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE8A838).withValues(alpha: 0.35), width: 1.5),
          ),
        ),
        AnimatedBuilder(
          animation: _orbitCtrl,
          builder: (_, __) {
            final pulse = (sin(_orbitCtrl.value * 2 * pi) + 1) / 2;
            return Container(
              width: 100 + pulse * 10, height: 100 + pulse * 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.25 + pulse * 0.15),
                  blurRadius: 24 + pulse * 12,
                )],
              ),
            );
          },
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (_, child) {
              return Stack(children: [
                child!,
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(-100 + _shimmerCtrl.value * 300, 0),
                    child: Transform(
                      transform: Matrix4.skewX(-0.3),
                      child: Container(
                        width: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ]);
            },
            child: Container(
              width: 100, height: 100,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1976D2), Color(0xFF1565C0), Color(0xFF082A80)],
                ),
              ),
              child: const Center(child: Text('✈', style: TextStyle(fontSize: 44, color: Colors.white))),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _orbitCtrl,
          builder: (_, __) {
            final angle = _orbitCtrl.value * 2 * pi;
            return Stack(children: [
              _orbitDot(65, angle),
              _orbitDot(65, angle + pi * 0.7),
              _orbitDot(65, angle + pi * 1.4),
            ]);
          },
        ),
      ]),
    );
  }

  Widget _orbitDot(double radius, double angle) {
    return Positioned(
      left: 65 + radius * cos(angle) - 4,
      top: 65 + radius * sin(angle) - 4,
      child: Container(
        width: 8, height: 8,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8A838)),
      ),
    );
  }

  Widget _buildAppName() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('Trip', style: TextStyle(
          fontSize: 42, fontFamily: 'Outfit', fontWeight: FontWeight.w400,
          color: const Color(0xFFE8A838), letterSpacing: -1,
        )),
        const SizedBox(width: 6),
        const Text('Yalla', style: TextStyle(
          fontSize: 42, fontFamily: 'Outfit', fontWeight: FontWeight.w900,
          color: Colors.white, letterSpacing: -1.5,
        )),
      ],
    );
  }

  Widget _buildLoadingDots() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((_shimmerCtrl.value * 3) - i).clamp(0.0, 1.0);
            final pulse = sin(phase * pi);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 6 + pulse * 2, height: 6 + pulse * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8A838).withValues(alpha: 0.4 + pulse * 0.6),
              ),
            );
          }),
        );
      },
    );
  }
}
