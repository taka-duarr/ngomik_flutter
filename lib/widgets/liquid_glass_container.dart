import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'bouncing_tap.dart';

/// Glass surface used across the app.
///
/// By default it is a "cheap" glass: a translucent navy fill, a faint sheen
/// and a lit hairline edge — no blur, so it is safe inside scrolling lists.
///
/// Set [frosted] to `true` for a real backdrop blur. Reserve it for surfaces
/// that sit over imagery or scrolling content (nav bar, pinned buttons,
/// sheets, the panel over the detail poster): it costs a save-layer per frame.
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  /// Blur sigma used when [frosted] is true.
  final double blur;
  final bool frosted;
  final Color? color;

  /// Solid border override. When null, a lit gradient hairline is painted.
  final BoxBorder? border;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final double scaleFactor;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppRadius.lg,
    this.blur = 18.0,
    this.frosted = false,
    this.color,
    this.border,
    this.gradient,
    this.boxShadow,
    this.onTap,
    this.width,
    this.height,
    this.scaleFactor = 0.97,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? (frosted ? AppColors.glassFill : AppColors.glassFillStrong),
        gradient: gradient,
        borderRadius: radius,
        border: border,
      ),
      // Sheen: a faint top-left light so the panel reads as a pane, not a box.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: AppColors.glassSheenGradient,
        ),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );

    if (border == null) {
      surface = CustomPaint(
        foregroundPainter: GlassEdgePainter(radius: borderRadius),
        child: surface,
      );
    }

    if (frosted) {
      surface = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: surface,
        ),
      );
    }

    Widget content = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: boxShadow ??
            const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
      ),
      child: surface,
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null) {
      return BouncingTap(scaleFactor: scaleFactor, onTap: onTap, child: content);
    }

    return content;
  }
}

/// Paints a 1px rounded-rect stroke that is brighter on the top-left edge,
/// mimicking light catching the rim of a glass pane.
class GlassEdgePainter extends CustomPainter {
  final double radius;
  final Gradient gradient;
  final double strokeWidth;

  const GlassEdgePainter({
    required this.radius,
    this.gradient = AppColors.glassEdgeGradient,
    this.strokeWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant GlassEdgePainter old) =>
      old.radius != radius || old.gradient != gradient || old.strokeWidth != strokeWidth;
}
