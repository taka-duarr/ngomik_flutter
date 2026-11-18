import 'package:flutter/material.dart';
import '../models/manga.dart';
import '../services/shngm_api_service.dart';

/// Minimal paged loader for screens that own their own list (ranking,
/// updates) so they don't fight over MangaProvider's shared filter state.
class PagedMangaList extends ChangeNotifier {
  final ShngmApiService _api;
  String sort;
  final int pageSize;

  PagedMangaList({required this.sort, this.pageSize = 20, ShngmApiService? api})
      : _api = api ?? ShngmApiService();

  final List<Manga> items = [];
  int _page = 0;
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  bool hasError = false;

  Future<void> refresh() async {
    _page = 0;
    hasMore = true;
    hasError = false;
    isLoading = true;
    notifyListeners();
    try {
      final first = await _api.fetchMangaList(page: 1, pageSize: pageSize, sort: sort);
      items
        ..clear()
        ..addAll(first);
      _page = 1;
      hasMore = first.length >= pageSize;
    } catch (_) {
      hasError = true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore || !hasMore) return;
    isLoadingMore = true;
    notifyListeners();
    try {
      final next = await _api.fetchMangaList(page: _page + 1, pageSize: pageSize, sort: sort);
      if (next.isEmpty) {
        hasMore = false;
      } else {
        _page += 1;
        final known = items.map((m) => m.id).toSet();
        items.addAll(next.where((m) => !known.contains(m.id)));
        hasMore = next.length >= pageSize;
      }
    } catch (_) {
      // Keep what we have; the user can pull to refresh.
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> changeSort(String newSort) {
    if (newSort == sort) return Future.value();
    sort = newSort;
    items.clear();
    return refresh();
  }
}
