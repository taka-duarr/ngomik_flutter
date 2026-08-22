import 'package:flutter/foundation.dart';
import '../models/manga.dart';
import '../services/shngm_api_service.dart';
import '../services/storage_service.dart';

class BookmarkProvider with ChangeNotifier {
  final ShngmApiService _apiService = ShngmApiService();
  final StorageService _storageService = StorageService();

  List<Manga> _bookmarks = [];
  bool _isLoading = false;

  List<Manga> get bookmarks => _bookmarks;
  int get count => _bookmarks.length;
  bool get isLoading => _isLoading;

  Future<void> init({String? token}) async {
    _bookmarks = await _storageService.getBookmarks();
    notifyListeners();

    if (token != null && token.isNotEmpty) {
      await syncRemoteBookmarks(token);
    }
  }

  bool isBookmarked(String mangaId) {
    return _bookmarks.any((m) => m.id == mangaId);
  }

  Future<bool> toggleBookmark(Manga manga, {String? token}) async {
    final exists = isBookmarked(manga.id);
    if (exists) {
      _bookmarks.removeWhere((m) => m.id == manga.id);
      await _storageService.saveBookmarks(_bookmarks);
      notifyListeners();

      if (token != null && token.isNotEmpty) {
        _apiService.removeBookmark(token, manga.id);
      }
      return false;
    } else {
      final updatedManga = manga.copyWith(isBookmarked: true);
      _bookmarks.insert(0, updatedManga);
      await _storageService.saveBookmarks(_bookmarks);
      notifyListeners();

      if (token != null && token.isNotEmpty) {
        _apiService.addBookmark(token, manga.id);
      }
      return true;
    }
  }

  Future<void> syncRemoteBookmarks(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final remote = await _apiService.fetchUserBookmarks(token);
      if (remote.isNotEmpty) {
        final Map<String, Manga> map = {};
        for (var b in _bookmarks) {
          map[b.id] = b;
        }
        for (var r in remote) {
          map[r.id] = r.copyWith(isBookmarked: true);
        }
        _bookmarks = map.values.toList();
        await _storageService.saveBookmarks(_bookmarks);
      }
    } catch (e) {
      debugPrint('Error syncRemoteBookmarks: ');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
