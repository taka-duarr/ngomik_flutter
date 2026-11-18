import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/date_formatter.dart';
import '../models/chapter.dart';
import '../models/manga.dart';
import 'app_network_image.dart';
import 'bouncing_tap.dart';
import '../screens/reader/reader_screen.dart';

/// One row in the episode list. Keeps the chapter-thumbnail backdrop, tinted
/// into the app palette, with a thin magenta outline like the reference.
///
/// States:
/// - unread     → bright text, magenta outline
/// - read       → dimmed, "Dibaca" check
/// - last read  → magenta edge bar + "Terakhir dibaca", so it's easy to find
class ChapterListTile extends StatelessWidget {
  final Chapter chapter;
  final Manga manga;
  final bool isRead;
  final bool isLastRead;

  const ChapterListTile({
    super.key,
    required this.chapter,
    required this.manga,
    required this.isRead,
    this.isLastRead = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgImageUrl = (chapter.thumbnailUrl != null && chapter.thumbnailUrl!.isNotEmpty)
        ? chapter.thumbnailUrl!
        : manga.coverUrl;

    final dateText = chapter.releaseDate != null && chapter.releaseDate!.isNotEmpty
        ? DateFormatter.timeAgo(chapter.releaseDate)
        : 'Update terbaru';

    final hasTitle = chapter.chapterTitle != null &&
        chapter.chapterTitle!.trim().isNotEmpty &&
        !chapter.chapterTitle!.toLowerCase().contains('chapter ${chapter.chapterNumber}');

    final dimmed = isRead && !isLastRead;

    final borderColor = isLastRead
        ? AppColors.primaryLight.withValues(alpha: 0.7)
        : dimmed
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.borderAccent;

    return Semantics(
      button: true,
      label: 'Chapter ${chapter.chapterNumber}${isRead ? ', sudah dibaca' : ''}',
      excludeSemantics: true,
      child: BouncingTap(
        scaleFactor: 0.98,
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
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: borderColor, width: isLastRead ? 1.2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Thumbnail backdrop, slightly desaturated when already read
              Opacity(
                opacity: dimmed ? 0.45 : 1,
                child: AppNetworkImage(
                  imageUrl: bgImageUrl,
                  fit: BoxFit.cover,
                  errorWidget: Container(color: AppColors.card),
                ),
              ),

              // 2. Palette-tinted scrim, solid on the text side
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xF51C2038),
                      Color(0xD91C2038),
                      Color(0x991C2038),
                      Color(0x731C2038),
                    ],
                    stops: [0.0, 0.45, 0.78, 1.0],
                  ),
                ),
              ),

              // 3. Last-read edge marker
              if (isLastRead)
                const Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: ColoredBox(color: AppColors.primary),
                ),

              // 4. Content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasTitle
                                ? 'Chapter ${chapter.chapterNumber} · ${chapter.chapterTitle!.trim()}'
                                : 'Chapter ${chapter.chapterNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: dimmed ? AppColors.textMuted : AppColors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (isLastRead) ...[
                                const Icon(Icons.bookmark_rounded, size: 12, color: AppColors.primaryLight),
                                const SizedBox(width: 4),
                                const Text(
                                  'Terakhir dibaca',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                                const _Dot(),
                              ] else if (isRead) ...[
                                const Icon(Icons.check_rounded, size: 13, color: AppColors.emerald),
                                const SizedBox(width: 3),
                                const Text(
                                  'Dibaca',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.emerald,
                                  ),
                                ),
                                const _Dot(),
                              ],
                              Flexible(
                                child: Text(
                                  dateText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Read affordance
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isLastRead
                            ? AppColors.primary
                            : const Color(0x8C1C2038),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: isLastRead ? Colors.transparent : Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: 20,
                        color: isLastRead
                            ? Colors.white
                            : dimmed
                                ? AppColors.textMuted
                                : AppColors.primaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(color: AppColors.textDisabled, shape: BoxShape.circle),
    );
  }
}
