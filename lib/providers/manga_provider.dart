import 'package:flutter/foundation.dart';
import '../models/manga.dart';
import '../services/shngm_api_service.dart';

class MangaProvider with ChangeNotifier {
  final ShngmApiService _apiService = ShngmApiService();

  List<Manga> _heroManga = [];
  List<Manga> _recentManga = [];
  List<Manga> _popularManga = [];
  List<Manga> _filteredManga = [];
  List<Manga> _searchResults = [];

  bool _isLoadingHome = false;
  bool _isLoadingFiltered = false;
  bool _isLoadingSearch = false;

  String _activeFilter = 'all';

  List<Manga> get heroManga => _heroManga;
  List<Manga> get recentManga => _recentManga;
  List<Manga> get popularManga => _popularManga;
  List<Manga> get filteredManga => _filteredManga;
  List<Manga> get searchResults => _searchResults;

  bool get isLoadingHome => _isLoadingHome;
  bool get isLoadingFiltered => _isLoadingFiltered;
  bool get isLoadingSearch => _isLoadingSearch;
  String get activeFilter => _activeFilter;
  bool get isFiltered => _activeFilter != 'all';

  Future<void> loadHomeFeed({bool refresh = false}) async {
    _isLoadingHome = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        // 1. Trending for Hero Banner (Default list)
        _apiService.fetchMangaList(page: 1),
        // 2. Recently Updated (sort=latest)
        _apiService.fetchMangaList(page: 1, sort: 'latest'),
        // 3. Popular Series (sort=bookmark)
        _apiService.fetchMangaList(page: 1, sort: 'bookmark'),
      ]);

      final trending = results[0];
      final latest = results[1];
      final popular = results[2];

      _heroManga = trending.take(6).toList();
      _recentManga = latest;
      _popularManga = popular.isNotEmpty ? popular : trending;
    } catch (e) {
      debugPrint('Error loadHomeFeed: $e');
    } finally {
      _isLoadingHome = false;
      notifyListeners();
    }
  }

  Future<void> setFilter(String filter) async {
    _activeFilter = filter;
    if (filter == 'all') {
      _filteredManga = [];
      notifyListeners();
      return;
    }

    _isLoadingFiltered = true;
    notifyListeners();

    try {
      String? type;
      String? sort;
      String? format;

      if (filter == 'project') {
        type = 'project';
      } else if (filter == 'mirror') {
        type = 'mirror';
      } else if (filter == 'latest') {
        sort = 'latest';
      } else if (filter == 'popular') {
        sort = 'bookmark';
      } else if (filter == 'rating') {
        sort = 'rating';
      } else if (filter == 'manhwa') {
        format = 'manhwa';
      } else if (filter == 'manga') {
        format = 'manga';
      } else if (filter == 'manhua') {
        format = 'manhua';
      }

      final results = await _apiService.fetchMangaList(
        page: 1,
        type: type,
        sort: sort,
        format: format,
      );
      _filteredManga = results;
    } catch (e) {
      debugPrint('Error setFilter: $e');
      _filteredManga = [];
    } finally {
      _isLoadingFiltered = false;
      notifyListeners();
    }
  }

  Future<void> search(
    String query, {
    String? genre,
    String? status,
    String? type,
    String? format,
    String? sort = 'latest',
  }) async {
    if (query.trim().isEmpty && (genre == null || genre.isEmpty)) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoadingSearch = true;
    notifyListeners();

    try {
      final results = await _apiService.searchManga(
        query: query,
        genre: genre,
        status: status,
        type: type,
        format: format,
        sort: sort,
      );
      _searchResults = results;
    } catch (e) {
      debugPrint('Error search: $e');
      _searchResults = [];
    } finally {
      _isLoadingSearch = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }
}
