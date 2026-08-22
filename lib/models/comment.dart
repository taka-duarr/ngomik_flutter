class WalineComment {
  final String id;
  final String nick;
  final String comment;
  final String? orig;
  final String? avatar;
  final String? insertedAt;
  final int like;
  final int level;
  final int replyCount;
  final List<WalineComment> replies;
  final List<String> imageUrls;

  const WalineComment({
    required this.id,
    required this.nick,
    required this.comment,
    this.orig,
    this.avatar,
    this.insertedAt,
    this.like = 0,
    this.level = 1,
    this.replyCount = 0,
    this.replies = const [],
    this.imageUrls = const [],
  });

  String get cleanComment {
    String text = comment;

    text = text
        .replaceAll(RegExp(r'<hr\s*\/?>', caseSensitive: false), '\n───\n')
        .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\/?p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\/?(strong|b)>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\/?(em|i)>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\/?(u|ins)>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\/?(s|del|strike)>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\/?(code|pre)>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\/?(blockquote|q)>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\/?(ul|ol|li)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\/?(div|span|section|header|footer)[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<a[^>]*>(.*?)<\/a>', caseSensitive: false), r'$1')
        .replaceAll(RegExp(r'<img[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<details>[\s\S]*?<\/details>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (text.isEmpty && orig != null && orig!.isNotEmpty) {
      return orig!
          .replaceAll(RegExp(r'!\[.*?\]\(.*?\)|<img[^>]*>'), '')
          .replaceAll(RegExp(r'\[spoiler\][\s\S]*?\[\/spoiler\]'), '')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
    }
    return text;
  }

  factory WalineComment.fromJson(Map<String, dynamic> json) {
    List<WalineComment> repList = [];
    if (json['children'] is List) {
      for (var c in json['children']) {
        if (c is Map<String, dynamic>) {
          repList.add(WalineComment.fromJson(c));
        }
      }
    }

    final rawComment = json['comment']?.toString() ?? '';
    final rawOrig = json['orig']?.toString() ?? '';

    // Extract images from html <img> and markdown ![]()
    final List<String> imgs = [];
    final imgTagRegex = RegExp(r'<img[^>]+src="([^">]+)"', caseSensitive: false);
    for (final match in imgTagRegex.allMatches(rawComment)) {
      final src = match.group(1);
      if (src != null && !src.contains('wl-emoji') && !imgs.contains(src)) {
        imgs.add(src);
      }
    }

    final mdImgRegex = RegExp(r'!\[.*?\]\((https?:\/\/[^\s\)]+)\)');
    for (final match in mdImgRegex.allMatches(rawOrig)) {
      final src = match.group(1);
      if (src != null && !imgs.contains(src)) {
        imgs.add(src);
      }
    }

    int rawLevel = int.tryParse(json['level']?.toString() ?? '1') ?? 1;
    if (rawLevel == 0) rawLevel = 1;

    return WalineComment(
      id: json['objectId']?.toString() ?? json['id']?.toString() ?? '',
      nick: json['nick']?.toString() ?? 'Pembaca Anonim',
      comment: rawComment,
      orig: rawOrig,
      avatar: json['avatar']?.toString(),
      insertedAt: json['insertedAt']?.toString() ?? json['time']?.toString() ?? json['created_at']?.toString(),
      like: int.tryParse(json['like']?.toString() ?? '0') ?? 0,
      level: rawLevel,
      replyCount: int.tryParse(json['reply_count']?.toString() ?? '0') ?? repList.length,
      replies: repList,
      imageUrls: imgs,
    );
  }
}

class CommentPageResult {
  final List<WalineComment> comments;
  final int page;
  final int totalPages;
  final int totalRecords;

  const CommentPageResult({
    required this.comments,
    required this.page,
    required this.totalPages,
    required this.totalRecords,
  });
}
