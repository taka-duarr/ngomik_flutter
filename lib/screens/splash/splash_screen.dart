import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/app_backdrop.dart';
import '../main_navigation_shell.dart';

/// Animated startup screen.
///
/// It picks up exactly where the native Android splash leaves off (same
/// canvas colour, same logo size and position), then:
///   1. a magenta bloom opens behind the logo and a glass ring ripples out,
///   2. the logo lifts and settles,
///   3. the wordmark and tagline slide in,
///   4. a slim glass progress track runs while [bootstrap] finishes,
/// and finally fades through to the app.
class SplashScreen extends StatefulWidget {
  /// Work to finish before leaving the splash (auth, bookmarks, history).
  final Future<void> Function()? bootstrap;

  const SplashScreen({super.key, this.bootstrap});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Intro choreography (one controller, staggered with Intervals).
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  // Looping shimmer on the progress track while we wait.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool _left = false;

  /// The native splash draws the 288px bitmap at raw pixel size (drawable-nodpi).
  static const double _nativeLogoPx = 288;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final work = _guard(widget.bootstrap);
    _loop.repeat();
    await _intro.forward().orCancel.catchError((_) {});
    await work;
    if (!mounted || _left) return;
    _left = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (_, _, _) => const MainNavigationShell(),
        transitionsBuilder: (_, anim, _, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 1.04, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  /// Never let a slow/failed network call trap the user on the splash.
  Future<void> _guard(Future<void> Function()? job) async {
    if (job == null) return;
    try {
      await job().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Splash bootstrap: $e');
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  Animation<double> _seg(
    double a,
    double b, [
    Curve curve = Curves.easeOutCubic,
  ]) => CurvedAnimation(
    parent: _intro,
    curve: Interval(a, b, curve: curve),
  );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.disableAnimations && !_intro.isCompleted) _intro.value = 1;

    final startSize = _nativeLogoPx / mq.devicePixelRatio;
    final endSize = math.min(132.0, mq.size.width * 0.34);

    final bloom = _seg(0.0, 0.55);
    final ring = _seg(0.12, 0.8, Curves.easeOut);
    final lift = _seg(0.18, 0.62, Curves.easeOutBack);
    final word = _seg(0.42, 0.8, Curves.easeOutCubic);
    final tag = _seg(0.55, 0.92, Curves.easeOutCubic);
    final bar = _seg(0.7, 1.0);

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBuilder(
          animation: Listenable.merge([_intro, _loop]),
          builder: (context, _) {
            final logoSize = startSize + (endSize - startSize) * lift.value;
            // Fill the screen so "center" matches the native splash's centre.
            return SizedBox.expand(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Magenta bloom behind the logo
                  Transform.translate(
                    offset: Offset(0, -46 * lift.value),
                    child: Opacity(
                      opacity: 0.85 * bloom.value,
                      child: Transform.scale(
                        scale: 0.4 + 0.9 * bloom.value,
                        child: Container(
                          width: 320,
                          height: 320,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(0x99E2288E),
                                Color(0x33B5186E),
                                Color(0x00242942),
                              ],
                              stops: [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Glass ripple ring
                  Transform.translate(
                    offset: Offset(0, -46 * lift.value),
                    child: Opacity(
                      opacity: (1 - ring.value) * (ring.value > 0 ? 1 : 0),
                      child: Container(
                        width: endSize + 160 * ring.value,
                        height: endSize + 160 * ring.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Logo + wordmark column
                  Transform.translate(
                    offset: Offset(0, -46 * lift.value),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: logoSize,
                          height: logoSize,
                          child: Image.asset(
                            'assets/images/logo_mark.png',
                            filterQuality: FilterQuality.medium,
                            semanticLabel: 'Logo Ngomik',
                          ),
                        ),
                        // Collapsed to zero height until the wordmark arrives, so
                        // the logo starts exactly where the native splash drew it.
                        // Align (no clip) shrinks the layout height while letting
                        // descenders like the "g" paint in full.
                        SizedBox(height: 18 * word.value),
                        Align(
                          heightFactor: word.value,
                          child: Opacity(
                            opacity: word.value,
                            child: Transform.translate(
                              offset: Offset(0, 14 * (1 - word.value)),
                              child: const _Wordmark(),
                            ),
                          ),
                        ),
                        SizedBox(height: 6 * tag.value),
                        Align(
                          heightFactor: tag.value,
                          child: Opacity(
                            opacity: tag.value,
                            child: Transform.translate(
                              offset: Offset(0, 10 * (1 - tag.value)),
                              child: const Text(
                                'baca komik, tanpa ribet',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Progress track at the bottom
                  Positioned(
                    bottom: mq.padding.bottom + 56,
                    child: Opacity(
                      opacity: bar.value,
                      child: _GlassProgress(phase: _loop.value),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'ngo',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          TextSpan(
            text: 'mik',
            style: TextStyle(color: AppColors.primaryLight),
          ),
        ],
      ),
      style: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.1,
      ),
      semanticsLabel: 'Ngomik',
    );
  }
}

/// Slim frosted track with a magenta comet sweeping across.
class _GlassProgress extends StatelessWidget {
  final double phase; // 0..1, looping

  const _GlassProgress({required this.phase});

  static const double _w = 120;
  static const double _h = 6;
  static const double _comet = 44;

  @override
  Widget build(BuildContext context) {
    final x = -_comet + (_w + _comet) * Curves.easeInOut.transform(phase);
    return Semantics(
      label: 'Memuat',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_h),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: _w,
            height: _h,
            decoration: BoxDecoration(
              color: const Color(0x591C2038),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.6,
              ),
              borderRadius: BorderRadius.circular(_h),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: x,
                  top: 0,
                  bottom: 0,
                  width: _comet,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x00E2288E),
                          Color(0xFFE2288E),
                          Color(0xFFFF6CB8),
                        ],
                        stops: [0.0, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
