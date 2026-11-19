import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/sakuga_progress.dart';
import '../main_navigation_shell.dart';

/// Startup work that reports its progress (0 to 1) as it goes.
typedef SplashBootstrap = Future<void> Function(ValueChanged<double> report);

/// Animated startup screen.
///
/// It picks up exactly where the native Android splash leaves off (same
/// canvas colour, same logo size and position), then:
///   1. a magenta bloom opens behind the logo and a glass ring ripples out,
///   2. the logo lifts and settles,
///   3. the wordmark and tagline slide in,
///   4. a Sakuga progress bar follows [bootstrap]'s real progress,
/// and once the bar itself lands (its `sakuga:done`) fades through to the app.
class SplashScreen extends StatefulWidget {
  /// Work to finish before leaving the splash (auth, bookmarks, history).
  /// It reports progress from 0 to 1 through the callback it is given.
  final SplashBootstrap? bootstrap;

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
  final SakugaProgressController _progress = SakugaProgressController();
  final Completer<void> _barDone = Completer<void>();

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
    await _intro.forward().orCancel.catchError((_) {});
    await work;
    if (!mounted || _left) return;
    // Done (or timed out): let the bar finish and wait for it to land.
    _progress.set(1);
    await _barDone.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    if (!mounted || _left) return;
    // A beat so the landing (ドン, the check) reads before the page changes.
    if (!MediaQuery.of(context).disableAnimations) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
    }
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
  Future<void> _guard(SplashBootstrap? job) async {
    if (job == null) return;
    try {
      await job((n) {
        // Never let a late report pull a finished bar backwards.
        if (n > _progress.value) _progress.set(n);
      }).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Splash bootstrap: $e');
    }
  }

  @override
  void dispose() {
    // Releases the wait in _run (and its timeout timer) if we leave early.
    if (!_barDone.isCompleted) _barDone.complete();
    _intro.dispose();
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
          animation: _intro,
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

                  // Sakuga progress at the bottom. Mounted when its turn in the
                  // intro comes, so the ride starts from 0 where it can be seen;
                  // until then the controller just holds the latest progress.
                  if (bar.value > 0)
                    Positioned(
                      bottom: mq.padding.bottom + 12,
                      child: Opacity(
                        opacity: bar.value,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - bar.value)),
                          child: SakugaProgress(
                            controller: _progress,
                            label: 'Memuat ngomik',
                            width: math.min(280.0, mq.size.width - 48),
                            onDone: () {
                              if (!_barDone.isCompleted) _barDone.complete();
                            },
                          ),
                        ),
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
