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
    final clean = cleanToken(trimmed);
    return clean.startsWith('v4.public.') ||
        clean.startsWith('eyJ') ||
        (clean.split('.').length == 3 && clean.length > 30) ||
        (clean.length > 30 && RegExp(r'^[A-Za-z0-9_\-\.]+$').hasMatch(clean));
  }

  static String cleanToken(String text) {
    final trimmed = text.trim();
    if (trimmed.toLowerCase().startsWith('bearer ')) {
      return trimmed.substring(7).trim();
    }
    return trimmed;
  }

  /// Decode JWT payload (part 1 of a 3-part JWT)
  static Map<String, dynamic>? parseJwtPayload(String jwt) {
    try {
      final clean = cleanToken(jwt);
      final parts = clean.split('.');
      if (parts.length < 2) return null;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Get expiration timestamp in seconds (Unix epoch) from JWT
  static int? getJwtExpiration(String jwt) {
    final payload = parseJwtPayload(jwt);
    if (payload != null && payload['exp'] != null) {
      return int.tryParse(payload['exp'].toString());
    }
    return null;
  }

  // --- Supabase Cookie (lasts ~60 days) ---

  static bool isSupabaseCookie(String? text) {
    if (text == null) return false;
    final trimmed = text.trim();
    return trimmed.contains('sb-kratos-auth-token') ||
        trimmed.startsWith('base64-eyJ') ||
        trimmed.startsWith('eyJ');
  }

  /// Parse Supabase session from:
  /// 1. Full document.cookie string (.0 + .1 combined)
  /// 2. Just the .0 value: "base64-eyJ..."
  /// 3. Raw base64 starting with "eyJ"
  static Map<String, dynamic>? parseSupabaseCookie(String input) {
    try {
      final trimmed = input.trim();

      // Strategy 1: full document.cookie string
      if (trimmed.contains('sb-kratos-auth-token')) {
        final result = _extractAndCombineCookieParts(trimmed);
        if (result != null) return result;
      }

      // Strategy 2: just "base64-eyJ..." value
      if (trimmed.startsWith('base64-')) {
        return _decodeBase64Json(trimmed.substring(7));
      }

      // Strategy 3: raw base64
      if (trimmed.startsWith('eyJ')) {
        return _decodeBase64Json(trimmed);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _extractAndCombineCookieParts(
      String cookieStr) {
    try {
      final parts = cookieStr.split(RegExp(r';\s*'));
      String? part0;
      String? part1;

      for (final part in parts) {
        final eqIdx = part.indexOf('=');
        if (eqIdx == -1) continue;
        final key = part.substring(0, eqIdx).trim();
        final value = part.substring(eqIdx + 1).trim();

        if (key.contains('auth-token') && key.endsWith('.0')) {
          part0 = value.startsWith('base64-') ? value.substring(7) : value;
        } else if (key.contains('auth-token') && key.endsWith('.1')) {
          part1 = value.startsWith('base64-') ? value.substring(7) : value;
        }
      }

      if (part0 == null) return null;

      // Combine .0 + .1 then decode
      final combined = part0 + (part1 ?? '');
      return _decodeBase64Json(combined);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _decodeBase64Json(String b64Raw) {
    // Try multiple decode strategies
    final strategies = [
      () => _tryDecode(b64Raw), // as-is
      () => _tryDecode(b64Raw.replaceAll('-', '+').replaceAll('_', '/')), // url-safe → standard
      () => _tryDecode(b64Raw.replaceAll('+', '-').replaceAll('/', '_')), // standard → url-safe
    ];

    for (final strategy in strategies) {
      try {
        final result = strategy();
        if (result != null) return result;
      } catch (_) {}
    }
    return null;
  }

  static Map<String, dynamic>? _tryDecode(String b64) {
    try {
      // Use base64 (standard) with manual padding
      final padded = _addPadding(b64.replaceAll('-', '+').replaceAll('_', '/'));
      final bytes = base64.decode(padded);
      final decoded = utf8.decode(bytes);
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      if (json.containsKey('access_token') &&
          json.containsKey('refresh_token')) {
        return json;
      }
      return null;
    } catch (_) {
      // Try base64Url codec
      try {
        final normalized = base64Url.normalize(b64);
        final bytes = base64Url.decode(normalized);
        final decoded = utf8.decode(bytes);
        final json = jsonDecode(decoded) as Map<String, dynamic>;
        if (json.containsKey('access_token') &&
            json.containsKey('refresh_token')) {
          return json;
        }
      } catch (_) {}
      return null;
    }
  }

  static String _addPadding(String s) {
    final remainder = s.length % 4;
    if (remainder == 0) return s;
    if (remainder == 1) {
      // Invalid - try adding 3 anyway
      return '$s===';
    }
    return s + ('=' * (4 - remainder));
  }
}
