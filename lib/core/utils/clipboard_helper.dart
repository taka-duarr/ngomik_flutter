import 'dart:convert';
import 'package:flutter/services.dart';

class ClipboardHelper {
  ClipboardHelper._();

  static Future<void> copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<String?> getClipboardText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  // --- Bearer Token ---
  static bool isShinigamiToken(String? text) {
    if (text == null) return false;
    final trimmed = text.trim();
    return trimmed.startsWith('v4.public.') ||
        trimmed.startsWith('Bearer v4.public.');
  }

  static String cleanToken(String text) {
    final trimmed = text.trim();
    if (trimmed.toLowerCase().startsWith('bearer ')) {
      return trimmed.substring(7).trim();
    }
    return trimmed;
  }

  // --- Supabase Cookie (lasts ~60 days) ---

  /// Detects if text is a Supabase session cookie or document.cookie output
  static bool isSupabaseCookie(String? text) {
    if (text == null) return false;
    final trimmed = text.trim();
    return trimmed.contains('sb-kratos-auth-token') ||
        (trimmed.startsWith('base64-eyJ') || trimmed.startsWith('eyJ'));
  }

  /// Parse a Supabase session from various possible formats:
  /// 1. Full document.cookie string (contains sb-kratos-auth-token.0 AND .1)
  /// 2. Just the .0 cookie value: "base64-eyJ..."
  /// 3. Cookie header line: "sb-kratos-auth-token.0=base64-eyJ..."
  static Map<String, dynamic>? parseSupabaseCookie(String input) {
    try {
      final trimmed = input.trim();

      // Strategy 1: Full document.cookie string — extract .0 AND .1, combine
      if (trimmed.contains('sb-kratos-auth-token')) {
        final combined = _extractAndCombineCookieParts(trimmed);
        if (combined != null) return combined;
      }

      // Strategy 2: Just the raw value of .0 starting with "base64-"
      if (trimmed.startsWith('base64-')) {
        final b64 = trimmed.substring(7);
        return _decodeBase64Json(b64);
      }

      // Strategy 3: Raw base64 starting with "eyJ" (value without prefix)
      if (trimmed.startsWith('eyJ')) {
        return _decodeBase64Json(trimmed);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Extract, combine .0 + .1 parts, and decode
  static Map<String, dynamic>? _extractAndCombineCookieParts(String cookieStr) {
    try {
      // Split by "; " or ";" to get individual cookie parts
      final parts = cookieStr.split(RegExp(r';\s*'));

      String? part0;
      String? part1;

      for (final part in parts) {
        final eqIdx = part.indexOf('=');
        if (eqIdx == -1) continue;
        final key = part.substring(0, eqIdx).trim();
        final value = part.substring(eqIdx + 1).trim();

        if (key.endsWith('.0') && key.contains('sb-') && key.contains('auth-token')) {
          part0 = value;
        } else if (key.endsWith('.1') && key.contains('sb-') && key.contains('auth-token')) {
          part1 = value;
        }
      }

      if (part0 == null) return null;

      // .0 value: "base64-eyJ..."
      String base64Part0 = part0.startsWith('base64-')
          ? part0.substring(7)
          : part0;

      // .1 value: might just be raw continuation base64 (no "base64-" prefix)
      String? base64Part1 = part1 != null
          ? (part1.startsWith('base64-') ? part1.substring(7) : part1)
          : null;

      // Combine the two base64 chunks
      final combined = base64Part0 + (base64Part1 ?? '');
      return _decodeBase64Json(combined);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _decodeBase64Json(String b64) {
    try {
      final padded = _fixBase64Padding(b64);
      final decoded = utf8.decode(base64Decode(padded));
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      if (!json.containsKey('access_token') ||
          !json.containsKey('refresh_token')) {
        return null;
      }
      return json;
    } catch (_) {
      return null;
    }
  }

  static String _fixBase64Padding(String s) {
    // Standard base64 (not URL-safe)
    final cleaned = s.replaceAll('-', '+').replaceAll('_', '/');
    final remainder = cleaned.length % 4;
    if (remainder == 0) return cleaned;
    return cleaned + ('=' * (4 - remainder));
  }
}
