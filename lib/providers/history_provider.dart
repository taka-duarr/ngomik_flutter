import 'package:flutter/foundation.dart';
import '../models/reading_history.dart';
import '../services/shngm_api_service.dart';
import '../services/storage_service.dart';

class HistoryProvider with ChangeNotifier {
  final ShngmApiService _apiService = ShngmApiService();
  final StorageService _storageService = StorageService();

  List<ReadingHistoryItem> _history = [];
  Map<String, String> _readChapters = {};
  bool _isLoading = false;

  List<ReadingHistoryItem> get history => _history;
  int get count => _history.length;
  bool get isLoading => _isLoading;

  Future<void> init({String? token}) async {
    _history = await _storageService.getHistory();
    _readChapters = await _storageService.getReadChapters();
    notifyListeners();

    if (token != null && token.isNotEmpty) {
      await syncRemoteHistory(token);
    }
  }

  bool isChapterRead(String chapterId) {
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
      if (remoteList.isNotEmpty) {
        // Remote entries take priority to overwrite any old 0-chapter cached entries
        final Map<String, ReadingHistoryItem> map = {};
        for (final item in _history) {
          map[item.mangaId] = item;
        }
        for (final item in remoteList) {
          map[item.mangaId] = item;
          if (item.chapterId.isNotEmpty) {
            _readChapters[item.chapterId] = item.mangaId;
          }
        }

        final merged = map.values.toList();
        merged.sort((a, b) => b.readAt.compareTo(a.readAt));
        _history = merged.take(100).toList();
        await _storageService.saveHistory(_history);
      }
    } catch (e) {
      debugPrint('Error syncRemoteHistory: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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
    await _storageService.saveHistory(_history);
    await _storageService.markChapterRead(chapterId, mangaId);
    notifyListeners();

    // Direct save to Shinigami Database via API if logged in
    if (token != null && token.isNotEmpty) {
      _apiService.addHistory(token, mangaId, chapterId);
    }
  }

  Future<void> removeHistoryItem(String mangaId, {String? token}) async {
    _history.removeWhere((h) => h.mangaId == mangaId);
    await _storageService.saveHistory(_history);
    notifyListeners();

    if (token != null && token.isNotEmpty) {
      _apiService.removeHistory(token, mangaId);
    }
  }

  Future<void> clearHistory() async {
    _history.clear();
    _readChapters.clear();
    await _storageService.saveHistory([]);
    notifyListeners();
  }
}
