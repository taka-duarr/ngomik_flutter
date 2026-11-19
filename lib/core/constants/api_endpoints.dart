import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiEndpoints {
  ApiEndpoints._();

  static String _getEnv(String key, String fallback) {
    if (dotenv.isInitialized) {
      return dotenv.env[key] ?? fallback;
    }
    return fallback;
  }

  // Base URLs directly from .env (with safe fallbacks if dotenv is not yet initialized)
  static String get baseUrl => _getEnv('API_BASE_URL', 'https://api.shinigami.io');
  static String get commentsBaseUrl => _getEnv('WALINE_API_URL', 'https://api.shinigami.io/comment/api/v2');
  static String get walineComments => commentsBaseUrl;
  static String get commentsList => '$commentsBaseUrl/comments';
  static String get commentsStats => '$commentsBaseUrl/stats/page_comment_info';
  static String get chatConnectionToken => '$commentsBaseUrl/chat/connection-token';
  static String commentVote(String commentId, String action) => '$commentsBaseUrl/votes/comment/$commentId/$action';

  // WorkOS AuthKit
  static String get workosAuthUrl => 'https://api.workos.com/user_management/authenticate';
  static String get workosClientId => _getEnv('WORKOS_CLIENT_ID', 'client_01KJWQWJ8M8WAKN8ZDWVVJ4BG1');

  // Page key format helpers for Shinigami Comments
  static String mangaPageKey(String mangaId) => 'manga:$mangaId';
  static String chapterPageKey(String mangaId, String chapterId) => 'manga:$mangaId:chapter:$chapterId';

  static String normalizeCommentKey(String path, {String? mangaId, String? chapterId}) {
    final clean = path.trim().replaceFirst(RegExp(r'^/+'), '');
    if (clean.startsWith('manga:') || clean.startsWith('post:')) {
      return clean;
    }
    if (clean.startsWith('series/')) {
      return 'manga:${clean.substring(7)}';
    }
    if (clean.startsWith('chapter/')) {
      final chId = clean.substring(8);
      if (mangaId != null && mangaId.isNotEmpty) {
        return 'manga:$mangaId:chapter:$chId';
      }
      return 'chapter:$chId';
    }
    if (mangaId != null && mangaId.isNotEmpty) {
      if (chapterId != null && chapterId.isNotEmpty) {
        return 'manga:$mangaId:chapter:$chapterId';
      }
      return 'manga:$mangaId';
    }
    return clean;
  }
  static String get origin => _getEnv('DEFAULT_ORIGIN', 'https://s1.shinigami.mx');
  static String get referer => _getEnv('DEFAULT_REFERER', 'https://s1.shinigami.mx/');
  static String get assetsBaseUrl => _getEnv('ASSETS_BASE_URL', 'https://cdn.shinigami.gg');
  static String get userAgent => _getEnv(
        'USER_AGENT',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );

  // Manga Lists
  static String get latestManga => '$baseUrl/v1/manga/list';
  static String get searchManga => '$baseUrl/v1/manga/list';

  // Recommendations
  static String get recommendationHomeHero => '$baseUrl/v1/manga/recommendation/lists/home-hero';
  static String get recommendationHome => '$baseUrl/v1/manga/recommendation/lists/home';

  // Manga Detail & Chapters
  static String mangaDetail(String mangaId) => '$baseUrl/v1/manga/detail/$mangaId';
  static String chapterList(String mangaId) => '$baseUrl/v1/chapter/$mangaId/list';
  static String chapterDetail(String chapterId) => '$baseUrl/v1/chapter/detail/$chapterId';
  static String chapterHistory(String mangaId) => '$baseUrl/v1/chapter/$mangaId/history';

  // User & Profile
  static String get userDetail => '$baseUrl/v1/user/detail';
  static String userProfile(String userId) => '$baseUrl/v1/user/profile/$userId';

  // Bookmarks
  static String get bookmarkList => '$baseUrl/v1/bookmark/list';
  static String get bookmarkAdd => '$baseUrl/v1/bookmark/add';
  static String get bookmarkRemove => '$baseUrl/v1/bookmark/remove';

  // Reading History
  static String get historyList => '$baseUrl/v1/history/list';
  static String historyGetByManga(String mangaId) => '$baseUrl/v1/history/get-by-manga/$mangaId';
  static String get historyAdd => '$baseUrl/v1/history/add';
  static String get historyRemove => '$baseUrl/v1/history/remove';

  // Default Headers
  static Map<String, String> defaultHeaders({String? token}) {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (origin.isNotEmpty) 'Origin': origin,
      if (referer.isNotEmpty) 'Referer': referer,
      'User-Agent': userAgent,
    };

    if (token != null && token.isNotEmpty) {
      final cleanToken = token.startsWith('Bearer ') ? token : 'Bearer $token';
      headers['Authorization'] = cleanToken;
    }

    return headers;
  }

  // Dedicated headers for images
  static Map<String, String> get imageHeaders {
    return {
      if (origin.isNotEmpty) 'Origin': origin,
      if (referer.isNotEmpty) 'Referer': referer,
      'User-Agent': userAgent,
    };
  }
}
