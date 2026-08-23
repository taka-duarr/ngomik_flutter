import 'package:flutter/foundation.dart';
import '../models/reading_history.dart';
import '../services/shngm_api_service.dart';

class HistoryProvider with ChangeNotifier {
  final ShngmApiService _apiService = ShngmApiService();

  List<ReadingHistoryItem> _history = [];
  final Map<String, String> _readChapters = {};
  bool _isLoading = false;

  List<ReadingHistoryItem> get history => _history;
  int get count => _history.length;
  bool get isLoading => _isLoading;

  Future<void> init({String? token}) async {
    _history.clear();
    _readChapters.clear();
    notifyListeners();

    if (token != null && token.isNotEmpty) {
      await syncRemoteHistory(token);
    }
  }

  bool isChapterRead(String chapterId) {
    if (chapterId.isEmpty) return false;
    return _readChapters.containsKey(chapterId);
  }

  ReadingHistoryItem? getLastReadChapter(String mangaId) {
    try {
      return _history.firstWhere((h) => h.mangaId == mangaId);
    } catch (_) {
      return null;
    }
  }

  Future<void> syncRemoteHistory(String token) async {
    if (token.isEmpty) return;
    _isLoading = true;
    notifyListeners();

    try {
      final remoteList = await _apiService.fetchUserHistory(token);
      _history = remoteList;
      for (final item in remoteList) {
        if (item.chapterId.isNotEmpty && item.chapterId != '0') {
          _readChapters[item.chapterId] = item.mangaId;
        }
      }
    } catch (e) {
      debugPrint('Error syncRemoteHistory: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncMangaChapterHistory(String mangaId, String token) async {
    if (token.isEmpty) return;
    try {
      final readIds = await _apiService.fetchMangaChapterHistory(
        mangaId,
        token,
      );
      if (readIds.isNotEmpty) {
        bool hasNew = false;
        for (final chId in readIds) {
          if (!_readChapters.containsKey(chId)) {
            _readChapters[chId] = mangaId;
            hasNew = true;
          }
        }
        if (hasNew) notifyListeners();
      }
    } catch (e) {
      debugPrint('Error syncMangaChapterHistory: $e');
    }
  }

  Future<void> recordReadChapter({
    required String mangaId,
    required String mangaTitle,
    required String coverUrl,
    required String chapterId,
    required String chapterNumber,
    String? chapterTitle,
    double? userRate,
    String? token,
  }) async {
    final item = ReadingHistoryItem(
      mangaId: mangaId,
      mangaTitle: mangaTitle,
      coverUrl: coverUrl,
      chapterId: chapterId,
      chapterNumber: chapterNumber,
      chapterTitle: chapterTitle,
      userRate: userRate,
      readAt: DateTime.now(),
    );

    _history.removeWhere((h) => h.mangaId == mangaId);
    _history.insert(0, item);
    _readChapters[chapterId] = mangaId;
    notifyListeners();

    // Directly record to server API
    if (token != null && token.isNotEmpty) {
      await _apiService.addHistory(token, mangaId, chapterId);
    }
  }

  Future<void> removeHistory(String mangaId, {String? token}) async {
    _history.removeWhere((h) => h.mangaId == mangaId);
    _readChapters.removeWhere((_, mId) => mId == mangaId);
    notifyListeners();

    if (token != null && token.isNotEmpty) {
      await _apiService.removeHistory(token, mangaId);
    }
  }

  Future<void> removeHistoryItem(String mangaId, {String? token}) async {
    await removeHistory(mangaId, token: token);
  }

  Future<void> clearAllHistory({String? token}) async {
    _history.clear();
    _readChapters.clear();
    notifyListeners();
  }

  Future<void> clearHistory({String? token}) async {
    await clearAllHistory(token: token);
  }
}
