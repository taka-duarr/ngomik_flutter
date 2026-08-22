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

  static bool isShinigamiToken(String? text) {
    if (text == null) return false;
    final trimmed = text.trim();
    return trimmed.startsWith('v4.public.') || trimmed.startsWith('Bearer v4.public.');
  }

  static String cleanToken(String text) {
    final trimmed = text.trim();
    if (trimmed.toLowerCase().startsWith('bearer ')) {
      return trimmed.substring(7).trim();
    }
    return trimmed;
  }
}
