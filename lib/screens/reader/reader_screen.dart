import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../models/manga.dart';
import '../../models/chapter.dart';
import '../../services/shngm_api_service.dart';
import '../../providers/history_provider.dart';
import '../../providers/auth_provider.dart';

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

  ChapterDetail? _chapterDetail;
  bool _isLoading = true;
  bool _showControls = true;
  late String _currentChapterId;
  late String _currentChapterNumber;

  @override
  void initState() {
    super.initState();
    _currentChapterId = widget.chapterId;
    _currentChapterNumber = widget.chapterNumber;
    _loadChapterImages(_currentChapterId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Vertical Webtoon Reader Image Stream
          GestureDetector(
            onTap: _toggleControls,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
                            ElevatedButton(
                              onPressed: () => _loadChapterImages(_currentChapterId),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                              child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 50,
                          bottom: 100,
                        ),
                        itemCount: _chapterDetail!.images.length + 1,
                        itemBuilder: (context, index) {
                          // Next Chapter Footer Banner
                          if (index == _chapterDetail!.images.length) {
                            return _buildEndChapterBanner();
                          }

                          final imgUrl = _chapterDetail!.images[index];
                          return CachedNetworkImage(
                            imageUrl: imgUrl,
                            fit: BoxFit.fitWidth,
                            memCacheWidth: 1080,
                            placeholder: (context, url) => Container(
                              height: 300,
                              color: const Color(0xFF0F172A),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 200,
                              color: const Color(0xFF1E293B),
                              child: const Center(
                                child: Icon(Icons.error_outline, color: AppColors.primary),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // 2. Animated Top App Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            top: _showControls ? 0 : -90,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 4,
                bottom: 8,
                left: 8,
                right: 16,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.95),
                border: const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Chapter $_currentChapterNumber',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Animated Bottom Navigation Toolbar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            bottom: _showControls ? 0 : -90,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 8,
                top: 8,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.95),
                border: const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Prev Chapter
                  IconButton(
                    onPressed: _chapterDetail?.prevChapterId != null
                        ? () => _loadChapterImages(_chapterDetail!.prevChapterId!)
                        : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                    color: _chapterDetail?.prevChapterId != null
                        ? AppColors.primaryLight
                        : AppColors.textDisabled,
                  ),

                  // Chapter Status Text
                  Text(
                    'Chapter $_currentChapterNumber',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),

                  // Next Chapter
                  IconButton(
                    onPressed: _chapterDetail?.nextChapterId != null
                        ? () => _loadChapterImages(_chapterDetail!.nextChapterId!)
                        : null,
                    icon: const Icon(Icons.skip_next_rounded),
                    color: _chapterDetail?.nextChapterId != null
                        ? AppColors.primaryLight
                        : AppColors.textDisabled,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndChapterBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 40),
          const SizedBox(height: 10),
          Text(
            'Selesai Membaca Ch. $_currentChapterNumber',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          if (_chapterDetail?.nextChapterId != null)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _loadChapterImages(_chapterDetail!.nextChapterId!),
                icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'Lanjut ke Chapter Berikutnya',
                  style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else
            const Text(
              '🎉 Ini adalah chapter terbaru yang tersedia saat ini!',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}
