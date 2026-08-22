import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../models/manga.dart';
import '../../models/chapter.dart';
import '../../services/shngm_api_service.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/history_provider.dart';
import '../../widgets/manga_flag.dart';
import '../../widgets/chapter_list_tile.dart';
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
  bool _isAscending = false;

  @override
  void initState() {
    super.initState();
    _manga = widget.initialManga;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    final result = await _apiService.fetchMangaDetail(widget.mangaId);
    if (result != null && mounted) {
      setState(() {
        _manga = result['manga'] as Manga?;
        _chapters = (result['chapters'] as List<Chapter>?) ?? [];
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final manga = _manga;
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
                          bookmarkProvider.toggleBookmark(manga);
                        },
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background Blur Cover
                        CachedNetworkImage(
                          imageUrl: manga?.bannerUrl?.isNotEmpty == true
                              ? manga!.bannerUrl!
                              : (manga?.coverUrl ?? ''),
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(color: AppColors.surface),
                        ),

                        // Gradient Overlays
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x66000000),
                                Color(0x990B0F19),
                                Color(0xFF0B0F19),
                              ],
                              stops: [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),

                        // Bottom Hero Content
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Poster Cover
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
                                child: CachedNetworkImage(
                                  imageUrl: manga?.coverUrl ?? '',
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => const Icon(Icons.broken_image),
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
                                        MangaFlag(type: manga?.type ?? 'Manhwa'),
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
                                          '${_chapters.length} Chapter',
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

                // 2. Action Buttons (Read / Resume)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_chapters.isNotEmpty && manga != null) {
                                final firstCh = lastReadChapter != null
                                    ? _chapters.firstWhere(
                                        (c) => c.id == lastReadChapter.chapterId,
                                        orElse: () => _chapters.last,
                                      )
                                    : _chapters.last;

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReaderScreen(
                                      chapterId: firstCh.id,
                                      chapterNumber: firstCh.chapterNumber,
                                      manga: manga,
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                            label: Text(
                              lastReadChapter != null
                                  ? 'Lanjut Ch. ${lastReadChapter.chapterNumber}'
                                  : 'Mulai Baca (Ch. 1)',
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
                            if (manga != null) bookmarkProvider.toggleBookmark(manga);
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

                // 5. Chapter Header with Sort Toggle
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daftar Chapter (${_chapters.length})',
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
                if (_chapters.isEmpty && !_isLoading)
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

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }
}
