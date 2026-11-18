import 'package:flutter/material.dart';

/// Palette derived from the "slate indigo + magenta" reference:
/// a muted blue-violet canvas, a single hot-magenta accent, and
/// translucent navy glass surfaces with hairline white edges.
class AppColors {
  AppColors._();

  // ── Canvas ────────────────────────────────────────────────────────────
  static const Color background = Color(0xFF242942); // deepest canvas
  static const Color backgroundSoft = Color(0xFF39416A); // lifted slate
  static const Color surface = Color(0xFF1F2339); // sheets, dialogs
  static const Color card = Color(0xFF2A2F4C); // solid card fallback
  static const Color cardLighter = Color(0xFF353B5E);

  // Ambient glows painted behind glass
  static const Color glowMagenta = Color(0xFF9B3C8F);
  static const Color glowViolet = Color(0xFF5B4B9A);

  // ── Accent (single brand hue) ─────────────────────────────────────────
  static const Color primary = Color(0xFFE2288E);
  static const Color primaryDark = Color(0xFFB5186E);
  static const Color primaryLight = Color(0xFFFF6CB8);
  static const Color primaryGlow = Color(0x66E2288E);
  static const Color primarySoft = Color(0x29E2288E); // tinted fills

  // Secondary accent: a quiet lavender that sits inside the palette
  static const Color accent = Color(0xFFB7A9FF);
  static const Color accentGlow = Color(0x33B7A9FF);

  // Semantic
  static const Color emerald = Color(0xFF4CD9A0); // read / success
  static const Color emeraldGlow = Color(0x334CD9A0);
  static const Color amber = Color(0xFFFFC857); // rating
  static const Color amberGlow = Color(0x33FFC857);
  static const Color danger = Color(0xFFFF5C7A);
  static const Color purple = Color(0xFF8B6CF0);

  // ── Typography ────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F6FC);
  static const Color textSecondary = Color(0xFFC9CCE2);
  static const Color textMuted = Color(0xFF959BBD);
  static const Color textDisabled = Color(0xFF6A7096);

  // ── Glass ─────────────────────────────────────────────────────────────
  static const Color glassFill = Color(0x8C1C2038); // navy @ 55%
  static const Color glassFillStrong = Color(0xBF1C2038); // navy @ 75%
  static const Color glassHighlight = Color(0x14FFFFFF); // inner sheen
  static const Color glassEdge = Color(0x2EFFFFFF); // lit edge
  static const Color glassEdgeFaint = Color(0x0AFFFFFF); // shadowed edge

  // ── Borders ───────────────────────────────────────────────────────────
  static const Color border = Color(0x1FFFFFFF);
  static const Color borderSubtle = Color(0x0FFFFFFF);
  static const Color borderGlow = Color(0x66E2288E);
  static const Color borderAccent = Color(0x59E2288E); // pink outline tiles

  // Nav
  static const Color navBackground = Color(0x991C2038);
  static const Color navBorder = Color(0x2EFFFFFF);

  // ── Gradients (kept subtle on purpose) ────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFEA3896), Color(0xFFCC1F80)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Kept for older call sites; now a flat-looking magenta.
  static const LinearGradient neonPinkGradient = primaryGradient;

  static const LinearGradient glassEdgeGradient = LinearGradient(
    colors: [glassEdge, glassEdgeFaint],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassSheenGradient = LinearGradient(
    colors: [Color(0x1AFFFFFF), Color(0x05FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroOverlayGradient = LinearGradient(
    colors: [Colors.transparent, Color(0x80242942), Color(0xF0242942)],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Gradient used over cover art so text stays legible.
  static const LinearGradient coverScrim = LinearGradient(
    colors: [Color(0x00191C30), Color(0x99191C30), Color(0xF2191C30)],
    stops: [0.25, 0.6, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [Color(0x33E2288E), Color(0x051F2339)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Corner radius scale. Pick from here instead of inventing values.
class AppRadius {
  AppRadius._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;
}
