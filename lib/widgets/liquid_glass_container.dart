import 'package:flutter/material.dart';
import 'bouncing_tap.dart';

/// Ultra-performant Glassmorphic Container with zero BackdropFilter CPU/GPU overhead.
/// Uses layered semi-transparent gradients, crisp inner borders, and soft shadows
/// to create a stunning glass aesthetic that runs at a solid 60-120 FPS even on budget devices.
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur; // Kept for backwards compatibility
  final Color? color;
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
    this.borderRadius = 20.0,
    this.blur = 0.0,
    this.color,
    this.border,
    this.gradient,
    this.boxShadow,
    this.onTap,
    this.width,
    this.height,
    this.scaleFactor = 0.96,
  });

  @override
  Widget build(BuildContext context) {
    final boxDecoration = BoxDecoration(
      color: color ?? const Color(0xFF0F1424).withValues(alpha: 0.85),
      gradient: gradient ??
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E2640).withValues(alpha: 0.75),
              const Color(0xFF0D1220).withValues(alpha: 0.85),
            ],
          ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: border ??
          Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.0,
          ),
      boxShadow: boxShadow ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
    );

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: boxDecoration,
      child: child,
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null) {
      return BouncingTap(
        scaleFactor: scaleFactor,
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
