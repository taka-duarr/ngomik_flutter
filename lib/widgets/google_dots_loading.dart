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
  static const List<Color> googleColors = [
    Color(0xFFEA4335), // Google Red
    Color(0xFFFBBC05), // Google Yellow
    Color(0xFF34A853), // Google Green
    Color(0xFF4285F4), // Google Blue
  ];

  // App palette: magenta → pink → lavender → mist
  static const List<Color> neonColors = [
    Color(0xFFE2288E),
    Color(0xFFFF6CB8),
    Color(0xFFB7A9FF),
    Color(0xFFC9CCE2),
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
    final colors = widget.colors ?? GoogleDotsLoading.neonColors;

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

            final dotColor = colors[index % colors.length];

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
                      color: dotColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        // Inner bright glow
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.85),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                        // Outer ambient neon aura
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.45),
                          blurRadius: 14,
                          spreadRadius: 2,
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
