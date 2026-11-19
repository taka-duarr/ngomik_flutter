import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../core/constants/app_colors.dart';
import 'sakuga_fx.dart';

/// Drives a [SakugaProgress]: call [set] with progress from 0 to 1 as often
/// as it changes. The bar eases toward the number, so a jump is still ridden;
/// `set(n, instant: true)` goes straight there. [reset] puts it back to 0.
class SakugaProgressController {
  _SakugaProgressState? _state;
  double _goal = 0;

  double get value => _goal;
  bool get done => _state?._doneAt != null;

  void set(double n, {bool instant = false}) {
    _goal = n.isNaN ? 0 : n.clamp(0.0, 1.0);
    _state?._set(_goal, instant);
  }

  void reset() {
    _goal = 0;
    _state?._reset();
  }
}

/// Loading bar in the Sakuga style: a storm cloud rides the leading edge and
/// grows as the bar fills, dragging back when it surges; wisps tear off it and
/// speed lines trail it. Pebbles lift off a ground line as the edge passes,
/// and ゴゴゴゴ rumbles once it is under way. At 100% a burst goes off behind
/// the bar with ドン, a check lands above it, two small clouds stay on the
/// ground, and [onDone] fires once (the `sakuga:done` event).
///
/// Behaviour follows `<sakuga-progress>`; colours are adapted to the dark
/// palette. It is [width] wide and keeps 70 px above the bar for the cloud
/// and about 110 px below for the ground and the percentage. With reduced
/// motion on, only the bar and the percentage are drawn; it still finishes
/// and still fires [onDone].
class SakugaProgress extends StatefulWidget {
  final SakugaProgressController controller;

  /// What a screen reader hears: say what is loading.
  final String label;
  final String doneLabel;
  final VoidCallback? onDone;
  final double width;

  const SakugaProgress({
    super.key,
    required this.controller,
    required this.label,
    this.doneLabel = 'Selesai ✓',
    this.onDone,
    this.width = 280,
  });

  /// Total height of the widget for the default text scale.
  static const double height = _headroom + _barH + _pctGap + 36;

  static const double _headroom = 70;
  static const double _barH = 38;
  static const double _pctGap = 64;

  @override
  State<SakugaProgress> createState() => _SakugaProgressState();
}

class _Peb {
  final double u, s, ph, rot;
  final SakugaSpring lift = SakugaSpring(0, 70, 7);
  final List<Offset> pts;
  double up = 0;

  _Peb(this.u)
      : s = SakugaFx.rnd(3.4, 5.6),
        ph = SakugaFx.rnd(6.28),
        rot = SakugaFx.rnd(-0.5, 0.5),
        pts = const [Offset(-1, 0.4), Offset(-0.5, -0.8), Offset(0.5, -1), Offset(1, 0.1), Offset(0.3, 0.9)]
            .map((q) => Offset(q.dx * SakugaFx.rnd(0.8, 1.2), q.dy * SakugaFx.rnd(0.8, 1.2)))
            .toList();
}

class _CloudLobe {
  final double x, y, r, ph, w;
  final int i;
  _CloudLobe(this.x, this.y, this.r, this.i)
      : ph = SakugaFx.rnd(6.28),
        w = SakugaFx.rnd(1.4, 2.6);
}

class _SakugaProgressState extends State<SakugaProgress> with SingleTickerProviderStateMixin {
  static const List<List<double>> _lobeSpec = [
    [0, -0.95, 1], [0.78, -0.55, 0.74], [-0.72, -0.78, 0.72], [0.36, -1.7, 0.7], //
    [-0.4, -1.62, 0.62], [1.1, -1.32, 0.52], [-1.18, -0.28, 0.52], [0.62, 0.3, 0.5],
    [-0.86, 0.5, 0.52], [-1.5, 0.82, 0.38], [-2.05, 1.0, 0.24], [0.16, 0.72, 0.4],
  ];

  // Colours of the control itself (the effects use SakugaFx's palette).
  static const Color _ink = Color(0xFFE4E2F7);
  static const Color _card = AppColors.card;
  static const Color _fillColor = AppColors.primary;

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final _Frame _frame = _Frame();
  final SakugaLayer _back = SakugaLayer();

  double p = 0, goal = 0, t = 0, acc = 0, spd = 0;
  double? _doneAt;
  bool said = false;
  String lastPct = '';

  final List<_CloudLobe> lobes = [
    for (var i = 0; i < _lobeSpec.length; i++) _CloudLobe(_lobeSpec[i][0], _lobeSpec[i][1], _lobeSpec[i][2], i),
  ];
  final List<_Peb> pebbles = [for (final u in const [0.14, 0.31, 0.5, 0.69, 0.87]) _Peb(u)];
  final SakugaSpring size = SakugaSpring(0, 90, 13);
  final SakugaSpring lag = SakugaSpring(0, 120, 16);
  final SakugaSpring ck = SakugaSpring(0, 260, 13);
  final SakugaSpring tag = SakugaSpring(1, 500, 13);
  final SakugaSpring rest = SakugaSpring(0, 160, 14);

  // Spring values for this frame, read by the painter.
  double cloudS = 0, drag = 0, check = 0, restS = 0, tagS = 1;

  bool get isDone => _doneAt != null;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    goal = widget.controller._goal;
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(covariant SakugaProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller._state == this) oldWidget.controller._state = null;
      widget.controller._state = this;
      goal = widget.controller._goal;
    }
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    _ticker.dispose();
    _frame.dispose();
    _back.dispose();
    super.dispose();
  }

  void _set(double n, bool instant) {
    if (isDone && n >= 1) return;
    if (n < p - 0.001 || instant) {
      if (n < p) _clear();
      p = n;
    }
    goal = n;
  }

  void _reset() {
    _clear();
    p = 0;
    goal = 0;
  }

  void _clear() {
    _doneAt = null;
    said = false;
  }

  // Bar geometry in this widget's coordinates.
  double get _w => widget.width;
  double get _top => SakugaProgress._headroom;
  double get _cy => _top + SakugaProgress._barH / 2;
  double get _lead => 4 + (_w - 8) * p;

  Offset _global(Offset local) {
    final box = context.findRenderObject() as RenderBox?;
    return box == null || !box.attached ? local : box.localToGlobal(local);
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.034);
    _last = elapsed;
    t += dt;
    final calm = SakugaFx.calm(context);
    final fx = SakugaFx.instance;
    final rnd = SakugaFx.rnd;

    final was = p;
    if (!isDone && p < goal) {
      p = math.min(goal, p + dt * ((goal - p) * 3).clamp(0.12, 0.9));
    }
    spd = spd + ((dt > 0 ? (p - was) / dt : 0) - spd) * math.min(1, dt * 8);

    final lead = _lead, top = _top, cx = _w / 2;
    if (!isDone && !calm) {
      if (p > 0.06 && spd > 0.02) {
        // wisps torn off the back of the cloud, and the lines of its speed
        acc += dt * (4 + spd * 60);
        while (acc > 1) {
          acc -= 1;
          final s = 10 + 25 * math.sqrt(p);
          if (rnd(1) < 0.5) {
            fx.puff(context, _global(Offset(lead - s * rnd(0.9, 1.6), top - s * rnd(0.1, 0.9))),
                size: rnd(3, 5.5) + p * 3, n: 2, vx: -rnd(40, 90), vy: rnd(-12, 4), life: rnd(0.4, 0.7));
          } else {
            fx.lines(context, _global(Offset(lead - s * 1.4, top - s * rnd(0.2, 1.3))),
                n: 1, dir: math.pi, len: 30 + spd * 160, spread: 3, life: 0.3);
          }
          if (rnd(1) < 0.16) {
            fx.ticks(context, _global(Offset(lead + s * 1.1, top - s * 1.5)), dir: -0.7, n: 3, r: 4, len: 8, life: 0.35);
          }
        }
      }
      if (!said && p > 0.3 && p < 0.9) {
        said = true;
        fx.sfx(context, 'gogo', _global(Offset(cx - 34, top - 66)), size: 150, rot: -0.1, life: 2.9);
        fx.ticks(context, _global(Offset(cx + 52, top - 84)), dir: -0.5, n: 2, r: 4, len: 10, life: 0.6);
        fx.ticks(context, _global(Offset(8, top - 40)), dir: math.pi + 0.3, n: 2, r: 4, len: 10, life: 0.6);
      }
    }

    if (!isDone && p >= 1) {
      // the end: a burst behind the bar, ドン, clouds all round
      _doneAt = t;
      final r = _w, cy = _cy;
      if (!calm) {
        _back.add(SakugaEffects.burst(Offset(r - 74, cy), r: 92, spikes: 15, life: 0.5));
        fx.burst(context, _global(Offset(r - 60, cy)), r: 40, life: 0.3);
        fx.shards(context, _global(Offset(r - 60, cy)), n: 11, speed: 270, size: 7, life: 0.9, arc: 6.28);
        for (var i = 0; i < 7; i++) {
          final a = i / 7 * 6.28 + rnd(0.5);
          fx.puff(context, _global(Offset(r - 70 + math.cos(a) * 70, cy + math.sin(a) * 34)),
              size: rnd(8, 13), n: 4, vx: math.cos(a) * 46, vy: math.sin(a) * 30 - 8, life: rnd(0.6, 1));
        }
        fx.sfx(context, 'don', _global(Offset(cx - 26, top - 62)), size: 170, rot: -0.12, life: 1.05);
      }
      tag.x = 1.5;
      widget.onDone?.call();
    }

    final n = isDone ? 100 : (p * 100).floor();
    final key = isDone ? widget.doneLabel : '$n%';
    if (key != lastPct) {
      lastPct = key;
      if (n % 5 == 0 && !isDone) tag.x = 1.1;
    }
    tagS = tag.step(dt);

    // The persistent drawing: springs for the ground, pebbles, cloud, check.
    final done = isDone;
    for (final q in pebbles) {
      q.lift.to = !done && lead > _w * q.u - 16 ? 1 : 0;
      q.up = q.lift.step(dt);
    }
    rest.to = done ? 1 : 0;
    restS = math.max(0, rest.step(dt));
    size.to = done || p < 0.015 ? 0 : 10 + 25 * math.sqrt(p);
    lag.to = spd;
    cloudS = math.max(0, size.step(dt));
    drag = lag.step(dt);
    ck.to = done ? 1 : 0;
    check = math.max(0, ck.step(dt));

    _back.advance(dt);
    _frame.ping();
  }

  @override
  Widget build(BuildContext context) {
    final calm = SakugaFx.calm(context);
    return Semantics(
      label: widget.label,
      child: ListenableBuilder(
        listenable: _frame,
        builder: (context, _) {
          final pct = isDone ? 100 : (p * 100).floor();
          return Semantics(
            value: '$pct%',
            child: SizedBox(
              width: _w,
              child: CustomPaint(
                painter: SakugaLayerPainter(_back),
                foregroundPainter: calm ? null : _FrontPainter(this, _frame),
                child: Padding(
                  padding: const EdgeInsets.only(top: SakugaProgress._headroom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _bar(),
                      const SizedBox(height: SakugaProgress._pctGap),
                      _pctTag(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _bar() {
    return Container(
      height: SakugaProgress._barH,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _ink, width: 4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: p,
            heightFactor: 1,
            child: const ColoredBox(
              color: _fillColor,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // the two glints on the fill
                  Positioned(left: 22, top: 5, child: _Glint(width: 9)),
                  Positioned(left: 37, top: 5, child: _Glint(width: 6)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pctTag() {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(-12 * math.pi / 180)..scaleByDouble(tagS, tagS, 1, 1),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 3, 13, 4),
        decoration: BoxDecoration(
          color: _card,
          border: Border.all(color: _ink, width: 2.5),
          boxShadow: const [BoxShadow(color: _fillColor, offset: Offset(5, 5))],
        ),
        child: Text(
          lastPct.isEmpty ? '0%' : lastPct,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 21,
            height: 1.1,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.2,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _Glint extends StatelessWidget {
  final double width;
  const _Glint({required this.width});

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.skewX(-28 * math.pi / 180),
      child: Container(
        width: width,
        height: 11,
        decoration: BoxDecoration(
          color: const Color(0xEBFFFFFF),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Frame extends ChangeNotifier {
  void ping() => notifyListeners();
}

final Paint _lineStroke = Paint()
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..color = SakugaFx.line;

/// The ground, the pebbles, the cloud, the leftover clouds and the check,
/// drawn every frame over the control.
class _FrontPainter extends CustomPainter {
  final _SakugaProgressState s;
  _FrontPainter(this.s, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas g, Size size) {
    final w = s._w, p = s.p, done = s.isDone, tt = s.t;
    final lead = s._lead, cy = s._cy;
    final gy = cy + SakugaProgress._barH / 2 + 30;

    // the ground draws itself out under the fill
    final reach = sakugaClamp(p * 1.25 + (done ? 1 : 0));
    final gx1 = 10 + (w - 20) * reach;
    if (reach > 0.02) {
      final path = Path()
        ..moveTo(10, gy)
        ..lineTo(gx1, gy);
      for (var x = 26.0; x < gx1 - 6; x += 37) {
        path
          ..moveTo(x, gy)
          ..lineTo(x + 3, gy - 4)
          ..moveTo(x + 5, gy)
          ..lineTo(x + 6.5, gy - 2.5);
      }
      g.drawPath(path, _lineStroke..strokeWidth = 1.4);
    }

    // a pebble lifts when the edge goes over it and drops when the load is done
    for (final q in s.pebbles) {
      final px = w * q.u, up = q.up;
      if (reach < q.u - 0.04 && up < 0.01) continue;
      final y = gy - q.s * 0.7 - up * (7 + q.s * 1.5) + math.sin(tt * 3 + q.ph) * 2 * up;
      g.save();
      g.translate(px, y);
      g.rotate(q.rot + up * math.sin(tt * 2 + q.ph) * 0.5);
      final path = Path()..moveTo(q.pts[0].dx * q.s, q.pts[0].dy * q.s);
      for (var i = 1; i < q.pts.length; i++) {
        path.lineTo(q.pts[i].dx * q.s, q.pts[i].dy * q.s);
      }
      path.close();
      sakugaShape(g, path, 1.1, q.s * 0.5);
      g.restore();
      if (up > 0.15 && up < 0.9 && q.lift.v > 0.6) {
        final marks = Path();
        for (final a in const [-1.9, -1.57, -1.24]) {
          marks
            ..moveTo(px + math.cos(a) * (q.s + 5), y + math.sin(a) * (q.s + 5))
            ..lineTo(px + math.cos(a) * (q.s + 11), y + math.sin(a) * (q.s + 11));
        }
        g.drawPath(
          marks,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 2.4
            ..color = SakugaFx.accent,
        );
      }
    }

    // the two small clouds left on the ground when it is over
    final rs = s.restS;
    if (rs > 0.02) {
      for (final (x, d) in [(34.0, -1.0), (w - 40, 1.0)]) {
        final cs = <(double, double, double)>[
          (x, gy - 9 * rs, 8 * rs),
          (x + 8 * d, gy - 6 * rs, 6 * rs),
          (x - 6 * d, gy - 5 * rs, 5.5 * rs),
          (x + 2 * d, gy - 15 * rs, 5.5 * rs),
        ];
        sakugaBlob(
          g,
          [for (var n = 0; n < cs.length; n++) (cs[n].$1, cs[n].$2, cs[n].$3 * (1 + math.sin(tt * 3 + n) * 0.06))],
          lw: 1.3,
          lx: 1,
          arcs: true,
        );
        g.drawPath(
          Path()
            ..moveTo(x + d * 18, gy - 6)
            ..lineTo(x + d * 25, gy - 6)
            ..moveTo(x + d * 19, gy - 1.5)
            ..lineTo(x + d * 23, gy - 1.5),
          _lineStroke..strokeWidth = 1.4,
        );
      }
    }

    // the cloud: lobes swell in turn, so it reads as rolling forward
    final cs = s.cloudS;
    if (cs > 0.6) {
      sakugaBlob(
        g,
        [
          for (final l in s.lobes)
            (
              lead + 3 + (l.x + math.cos(tt * l.w * 0.7 + l.ph) * 0.1 - s.drag * 1.6 * math.max(0, -l.y) * 0.5) * cs,
              cy - 3 + (l.y + math.sin(tt * l.w * 0.7 + l.ph) * 0.1) * cs,
              l.r * cs * (1 + 0.16 * math.sin(tt * l.w + l.ph)) * (0.82 + 0.22 * math.sin(tt * 2.6 - l.i * 0.9)),
            ),
        ],
        lw: 1.6,
        lx: 1,
        arcs: true,
        deep: 1.7,
      );
    }

    // the check
    final c = s.check;
    if (c > 0.02) {
      g.save();
      g.translate(w / 2 + 4, cy - SakugaProgress._barH / 2 - 56);
      g.rotate((1 - c) * -0.5);
      g.scale(c, c);
      g.drawPath(
        Path()
          ..moveTo(-28, 2)
          ..lineTo(-8, 22)
          ..lineTo(30, -26),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeJoin = StrokeJoin.miter
          ..strokeCap = StrokeCap.butt
          ..color = SakugaFx.accent,
      );
      final rays = Path();
      for (final (a, d) in const [(-2.6, 58.0), (-2.95, 60.0), (-0.35, 56.0), (-0.1, 60.0)]) {
        rays
          ..moveTo(math.cos(a) * d, math.sin(a) * d * 0.7)
          ..lineTo(math.cos(a) * (d + 13), math.sin(a) * (d + 13) * 0.7);
      }
      g.drawPath(
        rays,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = SakugaFx.accent,
      );
      final sz = 15 * (0.9 + 0.1 * math.sin(tt * 5)), q = sz * 0.14;
      g.translate(74, 28);
      final sp = Path()
        ..moveTo(0, -sz)
        ..quadraticBezierTo(q, -q, sz * 0.75, 0)
        ..quadraticBezierTo(q, q, 0, sz)
        ..quadraticBezierTo(-q, q, -sz * 0.75, 0)
        ..quadraticBezierTo(-q, -q, 0, -sz);
      g.drawPath(sp, Paint()..color = SakugaFx.fill);
      g.drawPath(
        sp,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = SakugaFx.line,
      );
      g.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FrontPainter old) => true;
}
