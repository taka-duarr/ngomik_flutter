import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Liquid glass tab bar.
///
/// - The bar is frosted glass with a smooth notch carved under the active tab.
/// - A magenta glass bubble floats in the notch; while it travels it stretches
///   sideways and squashes, then settles with a small overshoot.
/// - The active icon rises into the bubble and its label fades in on the bar;
///   inactive tabs show the icon only.
class CustomBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav>
    with SingleTickerProviderStateMixin {
  static const List<_NavItemData> _items = [
    _NavItemData(icon: Icons.grid_view_rounded, label: 'Jelajah'),
    _NavItemData(icon: Icons.local_fire_department_rounded, label: 'Populer'),
    _NavItemData(icon: Icons.home_rounded, label: 'Beranda'),
    _NavItemData(icon: Icons.update_rounded, label: 'Update'),
    _NavItemData(icon: Icons.person_rounded, label: 'Profil'),
  ];

  // Geometry (logical px)
  static const double _barHeight = 64;
  static const double _barRadius = 22;
  static const double _sidePad = 10; // inside the bar
  static const double _bubble = 52;
  static const double _bubbleRise =
      24; // how far the bubble sits above the bar top
  static const double _notchWidth = 84;
  static const double _notchDepth = 34;
  static const double _iconRise =
      _bubbleRise + _barHeight / 2 - _bubble / 2 + 1;

  // Gentle overshoot so the bubble "lands" instead of stopping dead.
  static const Curve _travel = Cubic(0.34, 1.32, 0.64, 1.0);

  late final AnimationController _c;
  late double _from;
  late double _to;

  @override
  void initState() {
    super.initState();
    _from = _to = widget.currentIndex.toDouble();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..value = 1;
  }

  @override
  void didUpdateWidget(covariant CustomBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _from = _position; // start from wherever the bubble is right now
      _to = widget.currentIndex.toDouble();
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _position => lerpDouble(_from, _to, _travel.transform(_c.value))!;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion && _c.isAnimating) _c.value = 1;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: _barHeight + _bubbleRise,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final itemW = (width - _sidePad * 2) / _items.length;
              double centerOf(double pos) => _sidePad + itemW * (pos + 0.5);

              return AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final pos = _position;
                  final x = centerOf(pos);
                  // 0 → 1 → 0 across the trip; scaled by distance so short hops wobble less.
                  final travel =
                      math.sin(math.pi * _c.value.clamp(0.0, 1.0)) *
                      (0.35 + 0.65 * math.min(1.0, (_to - _from).abs() / 2));

                  final barPath = _LiquidBarPath.build(
                    size: Size(width, _barHeight),
                    radius: _barRadius,
                    notchX: x,
                    notchWidth: _notchWidth + 18 * travel,
                    notchDepth: _notchDepth - 4 * travel,
                  );

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 1. Bar: shadow, frosted fill, lit edge — all following the notch
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: _barHeight,
                        child: _GlassBar(path: barPath),
                      ),

                      // 2. Bubble
                      Positioned(
                        left: x - _bubble / 2,
                        top: 0,
                        width: _bubble,
                        height: _bubble,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.diagonal3Values(
                            1 + 0.28 * travel,
                            1 - 0.14 * travel,
                            1,
                          ),
                          child: const _Bubble(),
                        ),
                      ),

                      // 3. Icons + labels
                      Positioned(
                        left: _sidePad,
                        right: _sidePad,
                        bottom: 0,
                        height: _barHeight,
                        child: Row(
                          // Stretch so each item fills the bar height; the label is
                          // positioned against the bar's bottom, not the icon's box.
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: List.generate(_items.length, (i) {
                            // 1 when the bubble is exactly over this item, fading to 0 one slot away.
                            final active = (1 - (pos - i).abs()).clamp(
                              0.0,
                              1.0,
                            );
                            return Expanded(
                              child: _NavItem(
                                data: _items[i],
                                activeness: Curves.easeOut.transform(active),
                                selected: i == widget.currentIndex,
                                rise: _iconRise,
                                onTap: () => widget.onTap(i),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Bar ────────────────────────────────────────────────────────────────────

class _LiquidBarPath {
  /// Rounded rect minus a smooth "drop" shape centred on [notchX].
  static Path build({
    required Size size,
    required double radius,
    required double notchX,
    required double notchWidth,
    required double notchDepth,
  }) {
    final bar = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    final half = notchWidth / 2;
    final notch = Path()
      ..moveTo(notchX - half, -1)
      ..cubicTo(
        notchX - half * 0.55,
        -1,
        notchX - half * 0.62,
        notchDepth,
        notchX,
        notchDepth,
      )
      ..cubicTo(
        notchX + half * 0.62,
        notchDepth,
        notchX + half * 0.55,
        -1,
        notchX + half,
        -1,
      )
      ..close();

    return Path.combine(PathOperation.difference, bar, notch);
  }
}

class _GlassBar extends StatelessWidget {
  final Path path;

  const _GlassBar({required this.path});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _BarShadowPainter(path)),
        ClipPath(
          clipper: _PathClipper(path),
          child: BackdropFilter.grouped(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB82A2F4E), Color(0xD91C2038)],
                ),
              ),
            ),
          ),
        ),
        CustomPaint(painter: _BarEdgePainter(path)),
      ],
    );
  }
}

class _PathClipper extends CustomClipper<Path> {
  final Path path;
  _PathClipper(this.path);

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(covariant _PathClipper old) => old.path != path;
}

class _BarShadowPainter extends CustomPainter {
  final Path path;
  _BarShadowPainter(this.path);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawShadow(
      path.shift(const Offset(0, 4)),
      const Color(0xFF0E1022),
      14,
      true,
    );
  }

  @override
  bool shouldRepaint(covariant _BarShadowPainter old) => old.path != path;
}

class _BarEdgePainter extends CustomPainter {
  final Path path;
  _BarEdgePainter(this.path);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x47FFFFFF), Color(0x0AFFFFFF)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _BarEdgePainter old) => old.path != path;
}

// ── Bubble ─────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  const _Bubble();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xE6F0469F), Color(0xE6C21A78)],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          // Specular highlight on the upper-left
          child: const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.45, -0.55),
                radius: 0.75,
                colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Items ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final _NavItemData data;
  final double activeness; // 0..1
  final bool selected;
  final double rise;
  final VoidCallback onTap;

  const _NavItem({
    required this.data,
    required this.activeness,
    required this.selected,
    required this.rise,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = Color.lerp(
      AppColors.textMuted,
      Colors.white,
      activeness,
    )!;

    return Semantics(
      button: true,
      selected: selected,
      label: data.label,
      excludeSemantics: true,
      child: Tooltip(
        message: data.label,
        triggerMode: TooltipTriggerMode.longPress,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Icon: sits mid-bar, rises into the bubble as it becomes active
              Transform.translate(
                offset: Offset(0, -rise * activeness),
                child: Icon(
                  data.icon,
                  size: 24 + 1 * activeness,
                  color: iconColor,
                ),
              ),
              // Label: fades/slides in at the bottom of the bar for the active tab
              Positioned(
                bottom: 9,
                child: Opacity(
                  opacity: activeness,
                  child: Transform.translate(
                    offset: Offset(0, 6 * (1 - activeness)),
                    child: Text(
                      data.label,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData({required this.icon, required this.label});
}
