import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/manga.dart';
import '../../models/chapter.dart';
import '../../services/shngm_api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/history_provider.dart';
import '../../widgets/chapter_list_tile.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/google_dots_loading.dart';
import '../../widgets/liquid_glass_container.dart';
import '../../widgets/comments_section.dart';
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
  String _chapterSearchQuery = '';

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _manga = widget.initialManga;
    _fetchDetail();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToComments() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _fetchDetail() async {
    final authProvider = context.read<AuthProvider>();
    final historyProvider = context.read<HistoryProvider>();
    if (authProvider.token != null && authProvider.token!.isNotEmpty) {
      historyProvider.syncMangaChapterHistory(widget.mangaId, authProvider.token!);
    }

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

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }

  @override
  Widget build(BuildContext context) {
    final manga = _manga;
    final authProvider = context.watch<AuthProvider>();
    final bookmarkProvider = context.watch<BookmarkProvider>();
    final historyProvider = context.watch<HistoryProvider>();

    final isBookmarked = manga != null && bookmarkProvider.isBookmarked(manga.id);
    final lastReadChapter = manga != null ? historyProvider.getLastReadChapter(manga.id) : null;

    final filtered = _chapterSearchQuery.trim().isEmpty
        ? _chapters
        : _chapters.where((c) {
            final query = _chapterSearchQuery.trim().toLowerCase();
            return c.chapterNumber.toLowerCase().contains(query) ||
                (c.chapterTitle != null && c.chapterTitle!.toLowerCase().contains(query));
          }).toList();

    final sortedChapters = _isAscending ? filtered.reversed.toList() : filtered;
    final latestChapter = _chapters.isNotEmpty ? _chapters.first : null;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading && manga == null
          ? const Center(child: GoogleDotsLoading(dotSize: 13, jumpHeight: 18))
          : Stack(
              children: [
                // 1. FULL PAGE CLEAR POSTER BACKGROUND
                Positioned.fill(
                  child: AppNetworkImage(
                    imageUrl: manga?.coverUrl ?? '',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorWidget: Container(color: AppColors.background),
                  ),
                ),

                // 2. SMOOTH GRADIENT OVERLAY (Clear at top for poster view, fades to dark below)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.45),
                          AppColors.background.withValues(alpha: 0.94),
                          AppColors.background,
                        ],
                        stops: const [0.0, 0.22, 0.44, 0.65, 0.95],
                      ),
                    ),
                  ),
                ),

                // 3. MAIN SCROLLABLE CONTENT WITH LIQUID GLASS CARDS
                CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Top App Bar with back, sort, and bookmark (Liquid Glass buttons)
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      pinned: true,
                      leading: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: LiquidGlassContainer(
                          borderRadius: 12,
                          blur: 16,
                          color: Colors.black.withValues(alpha: 0.5),
                          onTap: () => Navigator.pop(context),
                          child: const Center(
                            child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 19),
                          ),
                        ),
                      ),
                      actions: [
                        // Sort Button (☰)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: LiquidGlassContainer(
                            borderRadius: 12,
                            blur: 16,
                            color: Colors.black.withValues(alpha: 0.5),
                            onTap: () {
                              setState(() {
                                _isAscending = !_isAscending;
                              });
                            },
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.menu_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Bookmark Button (🔖)
                        if (manga != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: LiquidGlassContainer(
                              borderRadius: 12,
                              blur: 16,
                              color: Colors.black.withValues(alpha: 0.5),
                              onTap: () {
                                bookmarkProvider.toggleBookmark(manga, token: authProvider.token);
                              },
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Icon(
                                  isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                  color: isBookmarked ? AppColors.primary : Colors.white,
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),

                        // Comment Button (💬) - Scroll down to comments
                        if (manga != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: LiquidGlassContainer(
                              borderRadius: 12,
                              blur: 16,
                              color: Colors.black.withValues(alpha: 0.5),
                              onTap: _scrollToComments,
                              child: const SizedBox(
                                width: 40,
                                height: 40,
                                child: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: AppColors.cyan,
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 14),
                      ],
                    ),

                    // Top Poster Spacing (Allows user to enjoy full poster art above)
                    SliverToBoxAdapter(
                      child: SizedBox(height: screenHeight * 0.34),
                    ),

                    // Top Header Section: Badges, Title, Author
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Column(
                          children: [
                            // Badges Row (Centered Liquid Glass Pills: Flag, Status, Rating, Views)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Flag Liquid Glass Pill
                                  LiquidGlassContainer(
                                    borderRadius: 20,
                                    blur: 14,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    color: Colors.black.withValues(alpha: 0.5),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          manga?.type.toLowerCase().contains('manhua') == true
                                              ? '🇨🇳'
                                              : (manga?.type.toLowerCase().contains('manga') == true ? '🇯🇵' : '🇰🇷'),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          manga?.type.isNotEmpty == true ? manga!.type : 'Manhua',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Status Liquid Glass Pill
                                  LiquidGlassContainer(
                                    borderRadius: 20,
                                    blur: 14,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    color: const Color(0x66064E3B),
                                    border: Border.all(color: AppColors.emerald.withValues(alpha: 0.6)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF34D399),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          manga?.status ?? 'Ongoing',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF34D399),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Rating Liquid Glass Pill
                                  LiquidGlassContainer(
                                    borderRadius: 20,
                                    blur: 14,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    color: Colors.black.withValues(alpha: 0.5),
                                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                                        const SizedBox(width: 4),
                                        Text(
                                          (manga?.rating ?? 0) > 0 ? manga!.rating.toStringAsFixed(1) : '8.6',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Views Liquid Glass Pill
                                  LiquidGlassContainer(
                                    borderRadius: 20,
                                    blur: 14,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    color: const Color(0x66312E81),
                                    border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.5)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.visibility_rounded, color: Color(0xFF818CF8), size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatViews(manga?.viewCount ?? 74100000),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Centered Title
                            Text(
                              manga?.title ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Centered Author
                            Text(
                              'by ${manga?.author?.isNotEmpty == true ? manga!.author : 'Unknown Author'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // LIQUID GLASS SINOPSIS BOX
                    if (manga?.synopsis.isNotEmpty == true)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: LiquidGlassContainer(
                            borderRadius: 22,
                            blur: 24,
                            color: Colors.white.withValues(alpha: 0.08),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sinopsis',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  manga!.synopsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white.withValues(alpha: 0.88),
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // LIQUID GLASS LATEST CHAPTER CARD (BARU)
                    if (latestChapter != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: LiquidGlassContainer(
                            borderRadius: 18,
                            blur: 20,
                            color: const Color(0x882E236C),
                            border: Border.all(
                              color: const Color(0x99818CF8),
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReaderScreen(
                                    chapterId: latestChapter.id,
                                    chapterNumber: latestChapter.chapterNumber,
                                    manga: manga!,
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Chapter ${latestChapter.chapterNumber}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const Text(
                                  'BARU',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // LIQUID GLASS KOMENTAR KOMIK BANNER - Scroll down to comments
                    if (manga != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: LiquidGlassContainer(
                            borderRadius: 16,
                            blur: 18,
                            color: const Color(0x550D111A),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            onTap: _scrollToComments,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.cyan.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        color: AppColors.cyan,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Komentar & Diskusi',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Bagikan pendapatmu tentang komik ini',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // LIQUID GLASS SEARCH CHAPTER BAR
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: LiquidGlassContainer(
                          borderRadius: 16,
                          blur: 16,
                          height: 46,
                          color: Colors.black.withValues(alpha: 0.4),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1.0,
                          ),
                          child: Center(
                            child: TextField(
                              onChanged: (v) => setState(() => _chapterSearchQuery = v),
                              style: const TextStyle(fontSize: 13, color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Cari nomor chapter (contoh: 100, 50)...',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                                suffixIcon: _chapterSearchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.white70),
                                        onPressed: () => setState(() => _chapterSearchQuery = ''),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Chapter List Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text(
                          'Daftar Chapter (${_totalChapterCount > 0 ? _totalChapterCount : _chapters.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Chapter List Stream (Cards with Background Image)
                    if (_isLoadingChapters)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: GoogleDotsLoading(dotSize: 10, jumpHeight: 14),
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

                    // LIQUID GLASS NUMBERED PAGINATION BAR
                    if (!_isLoadingChapters)
                      SliverToBoxAdapter(
                        child: _buildPaginationBar(),
                      ),

                    // EMBEDDED MANGA COMMENTS & DISCUSSION SECTION
                    if (manga != null)
                      SliverToBoxAdapter(
                        child: CommentsSection(
                          path: 'series/${manga.id}',
                          title: manga.title,
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),

                // 4. FLOATING ACTION BUTTON (▶ MULAI BACA / LANJUT BACA)
                if (_chapters.isNotEmpty && manga != null)
                  Positioned(
                    right: 16,
                    bottom: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.6),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final targetChapter = lastReadChapter != null
                              ? _chapters.firstWhere(
                                  (c) => c.id == lastReadChapter.chapterId,
                                  orElse: () => _chapters.last,
                                )
                              : _chapters.last;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReaderScreen(
                                chapterId: targetChapter.id,
                                chapterNumber: targetChapter.chapterNumber,
                                manga: manga,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          lastReadChapter != null ? 'Lanjut Baca' : 'Mulai Baca',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildPaginationBar() {
    if (_totalChapterPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // First Page Button (≪)
          _buildPaginationBtn(
            icon: Icons.keyboard_double_arrow_left_rounded,
            enabled: _chapterPage > 1 && !_isLoadingChapters,
            onTap: () => _goToChapterPage(1),
          ),
          const SizedBox(width: 8),

          // Previous Page Button (‹)
          _buildPaginationBtn(
            icon: Icons.chevron_left_rounded,
            enabled: _chapterPage > 1 && !_isLoadingChapters,
            onTap: () => _goToChapterPage(_chapterPage - 1),
          ),
          const SizedBox(width: 8),

          // Page Pill ( 1 / 91 )
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_chapterPage',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  ' / $_totalChapterPages',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Next Page Button (›)
          _buildPaginationBtn(
            icon: Icons.chevron_right_rounded,
            enabled: _chapterPage < _totalChapterPages && !_isLoadingChapters,
            onTap: () => _goToChapterPage(_chapterPage + 1),
          ),
          const SizedBox(width: 8),

          // Last Page Button (≫)
          _buildPaginationBtn(
            icon: Icons.keyboard_double_arrow_right_rounded,
            enabled: _chapterPage < _totalChapterPages && !_isLoadingChapters,
            onTap: () => _goToChapterPage(_totalChapterPages),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: enabled ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? Colors.white.withValues(alpha: 0.20) : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 18,
            color: enabled ? Colors.white : Colors.white30,
          ),
        ),
      ),
    );
  }
}
