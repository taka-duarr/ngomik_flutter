import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/chapter.dart';
import 'shngm_api_service.dart';

/// Page-by-page navigation over the cursor-paginated chapter API.
///
/// The API only hands out a "next" cursor, so this remembers the cursor that
/// started every page it has visited. That gives working Next / Prev / First
/// buttons. There is no way to jump straight to page N, and no exact total;
/// [estimatedTotalPages] is derived from the highest chapter number instead.
///
/// Sort order and the chapter-number search are applied by the server, so
/// they cover every page, not just the one on screen.
class ChapterPager extends ChangeNotifier {
  static const int defaultLimit = 24;

  final String mangaId;
  final int limit;
  final ShngmApiService _api;

  ChapterPager({
    required this.mangaId,
    this.limit = defaultLimit,
    ShngmApiService? api,
  }) : _api = api ?? ShngmApiService();

  List<Chapter> chapters = const [];
  bool isLoading = false;
  bool failed = false;
  bool ascending = false;
  String search = '';

  /// 0-based index of the page on screen.
  int pageIndex = 0;
  bool hasNext = false;

  /// Cursor that starts each visited page; index 0 is always null.
  final List<String?> _cursors = [null];

  /// Highest chapter number seen on an unfiltered newest-first first page.
  double? _maxChapterNumber;

  int _requestId = 0;
  Timer? _searchDebounce;

  int get pageNumber => pageIndex + 1;
  bool get hasPrev => pageIndex > 0;
  bool get isSearching => search.trim().isNotEmpty;

  /// Rough total chapter count (by number), or null when unknown.
  int? get estimatedTotalChapters => _maxChapterNumber?.ceil();

  int? get estimatedTotalPages {
    final total = estimatedTotalChapters;
    if (total == null || isSearching) return null;
    final pages = (total / limit).ceil();
    // Never show an estimate smaller than what we've already reached.
    return pages < pageNumber + (hasNext ? 1 : 0) ? null : pages;
  }

  /// Use a first page that was already fetched (e.g. alongside the detail).
  void seed(ChapterPageResult first) {
    chapters = first.chapters;
    hasNext = first.hasNext;
    failed = first.failed;
    pageIndex = 0;
    _cursors
      ..clear()
      ..add(null);
    if (first.hasNext) _cursors.add(first.nextCursor);
    _rememberMax(first.chapters);
    notifyListeners();
  }

  Future<void> loadFirst() => _load(0);

  Future<void> next() async {
    if (!hasNext || isLoading) return;
    await _load(pageIndex + 1);
  }

  Future<void> prev() async {
    if (!hasPrev || isLoading) return;
    await _load(pageIndex - 1);
  }

  Future<void> first() async {
    if (pageIndex == 0 || isLoading) return;
    await _load(0);
  }

  Future<void> setAscending(bool value) async {
    if (value == ascending) return;
    ascending = value;
    _reset();
    await _load(0);
  }

  /// Debounced server-side search by chapter number.
  void setSearch(String value) {
    if (value == search) return;
    search = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _reset();
      _load(0);
    });
  }

  void _reset() {
    pageIndex = 0;
    _cursors
      ..clear()
      ..add(null);
  }

  Future<void> _load(int index) async {
    if (index >= _cursors.length) return;
    final id = ++_requestId;
    isLoading = true;
    notifyListeners();

    final res = await _api.fetchChapterPage(
      mangaId,
      cursor: _cursors[index],
      limit: limit,
      ascending: ascending,
      search: search,
    );
    // A newer request (e.g. another keystroke) superseded this one.
    if (id != _requestId) return;

    isLoading = false;
    failed = res.failed;
    if (!res.failed) {
      chapters = res.chapters;
      pageIndex = index;
      hasNext = res.hasNext;
      if (res.hasNext) {
        if (_cursors.length > index + 1) {
          _cursors[index + 1] = res.nextCursor;
        } else {
          _cursors.add(res.nextCursor);
        }
      }
      if (index == 0 && !ascending && !isSearching) _rememberMax(res.chapters);
    }
    notifyListeners();
  }

  void _rememberMax(List<Chapter> list) {
    if (ascending || isSearching || list.isEmpty) return;
    for (final c in list) {
      final n = double.tryParse(c.chapterNumber);
      if (n != null && (_maxChapterNumber == null || n > _maxChapterNumber!)) {
        _maxChapterNumber = n;
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
