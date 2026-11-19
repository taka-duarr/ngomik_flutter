  import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_endpoints.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../models/user.dart';
import '../models/comment.dart';
import '../models/reading_history.dart';
import '../core/utils/clipboard_helper.dart';
import 'chapter_pager.dart';

class ShngmApiService {
  final http.Client _client = http.Client();
  static Future<String?> Function()? onTokenRefresh;

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
      // The API pages with limit/offset now; page/page_size are ignored and
      // every request used to return the same first 12 titles.
      final limit = pageSize ?? 12;
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': ((page < 1 ? 0 : page - 1) * limit).toString(),
      };
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

  Future<List<Manga>> fetchHomeHeroManga() async {
    try {
      final uri = Uri.parse(ApiEndpoints.recommendationHomeHero);
      final response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data']?['mangas'] ?? data['data'] ?? [];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map((item) => Manga.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetchHomeHeroManga: $e');
      return [];
    }
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
        fetchChapterPage(mangaId, limit: ChapterPager.defaultLimit),
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

  /// One page of a manga's chapters.
  ///
  /// The API paginates with a cursor: pass the previous result's
  /// [ChapterPageResult.nextCursor] to get the following page. It does not
  /// report a total, so callers can't jump to an arbitrary page. Sorting and
  /// chapter-number search happen server-side, across every page.
  Future<ChapterPageResult> fetchChapterPage(
    String mangaId, {
    String? cursor,
    int limit = 24,
    bool ascending = false,
    String? search,
  }) async {
    try {
      final uri = Uri.parse(ApiEndpoints.chapterList(mangaId)).replace(queryParameters: {
        'limit': limit.toString(),
        'sort_by': 'chapter_number',
        'sort_order': ascending ? 'asc' : 'desc',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      });
      final response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders());

      if (response.statusCode != 200) {
        debugPrint('fetchChapterPage: HTTP ${response.statusCode}');
        return const ChapterPageResult(chapters: [], hasNext: false, failed: true);
      }

      final chData = jsonDecode(response.body);
      final chList = chData['data'] ?? chData['results'] ?? [];
      final meta = chData['meta'] is Map ? chData['meta'] as Map : const {};

      final chapters = chList is List
          ? chList
              .whereType<Map<String, dynamic>>()
              .map((ch) => Chapter.fromJson(ch, mangaId: mangaId))
              .toList()
          : <Chapter>[];

      final nextCursor = meta['next_cursor']?.toString();
      final hasNext = meta['has_next'] == true && nextCursor != null && nextCursor.isNotEmpty;

      return ChapterPageResult(
        chapters: chapters,
        hasNext: hasNext,
        nextCursor: hasNext ? nextCursor : null,
      );
    } catch (e) {
      debugPrint('Error fetchChapterPage: $e');
      return const ChapterPageResult(chapters: [], hasNext: false, failed: true);
    }
  }

  /// The very first chapter (lowest number) — for "Mulai Baca".
  Future<Chapter?> fetchFirstChapter(String mangaId) async {
    final res = await fetchChapterPage(mangaId, limit: 1, ascending: true);
    return res.chapters.isNotEmpty ? res.chapters.first : null;
  }

  Future<List<Chapter>> fetchChapterList(String mangaId, {int limit = 24}) async {
    final res = await fetchChapterPage(mangaId, limit: limit);
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
      final clean = ClipboardHelper.cleanToken(tokenOrUserId);
      final isToken = clean.startsWith('v4.public.') ||
          clean.startsWith('eyJ') ||
          clean.length > 50 ||
          tokenOrUserId.toLowerCase().startsWith('bearer ') ||
          (clean.split('.').length == 3 && clean.length > 30);
      if (isToken) {
        final uri = Uri.parse(ApiEndpoints.userDetail);
        var response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders(token: clean));

        if (response.statusCode == 401 && onTokenRefresh != null) {
          final refreshed = await onTokenRefresh!();
          if (refreshed != null && refreshed != clean) {
            response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders(token: refreshed));
          }
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final profile = data['data'] ?? data;
          return User.fromJson(profile as Map<String, dynamic>, token: clean);
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
      var response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders(token: token));

      if (response.statusCode == 401 && onTokenRefresh != null) {
        final refreshed = await onTokenRefresh!();
        if (refreshed != null && refreshed != token) {
          response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders(token: refreshed));
        }
      }

      if (response.statusCode != 200) debugPrint('fetchUserBookmarks: HTTP ${response.statusCode}');
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
      final clean = ClipboardHelper.cleanToken(token);
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'limit': pageSize.toString(),
        'sort_by': 'last_read_chapter_time',
        'sort_order': 'desc',
      };

      final uri = Uri.parse(ApiEndpoints.historyList).replace(queryParameters: queryParams);
      var response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders(token: clean));

      if (response.statusCode == 401 && onTokenRefresh != null) {
        final refreshed = await onTokenRefresh!();
        if (refreshed != null && refreshed != clean) {
          response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders(token: refreshed));
        }
      }

      if (response.statusCode != 200) debugPrint('fetchUserHistory: HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawData = data['data'];
        List? list;
        if (rawData is List) {
          list = rawData;
        } else if (rawData is Map) {
          list = rawData['data'] ?? rawData['history'] ?? rawData['list'] ?? rawData['results'];
        } else {
          list = data['results'] ?? data['history'];
        }

        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map((item) => ReadingHistoryItem.fromJson(item))
              .toList();
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
    String? mangaId,
    String? chapterId,
    String? token,
  }) async {
    try {
      final pageKey = ApiEndpoints.normalizeCommentKey(
        path,
        mangaId: mangaId,
        chapterId: chapterId,
      );
      final isArtalk = ApiEndpoints.commentsBaseUrl.contains('comment/api/v2');

      final Uri uri;
      if (isArtalk) {
        uri = Uri.parse(ApiEndpoints.commentsList).replace(queryParameters: {
          'page_key': pageKey,
          'offset': ((page - 1) * pageSize).toString(),
          'limit': pageSize.toString(),
          'sort_by': sortBy == 'like_desc' ? 'vote' : 'date_desc',
        });
      } else {
        uri = Uri.parse(ApiEndpoints.walineComments).replace(queryParameters: {
          'path': pageKey,
          'page': page.toString(),
          'pageSize': pageSize.toString(),
          'lang': 'en',
          'sortBy': sortBy,
        });
      }

      final response = await _client.get(
        uri,
        headers: ApiEndpoints.defaultHeaders(token: token),
      );

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        List<WalineComment> comments = [];
        int count = 0;
        int totalPages = 1;

        if (isArtalk) {
          final list = resJson['comments'] ?? [];
          count = int.tryParse(resJson['count']?.toString() ?? '0') ?? 0;
          totalPages = (count / pageSize).ceil();
          if (totalPages < 1) totalPages = 1;

          if (list is List) {
            final allParsed = list
                .whereType<Map<String, dynamic>>()
                .map((c) => WalineComment.fromJson(c))
                .toList();

            // Group replies by rid (Artalk uses flat list with rid)
            final Map<String, List<WalineComment>> replyMap = {};
            final List<WalineComment> rootList = [];

            for (final c in allParsed) {
              if (c.rid > 0) {
                final parentKey = c.rid.toString();
                replyMap.putIfAbsent(parentKey, () => []).add(c);
              } else {
                rootList.add(c);
              }
            }

            if (replyMap.isNotEmpty) {
              comments = rootList.map((r) {
                final rep = replyMap[r.id];
                if (rep != null && rep.isNotEmpty) {
                  return r.copyWith(replies: [...r.replies, ...rep]);
                }
                return r;
              }).toList();
            } else {
              comments = rootList.isNotEmpty ? rootList : allParsed;
            }
          }
        } else {
          final dataObj = resJson['data'];
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

  Future<int> fetchCommentCount(
    String path, {
    String? mangaId,
    String? chapterId,
  }) async {
    try {
      final pageKey = ApiEndpoints.normalizeCommentKey(
        path,
        mangaId: mangaId,
        chapterId: chapterId,
      );
      final uri = Uri.parse(ApiEndpoints.commentsStats).replace(queryParameters: {
        'page_keys': pageKey,
      });

      final response = await _client.get(uri, headers: ApiEndpoints.defaultHeaders());
      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        final count = resJson['data']?['count'];
        return int.tryParse(count?.toString() ?? '0') ?? 0;
      }
    } catch (e) {
      debugPrint('Error fetchCommentCount: $e');
    }
    return 0;
  }

  Future<bool> postComment({
    required String path,
    required String comment,
    required String nick,
    String? mail,
    String? link,
    String? mangaId,
    String? chapterId,
    int? rid,
    String? token,
  }) async {
    try {
      final pageKey = ApiEndpoints.normalizeCommentKey(
        path,
        mangaId: mangaId,
        chapterId: chapterId,
      );
      final isArtalk = ApiEndpoints.commentsBaseUrl.contains('comment/api/v2');

      final Uri uri;
      final Map<String, dynamic> body;

      if (isArtalk) {
        uri = Uri.parse(ApiEndpoints.commentsList);
        body = {
          'page_key': pageKey,
          'content': comment,
          if (rid != null && rid > 0) 'rid': rid,
        };
      } else {
        uri = Uri.parse(ApiEndpoints.walineComments);
        body = {
          'path': pageKey,
          'comment': comment,
          'nick': nick,
          'mail': mail ?? '',
          'link': link ?? '',
          'ua': ApiEndpoints.userAgent,
        };
      }

      final response = await _client.post(
        uri,
        headers: ApiEndpoints.defaultHeaders(token: token),
        body: jsonEncode(body),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error postComment: $e');
      return false;
    }
  }

  Future<bool> voteComment(
    String commentId, {
    bool up = true,
    String? token,
  }) async {
    try {
      final uri = Uri.parse(ApiEndpoints.commentVote(commentId, up ? 'up' : 'down'));
      final response = await _client.post(
        uri,
        headers: ApiEndpoints.defaultHeaders(token: token),
        body: '{}',
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error voteComment: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> refreshWorkosToken(String refreshToken) async {
    try {
      final uri = Uri.parse(ApiEndpoints.workosAuthUrl);
      final body = {
        'client_id': ApiEndpoints.workosClientId,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      };

      final response = await _client.post(
        uri,
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Content-Type': 'application/json',
          'Origin': ApiEndpoints.origin,
          'Referer': ApiEndpoints.referer,
          'User-Agent': ApiEndpoints.userAgent,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('refreshWorkosToken failed: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error refreshWorkosToken: $e');
    }
    return null;
  }
}

class ChapterPageResult {
  final List<Chapter> chapters;
  final bool hasNext;
  final String? nextCursor;

  /// True when the request itself failed (network / non-200), as opposed to
  /// an empty page.
  final bool failed;

  const ChapterPageResult({
    required this.chapters,
    required this.hasNext,
    this.nextCursor,
    this.failed = false,
  });
}
