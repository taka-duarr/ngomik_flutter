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

  // Pagination state for Popular (Home)
  int _popularPage = 1;
  bool _hasMorePopular = true;
  bool _isLoadingMorePopular = false;

  // Pagination state for Filtered
  int _filteredPage = 1;
  bool _hasMoreFiltered = true;
  bool _isLoadingMoreFiltered = false;

  // Pagination state for Search
  int _searchPage = 1;
  bool _hasMoreSearch = true;
  bool _isLoadingMoreSearch = false;
  String _lastSearchQuery = '';
  String? _lastSearchGenre;
  String? _lastSearchStatus;
  String? _lastSearchType;
  String? _lastSearchFormat;
  String? _lastSearchSort = 'latest';

  String _activeFilter = 'all';

  List<Manga> get heroManga => _heroManga;
  List<Manga> get recentManga => _recentManga;
  List<Manga> get popularManga => _popularManga;
  List<Manga> get filteredManga => _filteredManga;
  List<Manga> get searchResults => _searchResults;

  bool get isLoadingHome => _isLoadingHome;
  bool get isLoadingFiltered => _isLoadingFiltered;
  bool get isLoadingSearch => _isLoadingSearch;

  bool get isLoadingMorePopular => _isLoadingMorePopular;
  bool get hasMorePopular => _hasMorePopular;

  bool get isLoadingMoreFiltered => _isLoadingMoreFiltered;
  bool get hasMoreFiltered => _hasMoreFiltered;

  bool get isLoadingMoreSearch => _isLoadingMoreSearch;
  bool get hasMoreSearch => _hasMoreSearch;

  String get activeFilter => _activeFilter;
  bool get isFiltered => _activeFilter != 'all';

  Future<void> loadHomeFeed({bool refresh = false}) async {
    _isLoadingHome = true;
    _popularPage = 1;
    _hasMorePopular = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        // 1. Official Recommendation List for Hero Banner
        _apiService.fetchHomeHeroManga(),
        // 2. Recently Updated (sort=latest)
        _apiService.fetchMangaList(page: 1, pageSize: 24, sort: 'latest'),
        // 3. Popular Series (sort=bookmark)
        _apiService.fetchMangaList(page: 1, pageSize: 24, sort: 'bookmark'),
      ]);

      final heroList = results[0];
      final latest = results[1];
      final popular = results[2];

      _heroManga = heroList.isNotEmpty
          ? heroList.take(10).toList()
          : (popular.isNotEmpty ? popular.take(6).toList() : latest.take(6).toList());
      _recentManga = latest;
      _popularManga = popular.isNotEmpty ? popular : latest;
      _hasMorePopular = _popularManga.isNotEmpty;
    } catch (e) {
      debugPrint('Error loadHomeFeed: $e');
    } finally {
      _isLoadingHome = false;
      notifyListeners();
    }
  }

  /// Appends titles not already in [into]. Rankings can shift between two
  /// requests, so a page boundary may repeat an item; never show it twice.
  static void _appendUnique(List<Manga> into, List<Manga> more) {
    final known = into.map((m) => m.id).toSet();
    into.addAll(more.where((m) => known.add(m.id)));
  }

  Future<void> loadMorePopular() async {
    if (_isLoadingMorePopular || !_hasMorePopular || _isLoadingHome) return;
    _isLoadingMorePopular = true;
    notifyListeners();

    try {
      final nextPage = _popularPage + 1;
      final results = await _apiService.fetchMangaList(page: nextPage, pageSize: 24, sort: 'bookmark');

      if (results.isEmpty) {
        _hasMorePopular = false;
      } else {
        _popularPage = nextPage;
        _appendUnique(_popularManga, results);
        _hasMorePopular = results.isNotEmpty;
      }
    } catch (e) {
      debugPrint('Error loadMorePopular: $e');
    } finally {
      _isLoadingMorePopular = false;
      notifyListeners();
    }
  }

  Map<String, String?> _parseFilterParams(String filter) {
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

    return {'type': type, 'sort': sort, 'format': format};
  }

  Future<void> setFilter(String filter) async {
    _activeFilter = filter;
    _filteredPage = 1;
    _hasMoreFiltered = true;

    if (filter == 'all') {
      _filteredManga = [];
      notifyListeners();
      return;
    }

    _isLoadingFiltered = true;
    notifyListeners();

    try {
      final params = _parseFilterParams(filter);
      final results = await _apiService.fetchMangaList(
        page: 1,
        pageSize: 24,
        type: params['type'],
        sort: params['sort'],
        format: params['format'],
      );
      _filteredManga = results;
      _hasMoreFiltered = results.isNotEmpty;
    } catch (e) {
      debugPrint('Error setFilter: $e');
      _filteredManga = [];
    } finally {
      _isLoadingFiltered = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreFiltered() async {
    if (_isLoadingMoreFiltered || !_hasMoreFiltered || _isLoadingFiltered || _activeFilter == 'all') return;
    _isLoadingMoreFiltered = true;
    notifyListeners();

    try {
      final nextPage = _filteredPage + 1;
      final params = _parseFilterParams(_activeFilter);
      final results = await _apiService.fetchMangaList(
        page: nextPage,
        pageSize: 24,
        type: params['type'],
        sort: params['sort'],
        format: params['format'],
      );

      if (results.isEmpty) {
        _hasMoreFiltered = false;
      } else {
        _filteredPage = nextPage;
        _appendUnique(_filteredManga, results);
        _hasMoreFiltered = results.isNotEmpty;
      }
    } catch (e) {
      debugPrint('Error loadMoreFiltered: $e');
    } finally {
      _isLoadingMoreFiltered = false;
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
    _lastSearchQuery = query;
    _lastSearchGenre = genre;
    _lastSearchStatus = status;
    _lastSearchType = type;
    _lastSearchFormat = format;
    _lastSearchSort = sort;
    _searchPage = 1;
    _hasMoreSearch = true;

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
        page: 1,
        pageSize: 24,
        genre: genre,
        status: status,
        type: type,
        format: format,
        sort: sort,
      );
      _searchResults = results;
      _hasMoreSearch = results.isNotEmpty;
    } catch (e) {
      debugPrint('Error search: $e');
      _searchResults = [];
    } finally {
      _isLoadingSearch = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreSearch() async {
    if (_isLoadingMoreSearch || !_hasMoreSearch || _isLoadingSearch) return;
    _isLoadingMoreSearch = true;
    notifyListeners();

    try {
      final nextPage = _searchPage + 1;
      final results = await _apiService.searchManga(
        query: _lastSearchQuery,
        page: nextPage,
        pageSize: 24,
        genre: _lastSearchGenre,
        status: _lastSearchStatus,
        type: _lastSearchType,
        format: _lastSearchFormat,
        sort: _lastSearchSort,
      );

      if (results.isEmpty) {
        _hasMoreSearch = false;
      } else {
        _searchPage = nextPage;
        _appendUnique(_searchResults, results);
        _hasMoreSearch = results.isNotEmpty;
      }
    } catch (e) {
      debugPrint('Error loadMoreSearch: $e');
    } finally {
      _isLoadingMoreSearch = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    _lastSearchQuery = '';
    _hasMoreSearch = false;
    notifyListeners();
  }
}
