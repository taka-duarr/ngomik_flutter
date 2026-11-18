import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../models/manga.dart';
import '../../models/chapter.dart';
import '../../services/shngm_api_service.dart';
import '../../providers/history_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/google_dots_loading.dart';
import '../../widgets/comments_section.dart';
import '../../widgets/liquid_glass_container.dart';
import '../../widgets/bouncing_tap.dart';

class ReaderScreen extends StatefulWidget {
  final String chapterId;
  final String chapterNumber;
  final Manga manga;

  const ReaderScreen({
    super.key,
    required this.chapterId,
    required this.chapterNumber,
    required this.manga,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final ShngmApiService _apiService = ShngmApiService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _commentsKey = GlobalKey();

  ChapterDetail? _chapterDetail;
  bool _isLoading = true;
  bool _showControls = true;
  double _scrollProgress = 0.0;
  late String _currentChapterId;
  late String _currentChapterNumber;

  @override
  void initState() {
    super.initState();
    _currentChapterId = widget.chapterId;
    _currentChapterNumber = widget.chapterNumber;
    _scrollController.addListener(_handleScrollProgress);
    _loadChapterImages(_currentChapterId);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScrollProgress);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScrollProgress() {
    if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
      final progress = (_scrollController.offset / _scrollController.position.maxScrollExtent).clamp(0.0, 1.0);
      if ((progress - _scrollProgress).abs() > 0.008) {
        setState(() {
          _scrollProgress = progress;
        });
      }
    }
  }

  Future<void> _loadChapterImages(String chapterId) async {
    setState(() => _isLoading = true);

    final detail = await _apiService.fetchChapterImages(chapterId);

    if (detail != null && mounted) {
      setState(() {
        _chapterDetail = detail;
        _currentChapterId = chapterId;
        _currentChapterNumber = detail.chapterNumber;
        _isLoading = false;
        _scrollProgress = 0.0;
      });

      // Automatically record reading history
      final auth = context.read<AuthProvider>();
      context.read<HistoryProvider>().recordReadChapter(
        mangaId: widget.manga.id,
        mangaTitle: widget.manga.title,
        coverUrl: widget.manga.coverUrl,
        chapterId: chapterId,
        chapterNumber: detail.chapterNumber,
        chapterTitle: detail.chapterTitle,
        userRate: widget.manga.rating,
        token: auth.token,
      );

      // Scroll back to top
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients) return;

    // Direct scroll down to comments section without stopping halfway
    for (int i = 0; i < 30; i++) {
      if (!_scrollController.hasClients) break;

      // If comments section is already built in the tree, animate smoothly directly into it!
      if (_commentsKey.currentContext != null) {
        await Scrollable.ensureVisible(
          _commentsKey.currentContext!,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: 0.0,
        );
        return;
      }

      // Fast-advance to current known max to force ListView.builder to build the next chunk
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(max);
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 16));
    }

    // Final smooth landing at the comments section
    if (_commentsKey.currentContext != null) {
      await Scrollable.ensureVisible(
        _commentsKey.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.0,
      );
    } else if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _hideControls() {
    if (_showControls) {
      setState(() {
        _showControls = false;
      });
    }
  }

  void _showChapterListModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChapterListBottomSheet(
        mangaId: widget.manga.id,
        mangaTitle: widget.manga.title,
        currentChapterId: _currentChapterId,
        onChapterSelected: (chapterId) {
          _loadChapterImages(chapterId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Vertical Webtoon Reader Image Stream
          NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction == ScrollDirection.reverse && _showControls) {
                // Auto hide controls when scrolling down to read
                _hideControls();
              }
              return false;
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleControls,
              child: _isLoading
                  ? const Center(child: GoogleDotsLoading(dotSize: 13, jumpHeight: 18))
                  : (_chapterDetail == null || _chapterDetail!.images.isEmpty)
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.broken_image_rounded, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              const Text(
                                'Gagal memuat gambar chapter.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _loadChapterImages(_currentChapterId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(
                            top: topPadding + 54,
                            bottom: bottomPadding + 100,
                          ),
                          // Keep ample buffer of pages rendered so scrolling is instant
                          cacheExtent: MediaQuery.sizeOf(context).height * 6.0,
                          addRepaintBoundaries: true,
                          addAutomaticKeepAlives: true,
                          itemCount: _chapterDetail!.images.length + 2,
                          itemBuilder: (context, index) {
                            // Next Chapter Footer Banner
                            if (index == _chapterDetail!.images.length) {
                              return _buildEndChapterBanner();
                            }

                            // Embedded Chapter Comments Section
                            if (index == _chapterDetail!.images.length + 1) {
                              return KeyedSubtree(
                                key: _commentsKey,
                                child: CommentsSection(
                                  path: ApiEndpoints.chapterPageKey(widget.manga.id, _currentChapterId),
                                  title: '${widget.manga.title} - Ch. $_currentChapterNumber',
                                  mangaId: widget.manga.id,
                                  chapterId: _currentChapterId,
                                ),
                              );
                            }

                            final imgUrl = _chapterDetail!.images[index];
                            return RepaintBoundary(
                              child: _ComicImageTile(
                                imageUrl: imgUrl,
                                pageIndex: index,
                                onTap: _toggleControls,
                              ),
                            );
                          },
                        ),
            ),
          ),

          // 2. Slim Neon Reading Progress Indicator at top of screen
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 2.5,
              child: LinearProgressIndicator(
                value: _scrollProgress,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),

          // 3. Floating Liquid Glass Top App Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            top: _showControls ? (topPadding + 6) : -(topPadding + 100),
            left: 12,
            right: 12,
            child: LiquidGlassContainer(
              borderRadius: 22,
              blur: 24,
              color: Colors.black.withValues(alpha: 0.42),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.20),
                width: 1.0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
              child: Row(
                children: [
                  // Back Button (Mini Liquid Glass Pill)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 17),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Manga Title & Chapter Badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.manga.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
                              ),
                              child: Text(
                                'Ch. $_currentChapterNumber',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                            if (_chapterDetail?.chapterTitle != null && _chapterDetail!.chapterTitle!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _chapterDetail!.chapterTitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Chapter List Shortcut Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _showChapterListModal,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                        ),
                        child: const Icon(Icons.format_list_bulleted_rounded, color: Colors.white, size: 19),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Reload Chapter Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _loadChapterImages(_currentChapterId),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                        ),
                        child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 19),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Animated Floating Liquid Glass Bottom Dock
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            bottom: _showControls ? (bottomPadding + 10) : -(bottomPadding + 100),
            left: 14,
            right: 14,
            child: LiquidGlassContainer(
              borderRadius: 24,
              blur: 24,
              color: Colors.black.withValues(alpha: 0.45),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1.0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
              child: Row(
                children: [
                  // Prev Chapter Button
                  _buildNavButton(
                    icon: Icons.arrow_back_rounded,
                    label: 'Prev',
                    isEnabled: _chapterDetail?.prevChapterId != null,
                    onPressed: _chapterDetail?.prevChapterId != null
                        ? () => _loadChapterImages(_chapterDetail!.prevChapterId!)
                        : null,
                  ),

                  const SizedBox(width: 8),

                  // Center Status & Chapter List Modal Shortcut
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _showChapterListModal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.format_list_bulleted_rounded, size: 15, color: AppColors.accent),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Ch. $_currentChapterNumber • ${(_scrollProgress * 100).toInt()}%',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Next Chapter Button
                  _buildNextNavButton(
                    isEnabled: _chapterDetail?.nextChapterId != null,
                    onPressed: _chapterDetail?.nextChapterId != null
                        ? () => _loadChapterImages(_chapterDetail!.nextChapterId!)
                        : null,
                  ),
                ],
              ),
            ),
          ),

          // 5. Floating Quick Scroll Dock (Jump to Top & Jump to Bottom)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            right: 14,
            bottom: _showControls ? (bottomPadding + 78) : -(bottomPadding + 140),
            child: LiquidGlassContainer(
              borderRadius: 20,
              padding: const EdgeInsets.all(5),
              color: Colors.black.withValues(alpha: 0.60),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.20),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Jump to Top Button
                  Tooltip(
                    message: 'Ke Paling Atas',
                    child: BouncingTap(
                      scaleFactor: 0.88,
                      onTap: _scrollToTop,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                        ),
                        child: const Icon(
                          Icons.keyboard_double_arrow_up_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Jump to Bottom Button
                  Tooltip(
                    message: 'Ke Paling Bawah',
                    child: BouncingTap(
                      scaleFactor: 0.88,
                      onTap: _scrollToBottom,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                        ),
                        child: const Icon(
                          Icons.keyboard_double_arrow_down_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required bool isEnabled,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isEnabled ? onPressed : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isEnabled
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isEnabled ? Colors.white.withValues(alpha: 0.20) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isEnabled ? Colors.white : AppColors.textDisabled,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isEnabled ? Colors.white : AppColors.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextNavButton({
    required bool isEnabled,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isEnabled ? onPressed : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: isEnabled ? AppColors.primaryGradient : null,
            color: isEnabled ? null : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: isEnabled ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.0) : null,
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Next',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isEnabled ? Colors.white : AppColors.textDisabled,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: isEnabled ? Colors.white : AppColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndChapterBanner() {
    final hasPrev = _chapterDetail?.prevChapterId != null;
    final hasNext = _chapterDetail?.nextChapterId != null;

    return LiquidGlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
      padding: const EdgeInsets.all(22),
      borderRadius: 24,
      blur: 0,
      color: const Color(0xFF1F2339).withValues(alpha: 0.90),
      border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 22,
          offset: const Offset(0, 6),
        ),
      ],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            'Selesai Membaca Ch. $_currentChapterNumber',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 18),

          // Next & Prev Chapter Row
          Row(
            children: [
              // Prev Chapter
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: hasPrev
                        ? () => _loadChapterImages(_chapterDetail!.prevChapterId!)
                        : null,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text(
                      'Prev',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: hasPrev ? Colors.white : AppColors.textDisabled,
                      side: BorderSide(
                        color: hasPrev ? Colors.white.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.08),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: hasPrev ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Next Chapter
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: hasNext
                        ? () => _loadChapterImages(_chapterDetail!.nextChapterId!)
                        : null,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text(
                      'Next',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasNext ? AppColors.primary : Colors.white.withValues(alpha: 0.06),
                      foregroundColor: hasNext ? Colors.white : AppColors.textDisabled,
                      elevation: hasNext ? 6 : 0,
                      shadowColor: AppColors.primary.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // List Chapter Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _showChapterListModal,
              icon: const Icon(Icons.format_list_bulleted_rounded, color: AppColors.accent, size: 18),
              label: const Text(
                'List Chapter',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
                backgroundColor: AppColors.accent.withValues(alpha: 0.10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComicImageTile extends StatefulWidget {
  final String imageUrl;
  final int pageIndex;
  final VoidCallback? onTap;

  const _ComicImageTile({
    required this.imageUrl,
    required this.pageIndex,
    this.onTap,
  });

  @override
  State<_ComicImageTile> createState() => _ComicImageTileState();
}

class _ComicImageTileState extends State<_ComicImageTile> with AutomaticKeepAliveClientMixin {
  int _retryKey = 0;
  bool _isRetrying = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _reloadImage() async {
    if (_isRetrying) return;
    setState(() {
      _isRetrying = true;
    });

    try {
      await CachedNetworkImage.evictFromCache(widget.imageUrl);
      PaintingBinding.instance.imageCache.evict(NetworkImage(widget.imageUrl));
    } catch (_) {}

    // Brief delay to allow cache eviction to take effect
    await Future.delayed(const Duration(milliseconds: 120));

    if (mounted) {
      setState(() {
        _retryKey++;
        _isRetrying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isRetrying) {
      return Container(
        height: 280,
        color: const Color(0xFF1F2339),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Memuat ulang gambar ${widget.pageIndex + 1}...',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final cleanUrl = widget.imageUrl.trim();
    if (cleanUrl.isEmpty || cleanUrl == 'null') {
      return _buildErrorWidget(context, 'URL gambar tidak valid');
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final targetMemWidth = (screenWidth * dpr).round();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: CachedNetworkImage(
        key: ValueKey('${cleanUrl}_$_retryKey'),
        imageUrl: cleanUrl,
        httpHeaders: ApiEndpoints.imageHeaders,
        fit: BoxFit.fitWidth,
        filterQuality: FilterQuality.medium,
        memCacheWidth: targetMemWidth > 0 ? targetMemWidth : null,
        fadeInDuration: const Duration(milliseconds: 60),
        placeholder: (context, url) => Container(
          height: 300,
          color: const Color(0xFF1F2339),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildErrorWidget(context, 'Koneksi gagal atau gambar tidak tersedia'),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, String reason) {
    return LiquidGlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      borderRadius: 18,
      blur: 0,
      color: const Color(0xFF2A2F4C).withValues(alpha: 0.90),
      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_rounded, color: Color(0xFFFF5C7A), size: 36),
          const SizedBox(height: 10),
          Text(
            'Halaman ${widget.pageIndex + 1} Gagal Dimuat',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reason,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _reloadImage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'Reload Gambar',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterListBottomSheet extends StatefulWidget {
  final String mangaId;
  final String mangaTitle;
  final String currentChapterId;
  final Function(String chapterId) onChapterSelected;

  const _ChapterListBottomSheet({
    required this.mangaId,
    required this.mangaTitle,
    required this.currentChapterId,
    required this.onChapterSelected,
  });

  @override
  State<_ChapterListBottomSheet> createState() => _ChapterListBottomSheetState();
}

class _ChapterListBottomSheetState extends State<_ChapterListBottomSheet> {
  final ShngmApiService _apiService = ShngmApiService();
  List<Chapter> _chapters = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _page = 1;
  int _totalPages = 1;
  int _totalRecords = 0;
  bool _isAscending = false;

  @override
  void initState() {
    super.initState();
    _fetchChapters(1);
  }

  Future<void> _fetchChapters(int page) async {
    setState(() => _isLoading = true);
    final result = await _apiService.fetchChapterPage(widget.mangaId, page: page, pageSize: 30);
    if (mounted) {
      setState(() {
        _chapters = result.chapters;
        _page = result.page;
        _totalPages = result.totalPages;
        _totalRecords = result.totalRecords;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.trim().isEmpty
        ? _chapters
        : _chapters.where((c) {
            final q = _searchQuery.trim().toLowerCase();
            return c.chapterNumber.toLowerCase().contains(q) ||
                (c.chapterTitle != null && c.chapterTitle!.toLowerCase().contains(q));
          }).toList();

    final displayedChapters = _isAscending ? filtered.reversed.toList() : filtered;

    return LiquidGlassContainer(
      height: MediaQuery.of(context).size.height * 0.78,
      borderRadius: 26,
      blur: 26,
      color: Colors.black.withValues(alpha: 0.65),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.2),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daftar Chapter',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.mangaTitle} • $_totalRecords Chapter',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Sort Button
                IconButton(
                  tooltip: _isAscending ? 'Urutkan Terbaru' : 'Urutkan Terlama',
                  icon: Icon(
                    _isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: AppColors.primaryLight,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isAscending = !_isAscending;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Cari nomor chapter...',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),

          // Chapter List
          Expanded(
            child: _isLoading
                ? const Center(child: GoogleDotsLoading(dotSize: 10, jumpHeight: 14))
                : displayedChapters.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada chapter ditemukan',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: displayedChapters.length,
                        itemBuilder: (context, index) {
                          final chapter = displayedChapters[index];
                          final isCurrent = chapter.id == widget.currentChapterId;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? AppColors.primary.withValues(alpha: 0.20)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isCurrent ? AppColors.primary : Colors.white.withValues(alpha: 0.12),
                                width: isCurrent ? 1.5 : 1.0,
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? AppColors.primary
                                      : Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isCurrent ? Icons.menu_book_rounded : Icons.bookmark_border_rounded,
                                  color: isCurrent ? Colors.white : AppColors.textMuted,
                                  size: 16,
                                ),
                              ),
                              title: Text(
                                'Chapter ${chapter.chapterNumber}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isCurrent ? AppColors.primaryLight : Colors.white,
                                ),
                              ),
                              subtitle: chapter.chapterTitle != null && chapter.chapterTitle!.isNotEmpty
                                  ? Text(
                                      chapter.chapterTitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    )
                                  : null,
                              trailing: isCurrent
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Sedang Dibaca',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : (chapter.releaseDate != null && chapter.releaseDate!.isNotEmpty)
                                      ? Text(
                                          chapter.releaseDate!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                          ),
                                        )
                                      : null,
                              onTap: () {
                                Navigator.pop(context);
                                if (!isCurrent) {
                                  widget.onChapterSelected(chapter.id);
                                }
                              },
                            ),
                          );
                        },
                      ),
          ),

          // Pagination Controls if multiple pages
          if (_totalPages > 1) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _page > 1 && !_isLoading ? () => _fetchChapters(_page - 1) : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: const Text('Prev Page'),
                  ),
                  Text(
                    'Hal $_page / $_totalPages',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  TextButton.icon(
                    onPressed: _page < _totalPages && !_isLoading ? () => _fetchChapters(_page + 1) : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: const Text('Next Page'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
