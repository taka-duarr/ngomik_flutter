import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiEndpoints {
  ApiEndpoints._();

  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'https://api.shngm.io';

  // Manga Lists
  static String get latestManga => '$baseUrl/v1/manga/list';
  static String get searchManga => '$baseUrl/v1/manga/search';

  // Manga Detail & Chapters
  static String mangaDetail(String mangaId) => '$baseUrl/v1/manga/detail/$mangaId';
  static String chapterList(String mangaId) => '$baseUrl/v1/chapter/$mangaId/list';
  static String chapterDetail(String chapterId) => '$baseUrl/v1/chapter/detail/$chapterId';

  // User & Profile
  static String get userDetail => '$baseUrl/v1/user/detail';
  static String userProfile(String userId) => '$baseUrl/v1/user/profile/$userId';

  // Bookmarks
  static String get bookmarkList => '$baseUrl/v1/bookmark/list';
  static String get bookmarkAdd => '$baseUrl/v1/bookmark/add';
  static String get bookmarkRemove => '$baseUrl/v1/bookmark/remove';

  // Reading History
  static String get historyAdd => '$baseUrl/v1/history/add';
  static String get historyRemove => '$baseUrl/v1/history/remove';

  // Comments (Waline API)
  static String get walineComments =>
      dotenv.env['WALINE_API_URL'] ?? 'https://commento.shngm.io/api/comment';

  // Default Headers
  static Map<String, String> defaultHeaders({String? token}) {
    final origin = dotenv.env['DEFAULT_ORIGIN'] ?? 'https://11.shinigami.asia';
    final referer = dotenv.env['DEFAULT_REFERER'] ?? 'https://11.shinigami.asia/';

    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Origin': origin,
      'Referer': referer,
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };

    if (token != null && token.isNotEmpty) {
      final cleanToken = token.startsWith('Bearer ') ? token : 'Bearer $token';
      headers['Authorization'] = cleanToken;
    }

    return headers;
  }
}
