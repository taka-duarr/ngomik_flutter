import 'package:flutter/foundation.dart';
import '../models/reading_history.dart';
import '../services/shngm_api_service.dart';
import '../services/storage_service.dart';

class HistoryProvider with ChangeNotifier {
  final ShngmApiService _apiService = ShngmApiService();
  final StorageService _storageService = StorageService();

  List<ReadingHistoryItem> _history = [];
  Map<String, String> _readChapters = {};

  List<ReadingHistoryItem> get history => _history;
  int get count => _history.length;

  Future<void> init() async {
    _history = await _storageService.getHistory();
    _readChapters = await _storageService.getReadChapters();
    notifyListeners();
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

    // Remove existing entry for this manga
    _history.removeWhere((h) => h.mangaId == mangaId);
    // Insert at front
    _history.insert(0, item);
    await _storageService.saveHistory(_history);

    // Mark chapter as read
    _readChapters[chapterId] = mangaId;
    await _storageService.markChapterRead(chapterId, mangaId);
    notifyListeners();

    // Sync to Shinigami API in background if token present
    if (token != null && token.isNotEmpty) {
      _apiService.addHistory(token, mangaId, chapterId);
    }
  }

  Future<void> removeHistoryItem(String mangaId) async {
    _history.removeWhere((h) => h.mangaId == mangaId);
    await _storageService.saveHistory(_history);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _storageService.saveHistory(_history);
    notifyListeners();
  }
}
