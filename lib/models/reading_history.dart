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
    return ReadingHistoryItem(
      mangaId: json['manga_id']?.toString() ?? json['id']?.toString() ?? '',
      mangaTitle: json['manga_title']?.toString() ?? json['title']?.toString() ?? 'Komik',
      coverUrl: json['cover_portrait_url']?.toString() ?? json['cover_image_url']?.toString() ?? json['cover_url']?.toString() ?? '',
      chapterId: json['chapter_id']?.toString() ?? '',
      chapterNumber: json['chapter_number']?.toString() ?? '0',
      chapterTitle: json['chapter_title']?.toString(),
      userRate: json['user_rate'] != null ? double.tryParse(json['user_rate'].toString()) : null,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) ?? DateTime.now() : DateTime.now(),
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
