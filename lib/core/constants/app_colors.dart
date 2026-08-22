import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds (Dark OLED Nebula)
  static const Color background = Color(0xFF0B0F19);
  static const Color surface = Color(0xFF111827);
  static const Color card = Color(0xFF1E293B);
  static const Color cardLighter = Color(0xFF273549);

  // Brand Accent Colors
  static const Color primary = Color(0xFFF43F5E); // Crimson Rose
  static const Color primaryDark = Color(0xFFE11D48);
  static const Color primaryLight = Color(0xFFFB7185);
  static const Color primaryGlow = Color(0x4DF43F5E);

  // Secondary Accents
  static const Color cyan = Color(0xFF38BDF8);
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color purple = Color(0xFFA855F7);

  // Typography Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDisabled = Color(0xFF64748B);

  // Borders & Dividers
  static const Color border = Color(0x1AFFFFFF);
  static const Color borderGlow = Color(0x33F43F5E);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFF43F5E), Color(0xFFBE123C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroOverlayGradient = LinearGradient(
    colors: [
      Colors.transparent,
      Color(0x800B0F19),
      Color(0xFF0B0F19),
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [
      Color(0x1AF43F5E),
      Color(0x050F172A),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
