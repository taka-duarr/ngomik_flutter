class Manga {
  final String id;
  final String title;
  final String? alternativeTitle;
  final String? slug;
  final String coverUrl;
  final String? bannerUrl;
  final double rating;
  final int ratingCount;
  final String synopsis;
  final String status;
  final String type; // Manhwa, Manga, Manhua
  final List<String> genres;
  final String? latestChapter;
  final String? latestChapterId;
  final String? latestChapterTime;
  final int bookmarkCount;
  final int viewCount;
  final bool isBookmarked;

  const Manga({
    required this.id,
    required this.title,
    this.alternativeTitle,
    this.slug,
    required this.coverUrl,
    this.bannerUrl,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.synopsis = '',
    this.status = 'Ongoing',
    this.type = 'Manhwa',
    this.genres = const [],
    this.latestChapter,
    this.latestChapterId,
    this.latestChapterTime,
    this.bookmarkCount = 0,
    this.viewCount = 0,
    this.isBookmarked = false,
  });

  factory Manga.fromJson(Map<String, dynamic> json) {
    final mangaObj = json['manga'] is Map<String, dynamic> ? json['manga'] as Map<String, dynamic> : null;
    final id = (json['manga_id'] ?? mangaObj?['id'] ?? json['id'] ?? json['uuid'] ?? '').toString();
    final title = (mangaObj?['title'] ?? json['title'] ?? mangaObj?['name'] ?? json['name'] ?? 'Judul Komik').toString();

    // Normalizer for image URLs
    String normalizeUrl(String? raw) {
      if (raw == null) return '';
      var url = raw.trim();
      if (url.isEmpty || url == 'null' || url == 'undefined') return '';
      if (url.startsWith('//')) {
        return 'https:$url';
      }
      if (url.startsWith('/')) {
        return 'https://assets.shngm.id$url';
      }
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        return 'https://assets.shngm.id/$url';
      }
      return url;
    }

    // Helper to find the first non-empty image URL
    String getFirstNonEmpty(List<String> keys) {
      for (final k in keys) {
        final val = json[k]?.toString() ?? mangaObj?[k]?.toString();
        final normalized = normalizeUrl(val);
        if (normalized.isNotEmpty) {
          return normalized;
        }
      }
      return '';
    }

    String cover = getFirstNonEmpty([
      'cover_portrait_url',
      'cover_image_url',
      'cover_landscape_url',
      'thumbnail_image_url',
      'cover_url',
      'cover',
      'banner_image_url',
      'banner_url',
      'thumbnail',
      'image',
    ]);

    String banner = getFirstNonEmpty([
      'cover_landscape_url',
      'banner_image_url',
      'banner_url',
      'banner',
      'cover_portrait_url',
      'cover_image_url',
      'thumbnail_image_url',
      'cover_url',
      'cover',
      'thumbnail',
      'image',
    ]);

    if (banner.isEmpty) banner = cover;
    if (cover.isEmpty) cover = banner;

    double rating = 0.0;
    if (json['user_rate'] != null) {
      rating = double.tryParse(json['user_rate'].toString()) ?? 0.0;
    } else if (json['rate'] != null) {
      rating = double.tryParse(json['rate'].toString()) ?? 0.0;
    } else if (json['rating'] != null) {
      rating = double.tryParse(json['rating'].toString()) ?? 0.0;
    }

    int ratingCount = int.tryParse(json['rating_count']?.toString() ?? '0') ?? 0;
    String synopsis = (json['description'] ?? json['synopsis'] ?? '').toString();

    // Parse status (can be int 1/2 or String 'Ongoing'/'Completed')
    String status = 'Ongoing';
    if (json['status'] != null) {
      final sStr = json['status'].toString().toLowerCase();
      if (sStr == '1' || sStr.contains('ongoing')) {
        status = 'Ongoing';
      } else if (sStr == '2' || sStr.contains('completed') || sStr.contains('tamat')) {
        status = 'Completed';
      } else {
        status = json['status'].toString();
      }
    }

    // Parse type/Format (Manhwa, Manga, Manhua)
    String type = 'Manhwa';
    if (json['type'] is String && (json['type'] as String).isNotEmpty) {
      type = json['type'].toString();
    } else if (json['taxonomy'] is Map) {
      final tax = json['taxonomy'] as Map;
      if (tax['Format'] is List && (tax['Format'] as List).isNotEmpty) {
        final fmt = tax['Format'][0];
        if (fmt is Map && fmt['name'] != null) {
          type = fmt['name'].toString();
        }
      }
    }

    // Parse genres from genres list or taxonomy.Genre
    List<String> genresList = [];
    if (json['genres'] is List) {
      for (var g in json['genres']) {
        if (g is String) {
          genresList.add(g);
        } else if (g is Map && g['name'] != null) {
          genresList.add(g['name'].toString());
        } else if (g is Map && g['title'] != null) {
          genresList.add(g['title'].toString());
        }
      }
    } else if (json['taxonomy'] is Map && (json['taxonomy'] as Map)['Genre'] is List) {
      for (var g in (json['taxonomy'] as Map)['Genre']) {
        if (g is Map && g['name'] != null) {
          genresList.add(g['name'].toString());
        }
      }
    } else if (json['genre'] != null) {
      genresList = json['genre'].toString().split(',').map((e) => e.trim()).toList();
    }

    String? latestCh = json['latest_chapter_number']?.toString() ??
        json['latest_chapter']?.toString() ??
        json['chapter_number']?.toString();

    String? latestChId = json['latest_chapter_id']?.toString() ?? json['chapter_id']?.toString();
    String? latestChTime = json['latest_chapter_time']?.toString() ?? json['updated_at']?.toString();

    return Manga(
      id: id,
      title: title,
      alternativeTitle: json['alternative_title']?.toString(),
      slug: json['slug']?.toString(),
      coverUrl: cover,
      bannerUrl: banner,
      rating: rating,
      ratingCount: ratingCount,
      synopsis: synopsis,
      status: status,
      type: type,
      genres: genresList,
      latestChapter: latestCh,
      latestChapterId: latestChId,
      latestChapterTime: latestChTime,
      bookmarkCount: int.tryParse(json['bookmark_count']?.toString() ?? '0') ?? 0,
      viewCount: int.tryParse(json['view_count']?.toString() ?? '0') ?? 0,
      isBookmarked: json['is_bookmark'] == true || json['is_bookmarked'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'manga_id': id,
        'title': title,
        'alternative_title': alternativeTitle,
        'slug': slug,
        'cover_portrait_url': coverUrl,
        'cover_image_url': coverUrl,
        'cover_landscape_url': bannerUrl,
        'user_rate': rating,
        'rating_count': ratingCount,
        'synopsis': synopsis,
        'status': status,
        'type': type,
        'genres': genres,
        'latest_chapter_number': latestChapter,
        'latest_chapter_id': latestChapterId,
        'latest_chapter_time': latestChapterTime,
        'bookmark_count': bookmarkCount,
        'view_count': viewCount,
        'is_bookmark': isBookmarked,
      };

  Manga copyWith({
    String? id,
    String? title,
    String? alternativeTitle,
    String? slug,
    String? coverUrl,
    String? bannerUrl,
    double? rating,
    int? ratingCount,
    String? synopsis,
    String? status,
    String? type,
    List<String>? genres,
    String? latestChapter,
    String? latestChapterId,
    String? latestChapterTime,
    int? bookmarkCount,
    int? viewCount,
    bool? isBookmarked,
  }) {
    return Manga(
      id: id ?? this.id,
      title: title ?? this.title,
      alternativeTitle: alternativeTitle ?? this.alternativeTitle,
      slug: slug ?? this.slug,
      coverUrl: coverUrl ?? this.coverUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      synopsis: synopsis ?? this.synopsis,
      status: status ?? this.status,
      type: type ?? this.type,
      genres: genres ?? this.genres,
      latestChapter: latestChapter ?? this.latestChapter,
      latestChapterId: latestChapterId ?? this.latestChapterId,
      latestChapterTime: latestChapterTime ?? this.latestChapterTime,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
      viewCount: viewCount ?? this.viewCount,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }
}
