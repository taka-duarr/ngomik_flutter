import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/manga.dart';
import '../../models/chapter.dart';
import '../../services/shngm_api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/history_provider.dart';
import '../../widgets/manga_flag.dart';
import '../../widgets/chapter_list_tile.dart';
import '../../widgets/app_network_image.dart';
import '../reader/reader_screen.dart';

class MangaDetailScreen extends StatefulWidget {
  final String mangaId;
  final Manga? initialManga;

  const MangaDetailScreen({
    super.key,
    required this.mangaId,
    this.initialManga,
  });

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  final ShngmApiService _apiService = ShngmApiService();
  Manga? _manga;
  List<Chapter> _chapters = [];
  bool _isLoading = true;
  bool _isLoadingChapters = false;
  bool _isAscending = false;

  // Chapter Pagination State
  int _chapterPage = 1;
  int _totalChapterPages = 1;
  int _totalChapterCount = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _manga = widget.initialManga;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    final result = await _apiService.fetchMangaDetail(widget.mangaId);
    if (result != null && mounted) {
      final chResult = result['chapterResult'] as ChapterPageResult?;
      setState(() {
        _manga = result['manga'] as Manga?;
        _chapters = chResult?.chapters ?? (result['chapters'] as List<Chapter>?) ?? [];
        _chapterPage = chResult?.page ?? 1;
        _totalChapterPages = chResult?.totalPages ?? 1;
        _totalChapterCount = chResult?.totalRecords ?? _chapters.length;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _goToChapterPage(int page) async {
    if (page < 1 || page > _totalChapterPages || page == _chapterPage || _isLoadingChapters) return;
    setState(() => _isLoadingChapters = true);

    final res = await _apiService.fetchChapterPage(widget.mangaId, page: page, pageSize: _pageSize);
    if (mounted) {
      setState(() {
        _chapters = res.chapters;
        _chapterPage = res.page;
        _totalChapterPages = res.totalPages;
        _totalChapterCount = res.totalRecords;
        _isLoadingChapters = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final manga = _manga;
    final authProvider = context.watch<AuthProvider>();
    final bookmarkProvider = context.watch<BookmarkProvider>();
    final historyProvider = context.watch<HistoryProvider>();

    final isBookmarked = manga != null && bookmarkProvider.isBookmarked(manga.id);
    final lastReadChapter = manga != null ? historyProvider.getLastReadChapter(manga.id) : null;

    final sortedChapters = _isAscending ? _chapters.reversed.toList() : _chapters;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading && manga == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                // 1. Sliver App Bar with Backdrop Image
                SliverAppBar(
                  expandedHeight: 330,
                  pinned: true,
                  backgroundColor: AppColors.surface,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    if (manga != null)
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: isBookmarked ? AppColors.primary : Colors.white,
                            size: 20,
                          ),
                        ),
                        onPressed: () {
                          bookmarkProvider.toggleBookmark(manga, token: authProvider.token);
                        },
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background Blur Cover
                        AppNetworkImage(
                          imageUrl: manga?.bannerUrl?.isNotEmpty == true
                              ? manga!.bannerUrl!
                              : (manga?.coverUrl ?? ''),
                          fit: BoxFit.cover,
                          errorWidget: Container(color: AppColors.surface),
                        ),

                        // Gradient Overlays
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(0x990A0D14),
                                AppColors.background,
                              ],
                              stops: [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),

                        // Manga Floating Poster & Main Info inside Header
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Poster Box
                              Container(
                                width: 95,
                                height: 135,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: AppNetworkImage(
                                  imageUrl: manga?.coverUrl ?? '',
                                  fit: BoxFit.cover,
                                  errorWidget: const Icon(Icons.broken_image),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Title & Badges
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        if (manga != null) MangaFlag(type: manga.type),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: manga?.status.toLowerCase() == 'completed'
                                                ? AppColors.cyan.withValues(alpha: 0.2)
                                                : AppColors.emerald.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            manga?.status ?? 'Ongoing',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: manga?.status.toLowerCase() == 'completed'
                                                  ? AppColors.cyan
                                                  : AppColors.emerald,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      manga?.title ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        if ((manga?.rating ?? 0) > 0) ...[
                                          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                          const SizedBox(width: 3),
                                          Text(
                                            manga!.rating.toStringAsFixed(1),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                        ],
                                        Text(
                                          '${_totalChapterCount > 0 ? _totalChapterCount : _chapters.length} Chapter',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Action Buttons (Read / Resume / Bookmark)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _chapters.isEmpty
                                ? null
                                : () {
                                    final targetChapter = lastReadChapter != null
                                        ? _chapters.firstWhere(
                                            (c) => c.id == lastReadChapter.chapterId,
                                            orElse: () => _chapters.first,
                                          )
                                        : _chapters.first;

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ReaderScreen(
                                          chapterId: targetChapter.id,
                                          chapterNumber: targetChapter.chapterNumber,
                                          manga: manga!,
                                        ),
                                      ),
                                    );
                                  },
                            icon: Icon(
                              lastReadChapter != null ? Icons.play_arrow_rounded : Icons.menu_book_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            label: Text(
                              lastReadChapter != null
                                  ? 'Lanjut Ch. ${lastReadChapter.chapterNumber}'
                                  : 'Mulai Baca Ch. ${_chapters.isNotEmpty ? _chapters.first.chapterNumber : '1'}',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            if (manga != null) bookmarkProvider.toggleBookmark(manga, token: authProvider.token);
                          },
                          icon: Icon(
                            isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: isBookmarked ? AppColors.primary : Colors.white,
                          ),
                          label: Text(
                            isBookmarked ? 'Tersimpan' : 'Bookmark',
                            style: TextStyle(
                              color: isBookmarked ? AppColors.primary : Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isBookmarked ? AppColors.primary : AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Genres Chips
                if (manga?.genres.isNotEmpty == true)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: manga!.genres.map((g) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              g,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                // 4. Synopsis
                if (manga?.synopsis.isNotEmpty == true)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sinopsis',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            manga!.synopsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 10)),

                // 5. Chapter Header Row
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daftar Chapter (${_totalChapterCount > 0 ? _totalChapterCount : _chapters.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isAscending = !_isAscending;
                            });
                          },
                          icon: Icon(
                            _isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          label: Text(
                            _isAscending ? 'Terlama' : 'Terbaru',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 6. Chapter List
                if (_isLoadingChapters)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                  )
                else if (_chapters.isEmpty && !_isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: Text(
                          'Belum ada chapter tersedia',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final ch = sortedChapters[index];
                          final isRead = historyProvider.isChapterRead(ch.id);

                          return ChapterListTile(
                            chapter: ch,
                            manga: manga!,
                            isRead: isRead,
                          );
                        },
                        childCount: sortedChapters.length,
                      ),
                    ),
                  ),

                // 7. Standard Numbered Pagination Bar
                if (!_isLoadingChapters)
                  SliverToBoxAdapter(
                    child: _buildPaginationBar(),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  Widget _buildPaginationBar() {
    if (_totalChapterPages <= 1) return const SizedBox.shrink();

    List<int> pages = [];
    if (_totalChapterPages <= 5) {
      pages = List.generate(_totalChapterPages, (i) => i + 1);
    } else {
      pages.add(1);
      int start = (_chapterPage - 1).clamp(2, _totalChapterPages - 2);
      int end = (_chapterPage + 1).clamp(3, _totalChapterPages - 1);

      for (int i = start; i <= end; i++) {
        if (!pages.contains(i)) pages.add(i);
      }
      if (!pages.contains(_totalChapterPages)) pages.add(_totalChapterPages);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Button
          IconButton(
            onPressed: (_chapterPage > 1 && !_isLoadingChapters)
                ? () => _goToChapterPage(_chapterPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: Colors.white,
            disabledColor: AppColors.textDisabled,
            style: IconButton.styleFrom(
              backgroundColor: _chapterPage > 1 ? const Color(0xFF1E293B) : Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),

          // Numbered Page Buttons
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < pages.length; i++) ...[
                    if (i > 0 && pages[i] - pages[i - 1] > 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '...',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ),
                    GestureDetector(
                      onTap: !_isLoadingChapters && pages[i] != _chapterPage
                          ? () => _goToChapterPage(pages[i])
                          : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: pages[i] == _chapterPage ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: pages[i] == _chapterPage ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${pages[i]}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: pages[i] == _chapterPage ? FontWeight.w800 : FontWeight.w600,
                              color: pages[i] == _chapterPage ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Next Button
          IconButton(
            onPressed: (_chapterPage < _totalChapterPages && !_isLoadingChapters)
                ? () => _goToChapterPage(_chapterPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: Colors.white,
            disabledColor: AppColors.textDisabled,
            style: IconButton.styleFrom(
              backgroundColor: _chapterPage < _totalChapterPages ? const Color(0xFF1E293B) : Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
