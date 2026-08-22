import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String timeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      DateTime date;
      final millis = int.tryParse(dateStr);
      if (millis != null) {
        date = millis < 10000000000
            ? DateTime.fromMillisecondsSinceEpoch(millis * 1000).toLocal()
            : DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
      } else {
        date = DateTime.parse(dateStr).toLocal();
      }

      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inSeconds < 60) {
        return 'Baru saja';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes} mnt lalu';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} jam lalu';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} hari lalu';
      } else if (diff.inDays < 30) {
        final weeks = (diff.inDays / 7).floor();
        return '$weeks minggu lalu';
      } else if (diff.inDays < 365) {
        final months = (diff.inDays / 30).floor();
        return '$months bulan lalu';
      } else {
        final years = (diff.inDays / 365).floor();
        return years > 0 ? '$years tahun lalu' : DateFormat('dd MMM yyyy').format(date);
      }
    } catch (_) {
      return dateStr;
    }
  }

  static String formatShortDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      DateTime date;
      final millis = int.tryParse(dateStr);
      if (millis != null) {
        date = millis < 10000000000
            ? DateTime.fromMillisecondsSinceEpoch(millis * 1000).toLocal()
            : DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
      } else {
        date = DateTime.parse(dateStr).toLocal();
      }
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
