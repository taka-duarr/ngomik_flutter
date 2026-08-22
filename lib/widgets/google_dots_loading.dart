import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class GoogleDotsLoading extends StatefulWidget {
  final double dotSize;
  final double spacing;
  final double jumpHeight;
  final List<Color>? colors;

  const GoogleDotsLoading({
    super.key,
    this.dotSize = 12.0,
    this.spacing = 8.0,
    this.jumpHeight = 16.0,
    this.colors,
  });

  // Preset Google colors matching the screenshot:
  // #EA4335 (Red), #FBBC05 (Yellow), #34A853 (Green), #4285F4 (Blue)
  static const List<Color> googleColors = [
    Color(0xFFEA4335), // Red
    Color(0xFFFBBC05), // Yellow
    Color(0xFF34A853), // Green
    Color(0xFF4285F4), // Blue
  ];

  // Preset Neon colors matching the app theme
  static const List<Color> neonColors = [
    Color(0xFFFF2E63), // Neon Pink
    Color(0xFFFFB800), // Neon Yellow/Gold
    Color(0xFF10B981), // Neon Emerald
    Color(0xFF00F0FF), // Neon Cyan
  ];

  @override
  State<GoogleDotsLoading> createState() => _GoogleDotsLoadingState();
}

class _GoogleDotsLoadingState extends State<GoogleDotsLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? GoogleDotsLoading.googleColors;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            // Staggered sine wave phase delay for each dot
            final delay = index * 0.16;
            final progress = (_controller.value - delay) % 1.0;

            // Smooth jump trajectory with squash and stretch
            double offsetY = 0.0;
            double scaleX = 1.0;
            double scaleY = 1.0;

            if (progress >= 0.0 && progress <= 0.6) {
              // Jump arc (0 to pi sine curve)
              final jumpProgress = progress / 0.6;
              final sineVal = math.sin(jumpProgress * math.pi);
              offsetY = -sineVal * widget.jumpHeight;

              // Stretch slightly while moving fast
              scaleY = 1.0 + (sineVal * 0.15);
              scaleX = 1.0 - (sineVal * 0.1);
            } else if (progress > 0.6 && progress <= 0.8) {
              // Landing squash
              final landProgress = (progress - 0.6) / 0.2;
              final squash = math.sin(landProgress * math.pi);
              scaleX = 1.0 + (squash * 0.2);
              scaleY = 1.0 - (squash * 0.15);
            }

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
              child: Transform.translate(
                offset: Offset(0, offsetY),
                child: Transform.scale(
                  scaleX: scaleX,
                  scaleY: scaleY,
                  child: Container(
                    width: widget.dotSize,
                    height: widget.dotSize,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors[index % colors.length].withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class AppLoadingBox extends StatelessWidget {
  final double height;
  final String? label;
  final List<Color>? colors;

  const AppLoadingBox({
    super.key,
    this.height = 120,
    this.label,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GoogleDotsLoading(colors: colors),
            if (label != null) ...[
              const SizedBox(height: 12),
              Text(
                label!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
