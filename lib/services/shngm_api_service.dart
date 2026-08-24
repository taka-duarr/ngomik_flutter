import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_endpoints.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/user.dart';
import '../models/comment.dart';
import '../models/reading_history.dart';

class ShngmApiService {
  final http.Client _client = http.Client();

  Future<List<Manga>> fetchMangaList({
    int page = 1,
    int? pageSize,
    String? sort, // 'latest', 'bookmark', 'rating'
    String? type, // 'project', 'mirror'
    String? format, // 'manhwa', 'manga', 'manhua'
    String? genre,
    String? status, // '1' (Ongoing), '2' (Completed)
    String? q,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
      };

      if (pageSize != null) {
        queryParams['page_size'] = pageSize.toString();
      }
      if (sort != null && sort.isNotEmpty) {
        queryParams['sort'] = sort;
      }
      if (type != null && type.isNotEmpty && type.toLowerCase() != 'all') {
        queryParams['type'] = type;
      }
      if (format != null && format.isNotEmpty && format.toLowerCase() != 'all') {
        queryParams['format'] = format;
      }
      if (genre != null && genre.isNotEmpty) {
        queryParams['genre'] = genre;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (q != null && q.isNotEmpty) {
        queryParams['q'] = q;
      }

      final uri = Uri.parse(ApiEndpoints.latestManga).replace(queryParameters: queryParams);
      final response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] ?? data['results'] ?? [];
        if (list is List) {
          return list.map((item) => Manga.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetchMangaList: $e');
      return [];
    }
  }

  Future<List<Manga>> fetchLatestManga({int page = 1, int? pageSize}) async {
    return fetchMangaList(page: page, pageSize: pageSize, sort: 'latest');
  }

  Future<List<Manga>> fetchPopularManga({int page = 1, int? pageSize}) async {
    return fetchMangaList(page: page, pageSize: pageSize, sort: 'bookmark');
  }

  Future<List<Manga>> searchManga({
    required String query,
    int page = 1,
    int? pageSize,
    String? genre,
    String? status,
    String? type,
    String? format,
    String? sort = 'latest',
  }) async {
    return fetchMangaList(
      page: page,
      pageSize: pageSize,
      q: query,
      genre: genre,
      status: status,
      type: type,
      format: format,
      sort: sort,
    );
  }

  Future<Map<String, dynamic>?> fetchMangaDetail(String mangaId) async {
    try {
      final detailUri = Uri.parse(ApiEndpoints.mangaDetail(mangaId));

      // Fetch detail and initial chapters in parallel for maximum speed
      final results = await Future.wait([
        _client.get(detailUri, headers: ApiEndpoints.defaultHeaders()),
        fetchChapterPage(mangaId, page: 1, pageSize: 25),
      ]);

      final detailResponse = results[0] as http.Response;
      final chapterResult = results[1] as ChapterPageResult;

      if (detailResponse.statusCode == 200) {
        final detailData = jsonDecode(detailResponse.body);
        final mangaMap = detailData['data'] ?? detailData;
        final manga = Manga.fromJson(mangaMap as Map<String, dynamic>);

        return {
          'manga': manga,
          'chapterResult': chapterResult,
          'chapters': chapterResult.chapters,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error fetchMangaDetail: $e');
      return null;
    }
  }

  Future<ChapterPageResult> fetchChapterPage(String mangaId, {int page = 1, int pageSize = 25}) async {
    try {
      final uri = Uri.parse(ApiEndpoints.chapterList(mangaId)).replace(queryParameters: {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'sort_by': 'chapter_number',
        'sort_order': 'desc',
      });
      final response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders());

      if (response.statusCode == 200) {
        final chData = jsonDecode(response.body);
        final chList = chData['data'] ?? chData['results'] ?? [];
        final meta = chData['meta'] as Map<String, dynamic>?;

        List<Chapter> chapters = [];
        if (chList is List) {
          chapters = chList
              .whereType<Map<String, dynamic>>()
              .map((ch) => Chapter.fromJson(ch, mangaId: mangaId))
              .toList();
        }

        final curPage = meta?['page'] is int
            ? meta!['page'] as int
            : int.tryParse(meta?['page']?.toString() ?? '') ?? page;
        final totalPage = meta?['total_page'] is int
            ? meta!['total_page'] as int
            : int.tryParse(meta?['total_page']?.toString() ?? '') ??
                (chapters.length >= pageSize ? page + 1 : page);
        final totalRecord = meta?['total_record'] is int
            ? meta!['total_record'] as int
            : int.tryParse(meta?['total_record']?.toString() ?? '') ?? chapters.length;

        return ChapterPageResult(
          chapters: chapters,
          page: curPage,
          totalPages: totalPage,
          totalRecords: totalRecord,
        );
      }
      return ChapterPageResult(chapters: [], page: page, totalPages: page, totalRecords: 0);
    } catch (e) {
      debugPrint('Error fetchChapterPage: $e');
      return ChapterPageResult(chapters: [], page: page, totalPages: page, totalRecords: 0);
    }
  }

  Future<List<Chapter>> fetchChapterList(String mangaId, {int page = 1, int pageSize = 25}) async {
    final res = await fetchChapterPage(mangaId, page: page, pageSize: pageSize);
    return res.chapters;
  }

  Future<ChapterDetail?> fetchChapterImages(String chapterId) async {
    try {
      final uri = Uri.parse(ApiEndpoints.chapterDetail(chapterId));
      final response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final chapterData = data['data'] ?? data;
        return ChapterDetail.fromJson(chapterData as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetchChapterImages: $e');
      return null;
    }
  }

  Future<User?> fetchUserProfile(String tokenOrUserId) async {
    try {
      final isToken = tokenOrUserId.startsWith('v4.public.') ||
          tokenOrUserId.startsWith('Bearer ') ||
          tokenOrUserId.startsWith('eyJ'); // Supabase JWT
      if (isToken) {
        final uri = Uri.parse(ApiEndpoints.userDetail);
        final response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders(token: tokenOrUserId));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final profile = data['data'] ?? data;
          return User.fromJson(profile as Map<String, dynamic>, token: tokenOrUserId);
        }
      } else {
        final uri = Uri.parse(ApiEndpoints.userProfile(tokenOrUserId));
        final response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders());

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final profile = data['data'] ?? data;
          return User.fromJson(profile as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetchUserProfile: $e');
      return null;
    }
  }

  Future<List<Manga>> fetchUserBookmarks(String token, {int page = 1, int pageSize = 50}) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'sort_by': 'latest',
        'sort_order': 'desc',
      };

      final uri = Uri.parse(ApiEndpoints.bookmarkList).replace(queryParameters: queryParams);
      final response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders(token: token));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] ?? data['results'] ?? data['bookmarks'] ?? [];
        if (list is List) {
          return list.map((item) => Manga.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetchUserBookmarks: $e');
      return [];
    }
  }

  Future<bool> addBookmark(String token, String mangaId) async {
    try {
      final uri = Uri.parse(ApiEndpoints.bookmarkAdd);
      final response = await _client.post(
        uri,
        headers: ApiEndpoints.defaultHeaders(token: token),
        body: jsonEncode({'manga_id': mangaId}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error addBookmark: $e');
      return false;
    }
  }

  Future<bool> removeBookmark(String token, String mangaId) async {
    try {
      final uri = Uri.parse(ApiEndpoints.bookmarkRemove);
      final response = await _client.post(
        uri,
        headers: ApiEndpoints.defaultHeaders(token: token),
        body: jsonEncode({'manga_id': mangaId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error removeBookmark: $e');
      return false;
    }
  }

  Future<List<ReadingHistoryItem>> fetchUserHistory(String token, {int page = 1, int pageSize = 50}) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'sort_by': 'updated_at',
        'sort_order': 'desc',
      };

      final uri = Uri.parse(ApiEndpoints.historyList).replace(queryParameters: queryParams);
      final response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders(token: token));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] ?? data['results'] ?? data['history'] ?? [];
        if (list is List) {
          return list.map((item) => ReadingHistoryItem.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetchUserHistory: $e');
      return [];
    }
  }

  Future<bool> addHistory(String token, String mangaId, String chapterId) async {
    try {
      final uri = Uri.parse(ApiEndpoints.historyAdd);
      final response = await _client.post(
        uri,
        headers: ApiEndpoints.defaultHeaders(token: token),
        body: jsonEncode({
          'manga_id': mangaId,
          'chapter_id': chapterId,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error addHistory: $e');
      return false;
    }
  }

  Future<bool> removeHistory(String token, String mangaId) async {
    try {
      final uri = Uri.parse(ApiEndpoints.historyRemove);
      final response = await _client.post(
        uri,
        headers: ApiEndpoints.defaultHeaders(token: token),
        body: jsonEncode({'manga_id': mangaId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error removeHistory: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchHistoryByManga(String mangaId, String token) async {
    try {
      final uri = Uri.parse(ApiEndpoints.historyGetByManga(mangaId));
      final response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders(token: token));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] is Map<String, dynamic> ? data['data'] as Map<String, dynamic> : null;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetchHistoryByManga: $e');
      return null;
    }
  }

  Future<List<String>> fetchMangaChapterHistory(
    String mangaId,
    String token, {
    int pageSize = 50,
  }) async {
    final List<String> readIds = [];
    int page = 1;
    int totalPages = 1;

    try {
      do {
        final uri = Uri.parse(
          '${ApiEndpoints.chapterHistory(mangaId)}?page=$page&page_size=$pageSize&sort_by=chapter_number&sort_order=desc',
        );
        final response = await _client.get(
          uri,
          headers: ApiEndpoints.defaultHeaders(token: token),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final meta = data['meta'] as Map<String, dynamic>?;
          totalPages = meta?['total_page'] is int
              ? meta!['total_page'] as int
              : int.tryParse(meta?['total_page']?.toString() ?? '') ?? 1;

          final list = data['data'] ?? [];
          if (list is List) {
            for (final item in list) {
              if (item is Map && item['is_read'] == true) {
                final chId = (item['chapter_id'] ?? '').toString();
                if (chId.isNotEmpty && chId != 'null') {
                  readIds.add(chId);
                }
              }
            }
          }
        } else {
          break;
        }
        page++;
      } while (page <= totalPages);
    } catch (e) {
      debugPrint('Error fetchMangaChapterHistory: $e');
    }
    return readIds;
  }

  Future<CommentPageResult> fetchComments(
    String path, {
    int page = 1,
    int pageSize = 15,
    String sortBy = 'like_desc',
  }) async {
    try {
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final queryParams = {
        'path': cleanPath,
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        'lang': 'en',
        'sortBy': sortBy,
      };
      final uri = Uri.parse(ApiEndpoints.walineComments).replace(queryParameters: queryParams);
      final response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders());

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        final dataObj = resJson['data'];
        List<WalineComment> comments = [];
        int count = 0;
        int totalPages = 1;

        if (dataObj is Map) {
          count = int.tryParse(dataObj['count']?.toString() ?? '0') ?? 0;
          totalPages = int.tryParse(dataObj['totalPages']?.toString() ?? '1') ?? 1;
          final list = dataObj['data'] ?? [];
          if (list is List) {
            comments = list
                .whereType<Map<String, dynamic>>()
                .map((c) => WalineComment.fromJson(c))
                .toList();
          }
        } else if (dataObj is List) {
          comments = dataObj
              .whereType<Map<String, dynamic>>()
              .map((c) => WalineComment.fromJson(c))
              .toList();
          count = comments.length;
        }

        return CommentPageResult(
          comments: comments,
          page: page,
          totalPages: totalPages,
          totalRecords: count,
        );
      }
      return const CommentPageResult(comments: [], page: 1, totalPages: 1, totalRecords: 0);
    } catch (e) {
      debugPrint('Error fetchComments: $e');
      return const CommentPageResult(comments: [], page: 1, totalPages: 1, totalRecords: 0);
    }
  }

  Future<bool> postComment({
    required String path,
    required String comment,
    required String nick,
    String? mail,
    String? link,
  }) async {
    try {
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final uri = Uri.parse(ApiEndpoints.walineComments);
      final body = {
        'path': cleanPath,
        'comment': comment,
        'nick': nick,
        'mail': mail ?? '',
        'link': link ?? '',
        'ua': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      };

      final response = await _client.post(
        uri,
        headers: ApiEndpoints.defaultHeaders(token: null),
        body: jsonEncode(body),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error postComment: $e');
      return false;
    }
  }
}

class ChapterPageResult {
  final List<Chapter> chapters;
  final int page;
  final int totalPages;
  final int totalRecords;

  const ChapterPageResult({
    required this.chapters,
    required this.page,
    required this.totalPages,
    required this.totalRecords,
  });
}

