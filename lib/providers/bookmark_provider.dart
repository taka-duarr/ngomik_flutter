import 'package:flutter/foundation.dart';
import '../models/manga.dart';
import '../services/shngm_api_service.dart';

class BookmarkProvider with ChangeNotifier {
  final ShngmApiService _apiService = ShngmApiService();

  List<Manga> _bookmarks = [];
  bool _isLoading = false;

  List<Manga> get bookmarks => _bookmarks;
  int get count => _bookmarks.length;
  bool get isLoading => _isLoading;

  Future<void> init({String? token}) async {
    if (token != null && token.isNotEmpty) {
      await syncRemoteBookmarks(token);
    } else {
      _bookmarks = [];
      notifyListeners();
    }
  }

  void clear() {
    _bookmarks = [];
    notifyListeners();
  }

  bool isBookmarked(String mangaId) {
    return _bookmarks.any((m) => m.id == mangaId);
  }

  Future<bool> toggleBookmark(Manga manga, {required String? token}) async {
    if (token == null || token.isEmpty) {
      return false;
    }

    final exists = isBookmarked(manga.id);
    if (exists) {
      _bookmarks.removeWhere((m) => m.id == manga.id);
      notifyListeners();

      _apiService.removeBookmark(token, manga.id);
      return false;
    } else {
      final updatedManga = manga.copyWith(isBookmarked: true);
      _bookmarks.insert(0, updatedManga);
      notifyListeners();

      _apiService.addBookmark(token, manga.id);
      return true;
    }
  }

  Future<void> syncRemoteBookmarks(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final remote = await _apiService.fetchUserBookmarks(token);
      _bookmarks = remote.map((r) => r.copyWith(isBookmarked: true)).toList();
    } catch (e) {
      debugPrint('Error syncRemoteBookmarks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
