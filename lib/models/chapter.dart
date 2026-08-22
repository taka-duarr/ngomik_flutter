class Chapter {
  final String id;
  final String? mangaId;
  final String chapterNumber;
  final String? chapterTitle;
  final String? releaseDate;
  final String? thumbnailUrl;
  final int views;
  final bool isRead;

  const Chapter({
    required this.id,
    this.mangaId,
    required this.chapterNumber,
    this.chapterTitle,
    this.releaseDate,
    this.thumbnailUrl,
    this.views = 0,
    this.isRead = false,
  });

  factory Chapter.fromJson(Map<String, dynamic> json, {String? mangaId, bool isRead = false}) {
    final id = (json['chapter_id'] ?? json['id'] ?? json['uuid'] ?? '').toString();
    final numStr = (json['chapter_number'] ??
            json['number'] ??
            json['chapter'] ??
            '0')
        .toString();

    final thumb = json['thumbnail_image_url']?.toString() ??
        json['thumbnail']?.toString() ??
        json['image_url']?.toString() ??
        json['cover_url']?.toString();

    return Chapter(
      id: id,
      mangaId: mangaId ?? json['manga_id']?.toString(),
      chapterNumber: numStr,
      chapterTitle: json['chapter_title']?.toString() ?? json['title']?.toString(),
      releaseDate: json['release_date']?.toString() ??
          json['created_at']?.toString() ??
          json['published_at']?.toString(),
      thumbnailUrl: thumb,
      views: int.tryParse(json['view_count']?.toString() ?? '0') ?? 0,
      isRead: isRead,
    );
  }

  Map<String, dynamic> toJson() => {
        'chapter_id': id,
        'manga_id': mangaId,
        'chapter_number': chapterNumber,
        'chapter_title': chapterTitle,
        'release_date': releaseDate,
        'thumbnail_image_url': thumbnailUrl,
        'view_count': views,
        'is_read': isRead,
      };

  Chapter copyWith({bool? isRead}) {
    return Chapter(
      id: id,
      mangaId: mangaId,
      chapterNumber: chapterNumber,
      chapterTitle: chapterTitle,
      releaseDate: releaseDate,
      thumbnailUrl: thumbnailUrl,
      views: views,
      isRead: isRead ?? this.isRead,
    );
  }
}

class ChapterDetail {
  final String id;
  final String? mangaId;
  final String? mangaTitle;
  final String chapterNumber;
  final String? chapterTitle;
  final List<String> images;
  final String? prevChapterId;
  final String? nextChapterId;

  const ChapterDetail({
    required this.id,
    this.mangaId,
    this.mangaTitle,
    required this.chapterNumber,
    this.chapterTitle,
    required this.images,
    this.prevChapterId,
    this.nextChapterId,
  });

  factory ChapterDetail.fromJson(Map<String, dynamic> json) {
    final id = (json['chapter_id'] ?? json['id'] ?? '').toString();
    final numStr = (json['chapter_number'] ?? json['number'] ?? '0').toString();

    List<String> imgList = [];

    // Check Shinigami standard format: base_url + chapter.path + chapter.data
    String baseUrl = (json['base_url'] ?? '').toString().replaceAll(RegExp(r'/+$'), '');
    String path = '';
    List dataFiles = [];

    if (json['chapter'] is Map) {
      final chMap = json['chapter'] as Map;
      path = (chMap['path'] ?? '').toString().replaceAll(RegExp(r'^/+|/+$'), '');
      if (chMap['data'] is List) {
        dataFiles = chMap['data'] as List;
      }
    }

    if (baseUrl.isNotEmpty && dataFiles.isNotEmpty) {
      for (var file in dataFiles) {
        if (file != null && file.toString().isNotEmpty) {
          final cleanFile = file.toString().replaceAll(RegExp(r'^/+'), '');
          if (path.isNotEmpty) {
            imgList.add('$baseUrl/$path/$cleanFile');
          } else {
            imgList.add('$baseUrl/$cleanFile');
          }
        }
      }
    } else if (json['chapter_images'] is List) {
      for (var img in json['chapter_images']) {
        if (img is String) {
          imgList.add(img);
        } else if (img is Map && img['storage_path'] != null) {
          imgList.add(img['storage_path'].toString());
        } else if (img is Map && img['url'] != null) {
          imgList.add(img['url'].toString());
        }
      }
    } else if (json['images'] is List) {
      for (var img in json['images']) {
        if (img is String) {
          imgList.add(img);
        } else if (img is Map && img['url'] != null) {
          imgList.add(img['url'].toString());
        }
      }
    }

    return ChapterDetail(
      id: id,
      mangaId: json['manga_id']?.toString(),
      mangaTitle: json['manga_title']?.toString() ?? json['manga']?['title']?.toString(),
      chapterNumber: numStr,
      chapterTitle: json['chapter_title']?.toString() ?? json['title']?.toString(),
      images: imgList,
      prevChapterId: json['prev_chapter_id']?.toString() ?? json['prev_id']?.toString(),
      nextChapterId: json['next_chapter_id']?.toString() ?? json['next_id']?.toString(),
    );
  }
}
