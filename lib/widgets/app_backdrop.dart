import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// The ambient canvas every screen sits on: a slate-indigo wash with a
/// magenta bloom top-right and a violet bloom bottom-left. Glass panels get
/// their colour from what is behind them, so this is what makes them read
/// as glass instead of grey boxes.
///
/// Wrap a whole [Scaffold] (with a transparent background) in it.
class AppBackdrop extends StatelessWidget {
  final Widget child;

  const AppBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(child: _BackdropPaint()),
        child,
      ],
    );
  }
}

class _BackdropPaint extends StatelessWidget {
  const _BackdropPaint();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.backgroundSoft, AppColors.background],
          stops: [0.0, 0.7],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(1.1, -1.05),
                radius: 1.05,
                colors: [Color(0x8C9B3C8F), Color(0x009B3C8F)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-1.2, 0.9),
                radius: 0.9,
                colors: [Color(0x475B4B9A), Color(0x005B4B9A)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
