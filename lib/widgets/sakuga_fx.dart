import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../core/constants/app_colors.dart';
import 'sakuga_words.dart';

/// Anime-style effects ported from the Sakuga VFX core, re-coloured for the
/// ngomik palette.
///
/// The rules kept from the original:
/// - every shape is one light tone, one shadow tone and an outline (no
///   gradients, no blur);
/// - effects leave by shrinking or thinning, never by fading;
/// - nothing is drawn when the OS asks for reduced motion.
///
/// [SakugaFx.instance] is the "front layer": one [OverlayEntry] over the whole
/// app, so effects can fly outside the control that fired them. It only
/// exists while an effect is alive and its ticker stops when the last one
/// ends, so it costs nothing at rest. A control can also keep its own
/// [SakugaLayer] to draw effects behind itself (the "back layer").
class SakugaFx {
  SakugaFx._();
  static final SakugaFx instance = SakugaFx._();

  // Palette: light tone, shadow tone, outline, accent, ink.
  static const Color fill = AppColors.textPrimary;
  static const Color shade = AppColors.accent;
  static const Color line = Color(0xFF5A4FD8);
  static const Color accent = AppColors.primary;
  static const Color ink = Color(0xFF1D1A4A);

  static final math.Random _rng = math.Random();
  static double rnd(double a, [double? b]) =>
      b == null ? _rng.nextDouble() * a : a + _rng.nextDouble() * (b - a);

  /// True when effects must not be drawn (reduced motion).
  static bool calm(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  final SakugaLayer _layer = SakugaLayer();
  OverlayEntry? _entry;
  OverlayState? _overlay;
  Ticker? _ticker;
  Duration _last = Duration.zero;

  /// Accent wedges that point at something and fly off it.
  void ticks(BuildContext context, Offset global,
      {int n = 3, double r = 16, double len = 9, double dir = -0.9, double life = 0.4, double fan = 0.42}) {
    _spawn(context, global, (o) => SakugaEffects.ticks(o, n: n, r: r, len: len, dir: dir, life: life, fan: fan));
  }

  /// A puff of smoke: lobes swell out with a little overshoot, roll, and shrink away.
  void puff(BuildContext context, Offset global,
      {int n = 5, double size = 13, double vx = 0, double vy = -18, double life = 0.8, double spread = 1}) {
    _spawn(context, global,
        (o) => SakugaEffects.puff(o, n: n, size: size, vx: vx, vy: vy, life: life, spread: spread));
  }

  /// Crystal chips: long facets with one edge line, tumbling and falling.
  void shards(BuildContext context, Offset global,
      {int n = 7,
      double speed = 190,
      double size = 5,
      double life = 0.75,
      double dir = -math.pi / 2,
      double arc = math.pi,
      double grav = 420}) {
    _spawn(context, global,
        (o) => SakugaEffects.shards(o, n: n, speed: speed, size: size, life: life, dir: dir, arc: arc, grav: grav));
  }

  /// Speed lines: strokes that shoot out one way and thin away.
  void lines(BuildContext context, Offset global,
      {int n = 7, double dir = math.pi, double len = 46, double spread = 26, double life = 0.3}) {
    _spawn(context, global,
        (o) => SakugaEffects.lines(o, n: n, dir: dir, len: len, spread: spread, life: life));
  }

  /// The impact star.
  void burst(BuildContext context, Offset global, {double r = 44, int spikes = 13, double life = 0.34}) {
    _spawn(context, global, (o) => [SakugaEffects.burst(o, r: r, spikes: spikes, life: life)]);
  }

  /// A sound-effect word ('gogo' or 'don') that lands a size too big and
  /// wobbles while it stays.
  void sfx(BuildContext context, String word, Offset global,
      {double size = 64, double rot = -0.14, double life = 0.95}) {
    _spawn(context, global, (o) {
      final fx = SakugaEffects.sfx(word, o, size: size, rot: rot, life: life);
      return fx == null ? const [] : [fx];
    });
  }

  void _spawn(BuildContext context, Offset global, List<SakugaEffect> Function(Offset local) make) {
    if (calm(context)) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    if (_overlay != overlay) {
      _entry?.remove();
      _entry = null;
      _overlay = overlay;
    }
    if (_entry == null) {
      _entry = OverlayEntry(
        builder: (_) => IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(size: Size.infinite, painter: SakugaLayerPainter(_layer)),
          ),
        ),
      );
      overlay.insert(_entry!);
    }
    final box = overlay.context.findRenderObject() as RenderBox?;
    _layer.addAll(make(box == null ? global : box.globalToLocal(global)));
    _ticker ??= Ticker(_onTick);
    if (!_ticker!.isActive) {
      _last = Duration.zero;
      _ticker!.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.034);
    _last = elapsed;
    _layer.advance(dt);
    if (_layer.isEmpty) {
      _ticker!.stop();
      _entry?.remove();
      _entry = null;
    }
  }
}

/// A list of live effects in one coordinate space. Call [advance] every
/// frame and paint it with [SakugaLayerPainter].
class SakugaLayer extends ChangeNotifier {
  final List<SakugaEffect> _live = [];

  bool get isEmpty => _live.isEmpty;

  void add(SakugaEffect fx) => _live.add(fx);
  void addAll(Iterable<SakugaEffect> fx) => _live.addAll(fx);

  void advance(double dt) {
    final had = _live.isNotEmpty;
    _live.removeWhere((fx) => (fx.t += dt) >= fx.life);
    if (had) notifyListeners();
  }

  void paint(Canvas canvas) {
    for (final fx in _live) {
      canvas.save();
      fx.paint(canvas, (fx.t / fx.life).clamp(0.0, 1.0), fx.t);
      canvas.restore();
    }
  }
}

class SakugaLayerPainter extends CustomPainter {
  final SakugaLayer layer;
  SakugaLayerPainter(this.layer) : super(repaint: layer);

  @override
  void paint(Canvas canvas, Size size) => layer.paint(canvas);

  @override
  bool shouldRepaint(covariant SakugaLayerPainter old) => old.layer != layer;
}

/// A spring: the thing that makes a control overshoot and settle instead of
/// stopping dead. Same integrator as the core (8 ms substeps).
class SakugaSpring {
  double x, v = 0, to;
  final double k, d;

  SakugaSpring(this.x, [this.k = 300, this.d = 20]) : to = x;

  double step(double dt) {
    if (!(dt > 0)) return x;
    final n = (dt / 0.008).ceil();
    final h = dt / n;
    for (var i = 0; i < n; i++) {
      v += (-k * (x - to) - d * v) * h;
      x += v * h;
    }
    return x;
  }
}

// ── easing helpers (same curves as the core) ───────────────────────────────

double sakugaClamp(double v) => v.clamp(0.0, 1.0);
double sakugaOut(double t) => 1 - math.pow(1 - t, 3).toDouble();
double sakugaIn(double t) => t * t * t;
double sakugaBack(double t) {
  final u = t - 1;
  return 1 + 2.70158 * u * u * u + 1.70158 * u * u;
}

// ── drawing helpers: two tones and a line ──────────────────────────────────

final Paint _stroke = Paint()
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..color = SakugaFx.line;
final Paint _shadePaint = Paint()..color = SakugaFx.shade;
final Paint _fillPaint = Paint()..color = SakugaFx.fill;
final Paint _accentPaint = Paint()..color = SakugaFx.accent;

/// Circles drawn as one shape: outline, shadow tone, then the light side slid
/// up and to the side. [arcs] adds the cumulus lines inside a cloud.
void sakugaBlob(Canvas c, List<(double, double, double)> cs,
    {double lw = 1.5, double lx = -1, bool arcs = false, double deep = 1}) {
  final u = Path();
  for (final (x, y, r) in cs) {
    if (r > 0.3) u.addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
  }
  c.drawPath(u, _stroke..strokeWidth = lw * 2);
  c.save();
  c.clipPath(u);
  c.drawPaint(_shadePaint);
  final r0 = cs.isEmpty ? 8.0 : cs.first.$3;
  c.save();
  c.translate(lx * r0 * 0.2 * deep, -r0 * 0.26 * deep);
  c.drawPath(u, _fillPaint);
  c.restore();
  if (arcs) {
    final a = Path();
    for (final (x, y, rr) in cs) {
      if (rr > 3) {
        a.addArc(Rect.fromCircle(center: Offset(x, y), radius: rr), -2.7, 2.2);
      }
    }
    c.drawPath(a, _stroke..strokeWidth = lw * 0.75);
  }
  c.restore();
}

/// Any path as outline + shadow tone + light tone slid up-left by [off].
void sakugaShape(Canvas c, Path p, double lw, double off, [Paint? fill]) {
  c.drawPath(p, _stroke..strokeWidth = lw * 2);
  c.save();
  c.clipPath(p);
  c.drawPaint(_shadePaint);
  c.translate(-off * 0.7, -off);
  c.drawPath(p, fill ?? _fillPaint);
  c.restore();
}

// ── effects ────────────────────────────────────────────────────────────────

abstract class SakugaEffect {
  final double life;
  double t = 0;
  SakugaEffect(this.life);

  /// [k] is 0..1 through the effect's life, [t] its age in seconds.
  void paint(Canvas c, double k, double t);
}

/// Builders for each effect at a point in a layer's coordinates.
class SakugaEffects {
  SakugaEffects._();

  static List<SakugaEffect> ticks(Offset o,
          {int n = 3, double r = 16, double len = 9, double dir = -0.9, double life = 0.4, double fan = 0.42}) =>
      [_Ticks(o, n: n, r: r, len: len, dir: dir, fan: fan, life: life)];

  static List<SakugaEffect> puff(Offset o,
          {int n = 5, double size = 13, double vx = 0, double vy = -18, double life = 0.8, double spread = 1}) =>
      [_Puff(o, n: n, size: size, vx: vx, vy: vy, life: life, spread: spread)];

  static List<SakugaEffect> shards(Offset o,
      {int n = 7,
      double speed = 190,
      double size = 5,
      double life = 0.75,
      double dir = -math.pi / 2,
      double arc = math.pi,
      double grav = 420}) {
    final rnd = SakugaFx.rnd;
    return [
      for (var i = 0; i < n; i++)
        _Shard(o,
            a: dir + rnd(-arc, arc) / 2,
            v: speed * rnd(0.5, 1.15),
            s: size * rnd(0.6, 1.4),
            spin: rnd(-7, 7),
            grav: grav,
            life: life * rnd(0.7, 1)),
    ];
  }

  static List<SakugaEffect> lines(Offset o,
      {int n = 7, double dir = math.pi, double len = 46, double spread = 26, double life = 0.3}) {
    final rnd = SakugaFx.rnd;
    return [
      for (var i = 0; i < n; i++)
        _Line(o,
            dir: dir,
            off: rnd(-spread, spread),
            len: len * rnd(0.5, 1.3),
            delay: rnd(0, 0.25),
            width: rnd(1, 2.6),
            life: life),
    ];
  }

  static SakugaEffect burst(Offset o, {double r = 44, int spikes = 13, double life = 0.34}) =>
      _Burst(o, r: r, spikes: spikes, life: life);

  static SakugaEffect? sfx(String word, Offset o, {double size = 64, double rot = -0.14, double life = 0.95}) {
    final data = sakugaWords[word];
    if (data == null) return null;
    return _Sfx(word, data, o, size: size, rot: rot, life: life);
  }
}

class _Ticks extends SakugaEffect {
  final Offset o;
  final int n;
  final double r, len, dir, fan;

  _Ticks(this.o,
      {required this.n,
      required this.r,
      required this.len,
      required this.dir,
      required this.fan,
      required double life})
      : super(life);

  @override
  void paint(Canvas c, double k, double t) {
    final a = sakugaOut(sakugaClamp(k / 0.5)), b = sakugaIn(sakugaClamp((k - 0.4) / 0.6));
    final p = Path();
    for (var i = 0; i < n; i++) {
      final an = dir + (i - (n - 1) / 2) * fan;
      final r0 = r + len * b * 1.25, r1 = r + len * a * 1.25;
      final hw = 0.07 + 2.2 / (r1 + 8);
      if (r1 - r0 < 0.6) continue;
      p
        ..moveTo(o.dx + math.cos(an) * r0, o.dy + math.sin(an) * r0)
        ..lineTo(o.dx + math.cos(an - hw) * r1, o.dy + math.sin(an - hw) * r1)
        ..lineTo(o.dx + math.cos(an + hw) * r1, o.dy + math.sin(an + hw) * r1)
        ..close();
    }
    c.drawPath(p, _accentPaint);
  }
}

class _Lobe {
  final double a, d, r, ph, sp;
  const _Lobe(this.a, this.d, this.r, this.ph, this.sp);
}

class _Puff extends SakugaEffect {
  final Offset o;
  final double vx, vy;
  final bool arcs;
  final List<_Lobe> lobes;

  _Puff(this.o,
      {required int n,
      required double size,
      required this.vx,
      required this.vy,
      required double spread,
      required double life})
      : arcs = size > 6.5,
        lobes = [
          _Lobe(0, 0, size, 0, 1),
          for (var i = 0; i < n; i++)
            _Lobe(
              (i / n) * math.pi * 2 + SakugaFx.rnd(0.6),
              SakugaFx.rnd(0.25, 0.9) * size * spread,
              SakugaFx.rnd(0.55, 1) * size,
              SakugaFx.rnd(math.pi * 2),
              SakugaFx.rnd(0.6, 1.3),
            ),
        ],
        super(life);

  @override
  void paint(Canvas c, double k, double t) {
    final grow = sakugaBack(sakugaClamp(t / 0.22));
    final die = 1 - sakugaIn(sakugaClamp((k - 0.55) / 0.45));
    final px = o.dx + vx * sakugaOut(k) * life, py = o.dy + vy * sakugaOut(k) * life;
    final spreadK = 0.5 + sakugaOut(k) * 0.9;
    sakugaBlob(
      c,
      [
        for (final l in lobes)
          (
            px + math.cos(l.a + t * 0.9 * l.sp) * l.d * spreadK,
            py + math.sin(l.a + t * 0.9 * l.sp) * l.d * spreadK - sakugaOut(k) * 5 * l.sp,
            l.r * grow * die * (1 + math.sin(t * 9 + l.ph) * 0.05),
          ),
      ],
      lx: 0.5,
      arcs: arcs,
      deep: 1.5,
    );
  }
}

class _Shard extends SakugaEffect {
  final Offset o;
  final double a, v, s, spin, grav;
  final List<Offset> pts;

  _Shard(this.o,
      {required this.a,
      required this.v,
      required this.s,
      required this.spin,
      required this.grav,
      required double life})
      : pts = const [
          Offset(-1.4, 0.1),
          Offset(-0.6, -0.7),
          Offset(1.2, -0.45),
          Offset(1.5, 0.15),
          Offset(0.4, 0.75),
        ].map((q) => Offset(q.dx * SakugaFx.rnd(0.8, 1.2), q.dy * SakugaFx.rnd(0.8, 1.2))).toList(),
        super(life);

  @override
  void paint(Canvas c, double k, double t) {
    final px = o.dx + math.cos(a) * v * t;
    final py = o.dy + math.sin(a) * v * t + grav * t * t;
    final sc = s * (1 - sakugaIn(sakugaClamp((k - 0.6) / 0.4)));
    if (sc <= 0.05) return;
    c.translate(px, py);
    c.rotate(spin * t + a);
    final p = Path()..moveTo(pts[0].dx * sc, pts[0].dy * sc);
    for (var i = 1; i < pts.length; i++) {
      p.lineTo(pts[i].dx * sc, pts[i].dy * sc);
    }
    p.close();
    sakugaShape(c, p, 1.1, sc * 0.45);
    if (sc > 2.5) {
      c.drawLine(pts[1] * sc, pts[4] * sc, _stroke..strokeWidth = 0.9);
    }
  }
}

class _Line extends SakugaEffect {
  final Offset o;
  final double dir, off, len, delay, width;

  _Line(this.o,
      {required this.dir,
      required this.off,
      required this.len,
      required this.delay,
      required this.width,
      required double life})
      : super(life);

  @override
  void paint(Canvas c, double k, double t) {
    final kk = sakugaClamp((k - delay) / (1 - delay));
    if (kk <= 0) return;
    final a = sakugaOut(kk), b = sakugaIn(kk);
    final w = width * (1 - b);
    if (w < 0.05) return;
    final px = o.dx - math.sin(dir) * off, py = o.dy + math.cos(dir) * off;
    final cx = math.cos(dir), sy = math.sin(dir);
    c.drawLine(
      Offset(px + cx * len * b * 1.4, py + sy * len * b * 1.4),
      Offset(px + cx * len * (0.2 + a * 1.2), py + sy * len * (0.2 + a * 1.2)),
      _stroke..strokeWidth = w,
    );
  }
}

class _Pin {
  final double a, l, w;
  const _Pin(this.a, this.l, this.w);
}

/// The impact: magenta needles, a star in the shadow tone and a light star on
/// top; it leaves by its points thinning to nothing.
class _Burst extends SakugaEffect {
  final Offset o;
  final double r, rot;
  final List<double> j;
  final List<_Pin> pins;

  _Burst(this.o, {required this.r, required int spikes, required double life})
      : rot = SakugaFx.rnd(math.pi * 2),
        j = [for (var i = 0; i < spikes * 2; i++) i.isOdd ? SakugaFx.rnd(0.34, 0.5) : SakugaFx.rnd(0.75, 1.15)],
        pins = [
          for (var i = 0; i < 8; i++)
            _Pin(i / 8 * math.pi * 2 + SakugaFx.rnd(0.5), SakugaFx.rnd(1.25, 1.75), SakugaFx.rnd(0.03, 0.055)),
        ],
        super(life);

  Path _star(double radius, double turn, double inner) {
    final p = Path();
    for (var i = 0; i < j.length; i++) {
      final a = rot + turn + (i / j.length) * math.pi * 2;
      final rr = radius * (i.isOdd ? j[i] * inner : j[i]);
      final x = o.dx + math.cos(a) * rr, y = o.dy + math.sin(a) * rr;
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    return p..close();
  }

  @override
  void paint(Canvas c, double k, double t) {
    final big = r * sakugaOut(sakugaClamp(k / 0.3));
    final hollow = 1 + sakugaIn(sakugaClamp((k - 0.35) / 0.65)) * 1.3;
    final r0 = big * 0.6 * math.min(1.9, hollow);
    final needles = Path();
    for (final n in pins) {
      final l = big * n.l;
      if (l <= r0) continue;
      needles
        ..moveTo(o.dx + math.cos(n.a - n.w) * r0, o.dy + math.sin(n.a - n.w) * r0)
        ..lineTo(o.dx + math.cos(n.a) * l, o.dy + math.sin(n.a) * l)
        ..lineTo(o.dx + math.cos(n.a + n.w) * r0, o.dy + math.sin(n.a + n.w) * r0)
        ..close();
    }
    c.drawPath(needles, _accentPaint);
    final back = _star(big * 1.16, 0.19, hollow);
    c.drawPath(back, _shadePaint);
    c.drawPath(back, _stroke..strokeWidth = 1.2);
    sakugaShape(c, _star(big * 0.84, 0, hollow), 1.4, 3);
  }
}

/// A word lands a size too big and wobbles while it stays.
class _Sfx extends SakugaEffect {
  static final Map<String, ui.Picture> _baked = {};

  final SakugaWordData data;
  final ui.Picture picture;
  final Offset o;
  final double rot, k0;
  final SakugaSpring s = SakugaSpring(0.2, 520, 17)..to = 1;
  double _lastT = 0;

  _Sfx(String word, this.data, this.o, {required double size, required this.rot, required double life})
      : picture = _baked[word] ??= _bake(data),
        k0 = size / data.width,
        super(life);

  /// Outline and fill recorded once per word, so a word on screen costs one
  /// drawPicture a frame.
  static ui.Picture _bake(SakugaWordData data) {
    final path = sakugaParsePath(data.path);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final edge = data.width * 0.035;
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = edge * 2
        ..color = const Color(0xFFFFFFFF),
    );
    c.drawPath(path, Paint()..color = const Color(0xFFFFFFFF));
    c.drawPath(path, Paint()..color = SakugaFx.ink);
    return rec.endRecording();
  }

  @override
  void paint(Canvas c, double k, double t) {
    final sc = s.step(t - _lastT) * (1 - sakugaIn(sakugaClamp((k - 0.86) / 0.14))) * k0;
    _lastT = t;
    if (sc <= 0.001) return;
    c.translate(o.dx + math.sin(t * 31) * 0.8, o.dy + math.cos(t * 27) * 0.8);
    c.rotate(rot + math.sin(t * 6) * 0.03);
    c.scale(sc);
    c.translate(-data.width / 2, -data.height / 2);
    c.drawPicture(picture);
  }
}

/// Parses the absolute M/L/C/Z subset of SVG path data the traced words use.
Path sakugaParsePath(String d) {
  final path = Path();
  final tokens = RegExp(r'[MLCZ]|-?(?:\d+\.?\d*|\.\d+)').allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var cmd = 'M';
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final tok = tokens[i];
    if (RegExp(r'^[MLCZ]$').hasMatch(tok)) {
      i++;
      cmd = tok;
      if (cmd == 'Z') path.close();
      continue;
    }
    switch (cmd) {
      case 'M':
        path.moveTo(next(), next());
        cmd = 'L'; // extra pairs after M are lines
      case 'L':
        path.lineTo(next(), next());
      case 'C':
        path.cubicTo(next(), next(), next(), next(), next(), next());
      default:
        i++;
    }
  }
  return path;
}
