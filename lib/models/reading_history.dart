import '../core/constants/api_endpoints.dart';

class ReadingHistoryItem {
  final String mangaId;
  final String mangaTitle;
  final String coverUrl;
  final String chapterId;
  final String chapterNumber;
  final String? chapterTitle;
  final double? userRate;
  final DateTime readAt;

  const ReadingHistoryItem({
    required this.mangaId,
    required this.mangaTitle,
    required this.coverUrl,
    required this.chapterId,
    required this.chapterNumber,
    this.chapterTitle,
    this.userRate,
    required this.readAt,
  });

  factory ReadingHistoryItem.fromJson(Map<String, dynamic> json) {
    final mangaObj = json['manga'] is Map<String, dynamic> ? json['manga'] as Map<String, dynamic> : null;
    final chObj = (json['chapter'] is Map<String, dynamic>
        ? json['chapter']
        : json['last_chapter'] is Map<String, dynamic>
            ? json['last_chapter']
            : json['last_read_chapter'] is Map<String, dynamic>
                ? json['last_read_chapter']
                : json['latest_chapter'] is Map<String, dynamic>
                    ? json['latest_chapter']
                    : null) as Map<String, dynamic>?;

    final mangaId = (json['manga_id'] ?? mangaObj?['id'] ?? mangaObj?['manga_id'] ?? json['id'] ?? '').toString();
    final mangaTitle = (mangaObj?['title'] ?? json['manga_title'] ?? json['title'] ?? mangaObj?['name'] ?? 'Komik').toString();

    String cover = '';
    for (final k in ['cover_portrait_url', 'cover_image_url', 'cover_landscape_url', 'thumbnail_image_url', 'cover_url', 'cover', 'thumbnail', 'image']) {
      final val = json[k]?.toString() ?? mangaObj?[k]?.toString();
      if (val != null && val.isNotEmpty && val != 'null' && val != 'undefined') {
        if (val.startsWith('//')) {
          cover = 'https:$val';
        } else if (val.startsWith('/')) {
          cover = '${ApiEndpoints.assetsBaseUrl}$val';
        } else if (!val.startsWith('http://') && !val.startsWith('https://')) {
          cover = '${ApiEndpoints.assetsBaseUrl}/$val';
        } else {
          cover = val;
        }
        break;
      }
    }

    final chapterId = (json['chapter_id'] ??
            json['last_chapter_id'] ??
            json['last_read_chapter_id'] ??
            chObj?['id'] ??
            chObj?['chapter_id'] ??
            '')
        .toString();

    // Extract numbers safely
    String extractNum(dynamic val) {
      if (val == null) return '';
      final s = val.toString().trim();
      if (s.isEmpty || s == 'null') return '';
      final match = RegExp(r'\d+(\.\d+)?').firstMatch(s);
      return match != null ? match.group(0)! : s;
    }

    String chapterNumber = '';
    for (final k in [
      'chapter_number',
      'last_chapter_number',
      'last_read_chapter_number',
      'read_chapter_number',
      'latest_chapter_number',
      'chapter_num',
      'number',
      'chapter',
      'ep',
      'episode'
    ]) {
      if (json[k] != null && json[k].toString() != '0') {
        chapterNumber = extractNum(json[k]);
        if (chapterNumber.isNotEmpty && chapterNumber != '0') break;
      }
      if (chObj != null && chObj[k] != null && chObj[k].toString() != '0') {
        chapterNumber = extractNum(chObj[k]);
        if (chapterNumber.isNotEmpty && chapterNumber != '0') break;
      }
    }

    if (chapterNumber.isEmpty || chapterNumber == '0') {
      if (chObj?['name'] != null) {
        chapterNumber = extractNum(chObj!['name']);
      } else if (chObj?['title'] != null) {
        chapterNumber = extractNum(chObj!['title']);
      } else if (json['chapter_title'] != null) {
        chapterNumber = extractNum(json['chapter_title']);
      } else if (mangaObj?['latest_chapter_number'] != null) {
        chapterNumber = extractNum(mangaObj!['latest_chapter_number']);
      }
    }

    if (chapterNumber.isEmpty || chapterNumber == '0') {
      chapterNumber = '1';
    }

    final chapterTitle = json['chapter_title']?.toString() ?? chObj?['title']?.toString() ?? chObj?['name']?.toString();
    final userRate = json['user_rate'] != null ? double.tryParse(json['user_rate'].toString()) : null;

    DateTime readAt = DateTime.now();
    final dateStr = json['updated_at'] ?? json['read_at'] ?? json['created_at'];
    if (dateStr != null) {
      readAt = DateTime.tryParse(dateStr.toString()) ?? DateTime.now();
    }

    return ReadingHistoryItem(
      mangaId: mangaId,
      mangaTitle: mangaTitle,
      coverUrl: cover,
      chapterId: chapterId,
      chapterNumber: chapterNumber,
      chapterTitle: chapterTitle,
      userRate: userRate,
      readAt: readAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'manga_id': mangaId,
        'manga_title': mangaTitle,
        'cover_portrait_url': coverUrl,
        'chapter_id': chapterId,
        'chapter_number': chapterNumber,
        'chapter_title': chapterTitle,
        'user_rate': userRate,
        'read_at': readAt.toIso8601String(),
      };
}
