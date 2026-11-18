import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/manga.dart';
import '../screens/detail/manga_detail_screen.dart';
import 'app_network_image.dart';
import 'liquid_glass_container.dart';
import 'manga_flag.dart';

/// Horizontal list row: optional rank numeral, cover, title and two meta
/// lines. Used by the ranking and updates feeds.
class MangaRowTile extends StatelessWidget {
  final Manga manga;
  final int? rank;
  final Widget? meta;
  final String? subtitle;

  const MangaRowTile({super.key, required this.manga, this.rank, this.meta, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final genres = manga.genres.take(3).join(' · ');
    final podium = rank != null && rank! <= 3;

    return Semantics(
      button: true,
      label: rank != null ? 'Peringkat $rank, ${manga.title}' : manga.title,
      excludeSemantics: true,
      child: LiquidGlassContainer(
        margin: const EdgeInsets.only(bottom: 10),
        borderRadius: AppRadius.lg,
        boxShadow: const [],
        border: podium ? Border.all(color: AppColors.borderAccent) : null,
        padding: const EdgeInsets.all(10),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MangaDetailScreen(mangaId: manga.id, initialManga: manga)),
        ),
        child: Row(
          children: [
            if (rank != null)
              SizedBox(
                width: 40,
                child: Text(
                  rank!.toString().padLeft(2, '0'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: podium ? AppColors.primaryLight : AppColors.textDisabled,
                  ),
                ),
              ),
            if (rank != null) const SizedBox(width: 6),
            Stack(
              children: [
                Container(
                  width: 58,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AppNetworkImage(imageUrl: manga.coverUrl, fit: BoxFit.cover),
                ),
                Positioned(left: 4, top: 4, child: MangaFlag(type: manga.type)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manga.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle ?? (genres.isNotEmpty ? genres : manga.type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                  if (meta != null) ...[const SizedBox(height: 6), meta!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
