import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

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

class _CustomBottomNavState extends State<CustomBottomNav> {
  final List<_NavItemData> _items = const [
    _NavItemData(icon: Icons.home_rounded, label: 'Home'),
    _NavItemData(icon: Icons.schedule_rounded, label: 'Riwayat'),
    _NavItemData(icon: Icons.search_rounded, label: 'Cari'),
    _NavItemData(icon: Icons.bookmark_rounded, label: 'Bookmark'),
    _NavItemData(icon: Icons.settings_rounded, label: 'Setting'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth - 32; // 16 margin on left & right
        final itemWidth = totalWidth / _items.length;
        final targetX = (widget.currentIndex + 0.5) * itemWidth;

        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          tween: Tween<double>(end: targetX),
          builder: (context, currentX, child) {
            return Container(
              height: 92,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Liquid Navigation Bar Base with Cutout Notch
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: CustomPaint(
                      size: Size(totalWidth, 64),
                      painter: _LiquidNavPainter(
                        activeX: currentX,
                        backgroundColor: const Color(0xF20D121F), // Dark sleek void
                        borderColor: Colors.white.withValues(alpha: 0.14),
                        shadowColor: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                  ),

                  // 2. Elevated Floating Circle Bubble (Liquid Indicator)
                  Positioned(
                    left: currentX - 26,
                    bottom: 34,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(255, 255, 0, 0).withValues(alpha: 0.7),
                            blurRadius: 20,
                            spreadRadius: 3,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: anim,
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: Icon(
                            _items[widget.currentIndex].icon,
                            key: ValueKey<int>(widget.currentIndex),
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. Navigation Bar Icons & Text Labels
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 64,
                    child: Row(
                      children: List.generate(_items.length, (index) {
                        final isSelected = widget.currentIndex == index;
                        final item = _items[index];

                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onTap(index),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // When active, the icon is in the elevated bubble
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: isSelected ? 0.0 : 1.0,
                                  child: Icon(
                                    item.icon,
                                    size: 22,
                                    color: const Color(0xFF7E8EA4),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontSize: isSelected ? 10.5 : 10,
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                                    color: isSelected ? const Color.fromARGB(255, 253, 0, 0) : const Color(0xFF64748B),
                                    letterSpacing: isSelected ? 0.2 : 0,
                                  ),
                                  child: Text(item.label),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData({required this.icon, required this.label});
}

class _LiquidNavPainter extends CustomPainter {
  final double activeX;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;

  _LiquidNavPainter({
    required this.activeX,
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const r = 24.0; // Corner radius
    const notchWidth = 78.0;
    const notchDepth = 30.0;

    final path = Path();
    path.moveTo(r, 0);

    // Left shoulder approaching notch
    path.lineTo(activeX - notchWidth / 2, 0);

    // Smooth fluid Bezier concave curve
    path.cubicTo(
      activeX - notchWidth * 0.32,
      0,
      activeX - notchWidth * 0.30,
      notchDepth,
      activeX,
      notchDepth,
    );

    // Right shoulder leaving notch
    path.cubicTo(
      activeX + notchWidth * 0.30,
      notchDepth,
      activeX + notchWidth * 0.32,
      0,
      activeX + notchWidth / 2,
      0,
    );

    // Top right
    path.lineTo(w - r, 0);
    path.arcToPoint(Offset(w, r), radius: const Radius.circular(r));

    // Bottom right
    path.lineTo(w, h - r);
    path.arcToPoint(Offset(w - r, h), radius: const Radius.circular(r));

    // Bottom left
    path.lineTo(r, h);
    path.arcToPoint(Offset(0, h - r), radius: const Radius.circular(r));

    // Top left
    path.lineTo(0, r);
    path.arcToPoint(Offset(r, 0), radius: const Radius.circular(r));
    path.close();

    // Draw Shadow
    canvas.drawShadow(path, shadowColor, 12, true);

    // Fill Background
    final paintFill = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paintFill);

    // Stroke Border
    final paintBorder = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, paintBorder);
  }

  @override
  bool shouldRepaint(covariant _LiquidNavPainter oldDelegate) {
    return oldDelegate.activeX != activeX ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor;
  }
}
