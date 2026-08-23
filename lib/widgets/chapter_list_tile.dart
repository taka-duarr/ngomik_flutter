import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/date_formatter.dart';
import '../models/chapter.dart';
import '../models/manga.dart';
import 'app_network_image.dart';
import '../screens/reader/reader_screen.dart';

class ChapterListTile extends StatelessWidget {
  final Chapter chapter;
  final Manga manga;
  final bool isRead;

  const ChapterListTile({
    super.key,
    required this.chapter,
    required this.manga,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    final bgImageUrl = (chapter.thumbnailUrl != null && chapter.thumbnailUrl!.isNotEmpty)
        ? chapter.thumbnailUrl!
        : manga.coverUrl;

    final dateText = chapter.releaseDate != null && chapter.releaseDate!.isNotEmpty
        ? DateFormatter.timeAgo(chapter.releaseDate)
        : 'Update Terbaru';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead
              ? AppColors.emerald.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.14),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Chapter Thumbnail Background Image
          AppNetworkImage(
            imageUrl: bgImageUrl,
            fit: BoxFit.cover,
            errorWidget: Container(color: AppColors.card),
          ),

          // 2. Dark Horizontal Gradient Overlay for Text Readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.94),
                    Colors.black.withValues(alpha: 0.78),
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.25),
                  ],
                  stops: const [0.0, 0.45, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // Extra dark tint for read chapters
          if (isRead)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.38),
              ),
            ),

          // 3. Interactive Content Row
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReaderScreen(
                      chapterId: chapter.id,
                      chapterNumber: chapter.chapterNumber,
                      manga: manga,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Left: Chapter Number & Release Date
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Chapter ${chapter.chapterNumber}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (isRead) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.emerald, width: 0.6),
                                  ),
                                  child: const Text(
                                    'DIBACA',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.emerald,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            dateText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right: Heart Button
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.favorite_border_rounded,
                          color: Color(0xFFE11D48),
                          size: 19,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
