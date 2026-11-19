import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../models/manga.dart';
import '../../models/chapter.dart';
import '../../services/chapter_pager.dart';
import '../../services/shngm_api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/history_provider.dart';
import '../../widgets/sakuga_search_field.dart';
import '../../widgets/chapter_list_tile.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/baked_blur_image.dart';
import '../../widgets/glass_widgets.dart';
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
  bool _isLoading = true;
  bool _synopsisExpanded = false;
  bool _openingFirst = false;

  // Chapter list: cursor-paginated, sorted & searched server-side.
  late final ChapterPager _pager = ChapterPager(mangaId: widget.mangaId)
    ..addListener(_onPagerChanged);

  /// Newest chapter, taken from the first newest-first page.
  Chapter? _latestChapter;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _chapterSearchCtrl = TextEditingController();

  /// True once the header has scrolled under the app bar — drives the
  /// frosted bar + collapsed title without rebuilding the whole page.
  final ValueNotifier<bool> _collapsed = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _manga = widget.initialManga;
    _scrollController.addListener(_onScroll);
    _fetchDetail();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _chapterSearchCtrl.dispose();
    _collapsed.dispose();
    _pager
      ..removeListener(_onPagerChanged)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final collapsed = _scrollController.hasClients && _scrollController.offset > 120;
    if (collapsed != _collapsed.value) _collapsed.value = collapsed;
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
        _latestChapter = (chResult?.chapters.isNotEmpty ?? false) ? chResult!.chapters.first : null;
        _isLoading = false;
      });
      if (chResult != null) _pager.seed(chResult);
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onPagerChanged() {
    if (mounted) setState(() {});
  }

  final GlobalKey _chapterHeaderKey = GlobalKey();

  /// Runs a page change, then brings the top of the chapter list back into
  /// view (just under the pinned app bar) so the new page reads from its start.
  Future<void> _changePage(Future<void> Function() action) async {
    await action();
    if (!mounted || !_scrollController.hasClients) return;
    final box = _chapterHeaderKey.currentContext?.findRenderObject();
    if (box == null || !box.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    // Scroll offset that puts the header at the top of the viewport, minus
    // the pinned app bar that overlays it.
    final reveal = viewport.getOffsetToReveal(box, 0.0).offset;
    final topInset = MediaQuery.of(context).padding.top + 60;
    final target = reveal - topInset;
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  /// Opens chapter 1, fetched on demand: the visible page may not contain it.
  Future<void> _openFirstChapter(Manga manga) async {
    if (_openingFirst) return;
    setState(() => _openingFirst = true);
    final first = await _apiService.fetchFirstChapter(widget.mangaId);
    if (!mounted) return;
    setState(() => _openingFirst = false);
    if (first != null) {
      _openReader(manga, first.id, first.chapterNumber);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat chapter pertama. Coba lagi.')),
      );
    }
  }

  void _openReader(Manga manga, String chapterId, String chapterNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          chapterId: chapterId,
          chapterNumber: chapterNumber,
          manga: manga,
        ),
      ),
    );
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
    final lastRead = manga != null ? historyProvider.getLastReadChapter(manga.id) : null;

    final chapters = _pager.chapters;
    final latestChapter = _latestChapter;

    void toggleBookmark() {
      if (manga != null) bookmarkProvider.toggleBookmark(manga, token: authProvider.token);
    }

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _isLoading && manga == null
            ? const Center(child: GoogleDotsLoading(dotSize: 13, jumpHeight: 18))
            : Stack(
                children: [
                  // 1. Ambient blurred cover — the colour source for the glass above it.
                  if (manga != null && manga.coverUrl.isNotEmpty)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 520,
                      child: _AmbientCover(imageUrl: manga.coverUrl),
                    ),

                  // 2. Content
                  CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      _buildAppBar(manga, isBookmarked, toggleBookmark),

                      if (manga != null)
                        SliverToBoxAdapter(
                          child: _buildHeaderCard(
                            manga,
                            isBookmarked: isBookmarked,
                            onBookmark: toggleBookmark,
                            lastReadId: lastRead?.chapterId,
                            lastReadNumber: lastRead?.chapterNumber,
                          ),
                        ),

                      if (manga?.synopsis.isNotEmpty == true)
                        SliverToBoxAdapter(child: _buildSynopsis(manga!.synopsis)),

                      if (manga != null)
                        SliverToBoxAdapter(
                          child: _buildQuickRow(manga, latestChapter),
                        ),

                      // ── Chapter list ─────────────────────────────────────
                      SliverToBoxAdapter(
                        key: _chapterHeaderKey,
                        child: SectionHeader(
                          title: 'Daftar Chapter',
                          padding: const EdgeInsets.fromLTRB(20, 8, 12, 10),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GlassTag(
                                label: _pager.estimatedTotalChapters != null
                                    ? '±${_pager.estimatedTotalChapters}'
                                    : '${chapters.length}',
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                onPressed: () => _pager.setAscending(!_pager.ascending),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: const Size(0, 36),
                                ),
                                icon: Icon(
                                  _pager.ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  _pager.ascending ? 'Terlama' : 'Terbaru',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: SakugaSearchField(
                            controller: _chapterSearchCtrl,
                            hintText: 'Cari chapter…  contoh: 120',
                            onChanged: (v) => setState(() => _pager.setSearch(v)),
                            showClear: _chapterSearchCtrl.text.isNotEmpty,
                            onClear: () {
                              _chapterSearchCtrl.clear();
                              setState(() => _pager.setSearch(''));
                            },
                          ),
                        ),
                      ),

                      // Spinner only on a cold load; when switching pages the
                      // old list stays (dimmed) so the layout doesn't jump.
                      if (_pager.isLoading && chapters.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: GoogleDotsLoading(dotSize: 10, jumpHeight: 14)),
                          ),
                        )
                      else if (chapters.isEmpty && !_isLoading)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                            child: Center(
                              child: Text(
                                _pager.failed
                                    ? 'Gagal memuat chapter. Coba lagi nanti.'
                                    : _pager.isSearching
                                        ? 'Chapter "${_pager.search.trim()}" tidak ditemukan'
                                        : 'Belum ada chapter tersedia',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverOpacity(
                            opacity: _pager.isLoading ? 0.4 : 1,
                            sliver: SliverIgnorePointer(
                              ignoring: _pager.isLoading,
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final ch = chapters[index];
                                    return ChapterListTile(
                                      chapter: ch,
                                      manga: manga!,
                                      isRead: historyProvider.isChapterRead(ch.id),
                                      isLastRead: lastRead?.chapterId == ch.id,
                                    );
                                  },
                                  childCount: chapters.length,
                                ),
                              ),
                            ),
                          ),
                        ),

                      SliverToBoxAdapter(child: _buildPaginationBar()),

                      if (manga != null)
                        SliverToBoxAdapter(
                          child: CommentsSection(
                            path: ApiEndpoints.mangaPageKey(manga.id),
                            title: manga.title,
                            mangaId: manga.id,
                          ),
                        ),

                      SliverToBoxAdapter(
                        child: SizedBox(height: 32 + MediaQuery.of(context).padding.bottom),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────

  Widget _buildAppBar(Manga? manga, bool isBookmarked, VoidCallback onBookmark) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      toolbarHeight: 60,
      flexibleSpace: ValueListenableBuilder<bool>(
        valueListenable: _collapsed,
        builder: (context, collapsed, _) {
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: collapsed ? 1 : 0,
            child: ClipRect(
              child: BackdropFilter.grouped(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.navBackground,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            GlassIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Kembali',
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                manga?.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (manga != null) ...[
              const SizedBox(width: 12),
              GlassIconButton(
                icon: Icons.chat_bubble_outline_rounded,
                tooltip: 'Komentar',
                onTap: _scrollToComments,
              ),
              const SizedBox(width: 8),
              GlassIconButton(
                icon: isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                tooltip: isBookmarked ? 'Hapus bookmark' : 'Bookmark',
                active: isBookmarked,
                onTap: onBookmark,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header: cover + metadata + CTA ────────────────────────────────────

  Widget _buildHeaderCard(
    Manga manga, {
    required bool isBookmarked,
    required VoidCallback onBookmark,
    String? lastReadId,
    String? lastReadNumber,
  }) {
    final lowerType = manga.type.toLowerCase();
    final flag = lowerType.contains('manhua')
        ? '🇨🇳'
        : (lowerType.contains('manga') ? '🇯🇵' : '🇰🇷');
    final isCompleted = manga.status.toLowerCase() == 'completed';
    final hasResume = lastReadId != null && lastReadId.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: LiquidGlassContainer(
        color: const Color(0x991C2038),
        borderRadius: AppRadius.xl,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover
                Container(
                  width: 112,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: const [
                      BoxShadow(color: Color(0x59101225), blurRadius: 16, offset: Offset(0, 8)),
                    ],
                  ),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AppNetworkImage(
                    imageUrl: manga.coverUrl,
                    fit: BoxFit.cover,
                    errorWidget: Container(color: AppColors.card),
                  ),
                ),
                const SizedBox(width: 14),

                // Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        manga.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _InfoLine(
                        label: 'Penulis',
                        value: manga.author?.isNotEmpty == true ? manga.author! : '-',
                      ),
                      _InfoLine(label: 'Tipe', value: '$flag  ${manga.type.isNotEmpty ? manga.type : 'Komik'}'),
                      _InfoLine(
                        label: 'Status',
                        value: manga.status.isNotEmpty ? manga.status : 'Ongoing',
                        valueColor: isCompleted ? AppColors.accent : AppColors.emerald,
                      ),
                      if (manga.viewCount > 0)
                        _InfoLine(label: 'Dilihat', value: _formatViews(manga.viewCount)),
                      if (manga.bookmarkCount > 0)
                        _InfoLine(label: 'Disimpan', value: '${_formatViews(manga.bookmarkCount)} pengguna'),
                      if (manga.rating > 0) ...[
                        const SizedBox(height: 4),
                        _StarRating(rating: manga.rating),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (manga.genres.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: manga.genres.take(8).map((g) => GlassTag(label: g, filled: true)).toList(),
              ),
            ],

            if (_latestChapter != null || _pager.chapters.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (hasResume) {
                            _openReader(manga, lastReadId, lastReadNumber ?? '');
                          } else {
                            _openFirstChapter(manga);
                          }
                        },
                        icon: _openingFirst
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 22),
                        label: Text(
                          hasResume && (lastReadNumber?.isNotEmpty ?? false)
                              ? 'Lanjut Ch. $lastReadNumber'
                              : 'Mulai Baca',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GlassIconButton(
                    icon: isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                    tooltip: isBookmarked ? 'Hapus bookmark' : 'Bookmark',
                    size: 46,
                    active: isBookmarked,
                    onTap: onBookmark,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Synopsis ──────────────────────────────────────────────────────────

  Widget _buildSynopsis(String synopsis) {
    final isLong = synopsis.length > 220;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: LiquidGlassContainer(
        borderRadius: AppRadius.lg,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        boxShadow: const [],
        onTap: isLong ? () => setState(() => _synopsisExpanded = !_synopsisExpanded) : null,
        scaleFactor: 0.99,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sinopsis',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Text(
                synopsis,
                maxLines: _synopsisExpanded ? null : 4,
                overflow: _synopsisExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.55),
              ),
            ),
            if (isLong)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _synopsisExpanded ? 'Tutup' : 'Selengkapnya',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Latest chapter + comments shortcuts ───────────────────────────────

  Widget _buildQuickRow(Manga manga, Chapter? latest) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          if (latest != null) ...[
            Expanded(
              child: _QuickTile(
                icon: Icons.fiber_new_rounded,
                iconColor: AppColors.primaryLight,
                title: 'Ch. ${latest.chapterNumber}',
                subtitle: 'Chapter terbaru',
                onTap: () => _openReader(manga, latest.id, latest.chapterNumber),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: _QuickTile(
              icon: Icons.forum_outlined,
              iconColor: AppColors.accent,
              title: 'Komentar',
              subtitle: 'Diskusi pembaca',
              onTap: _scrollToComments,
            ),
          ),
        ],
      ),
    );
  }

  // ── Pagination ────────────────────────────────────────────────────────

  Widget _buildPaginationBar() {
    if (!_pager.hasPrev && !_pager.hasNext) return const SizedBox.shrink();

    final busy = _pager.isLoading;
    final estPages = _pager.estimatedTotalPages;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPaginationBtn(
            icon: Icons.first_page_rounded,
            tooltip: 'Halaman pertama',
            enabled: _pager.hasPrev && !busy,
            onTap: () => _changePage(_pager.first),
          ),
          const SizedBox(width: 8),
          _buildPaginationBtn(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Sebelumnya',
            enabled: _pager.hasPrev && !busy,
            onTap: () => _changePage(_pager.prev),
          ),
          const SizedBox(width: 8),
          LiquidGlassContainer(
            borderRadius: AppRadius.md,
            boxShadow: const [],
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Hal. ',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  TextSpan(
                    text: '${_pager.pageNumber}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (estPages != null)
                    TextSpan(
                      text: ' / ±$estPages',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildPaginationBtn(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Berikutnya',
            enabled: _pager.hasNext && !busy,
            onTap: () => _changePage(_pager.next),
          ),
          const SizedBox(width: 8),
          // The API can't jump to the last page; the oldest chapters are
          // page 1 of the reversed order instead.
          _buildPaginationBtn(
            icon: Icons.last_page_rounded,
            tooltip: 'Chapter terlama',
            enabled: !busy && (!_pager.ascending || _pager.hasPrev),
            onTap: () => _changePage(() => _pager.ascending ? _pager.first() : _pager.setAscending(true)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBtn({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GlassIconButton(
        icon: icon,
        tooltip: tooltip,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

/// Heavily blurred cover art that fades out downward. Rasterised once and
/// cached by the RepaintBoundary, so scrolling the page above it stays cheap.
/// Blurred cover behind the header. Baked once into a small bitmap (see
/// [BakedBlurImage]) so scrolling over it costs nothing extra per frame.
class _AmbientCover extends StatelessWidget {
  final String imageUrl;

  const _AmbientCover({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: BakedBlurImage(imageUrl: imageUrl, sigma: 6, opacity: 0.75, fadeStart: 0.45),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoLine({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(color: AppColors.textMuted)),
            TextSpan(
              text: value,
              style: TextStyle(color: valueColor ?? AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

/// Five-star row for a 0–10 rating, plus the numeric value.
class _StarRating extends StatelessWidget {
  final double rating;

  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    final stars = (rating / 2).clamp(0, 5);
    return Semantics(
      label: 'Rating ${rating.toStringAsFixed(1)} dari 10',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < 5; i++)
            Icon(
              stars >= i + 1
                  ? Icons.star_rounded
                  : stars > i
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded,
              size: 15,
              color: AppColors.amber,
            ),
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassContainer(
      borderRadius: AppRadius.lg,
      boxShadow: const [],
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
