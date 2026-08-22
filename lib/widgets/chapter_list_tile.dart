import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/date_formatter.dart';
import '../models/chapter.dart';
import '../models/manga.dart';
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
    final title = chapter.chapterTitle != null && chapter.chapterTitle!.isNotEmpty
        ? 'Chapter ${chapter.chapterNumber} - ${chapter.chapterTitle}'
        : 'Chapter ${chapter.chapterNumber}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isRead ? AppColors.surface.withValues(alpha: 0.5) : AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isRead ? AppColors.border.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: ListTile(
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        dense: true,
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isRead
                ? AppColors.emerald.withValues(alpha: 0.15)
                : AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isRead ? Icons.check_circle_outline_rounded : Icons.menu_book_rounded,
            size: 16,
            color: isRead ? AppColors.emerald : AppColors.primary,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isRead ? AppColors.textMuted : AppColors.textPrimary,
          ),
        ),
        subtitle: chapter.releaseDate != null && chapter.releaseDate!.isNotEmpty
            ? Text(
                DateFormatter.timeAgo(chapter.releaseDate),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textDisabled,
                ),
              )
            : null,
        trailing: isRead
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Dibaca',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emerald,
                  ),
                ),
              )
            : const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
      ),
    );
  }
}
