import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds (Deep Dark OLED Nebula)
  static const Color background = Color(0xFF07090E);
  static const Color surface = Color(0xFF0D111A);
  static const Color card = Color(0xFF131826);
  static const Color cardLighter = Color(0xFF1B2237);

  // Neon Brand Accents
  static const Color primary = Color(0xFFFF2E63); // Vibrant Neon Crimson / Hot Pink
  static const Color primaryDark = Color(0xFFD61A4E);
  static const Color primaryLight = Color(0xFFFF5E85);
  static const Color primaryGlow = Color(0x66FF2E63);

  // Neon Accents
  static const Color cyan = Color(0xFF00E5FF); // Electric Cyan
  static const Color cyanGlow = Color(0x4D00E5FF);
  static const Color emerald = Color(0xFF00E676); // Electric Emerald
  static const Color emeraldGlow = Color(0x4D00E676);
  static const Color amber = Color(0xFFFFB800); // Neon Gold
  static const Color amberGlow = Color(0x4DFFB800);
  static const Color purple = Color(0xFFB026FF); // Neon Violet

  // Typography Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF7E8EA4);
  static const Color textDisabled = Color(0xFF505F75);

  // Borders & Glows
  static const Color border = Color(0x1FFFFFFF);
  static const Color borderSubtle = Color(0x0FFFFFFF);
  static const Color borderGlow = Color(0x4DFF2E63);

  // Floating Nav Colors
  static const Color navBackground = Color(0xEB0D121F);
  static const Color navBorder = Color(0x2EFFFFFF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF2E63), Color(0xFFD61A4E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient neonPinkGradient = LinearGradient(
    colors: [Color(0xFFFF3366), Color(0xFFE11D48)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroOverlayGradient = LinearGradient(
    colors: [
      Colors.transparent,
      Color(0x8007090E),
      Color(0xFF07090E),
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [
      Color(0x26FF2E63),
      Color(0x050D111A),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
