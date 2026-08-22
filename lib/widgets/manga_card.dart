import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/manga.dart';
import 'manga_flag.dart';
import 'app_network_image.dart';
import '../screens/detail/manga_detail_screen.dart';

class MangaCard extends StatelessWidget {
  final Manga manga;
  final VoidCallback? onTap;

  const MangaCard({
    super.key,
    required this.manga,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final genre = manga.genres.isNotEmpty ? manga.genres.first : 'Action';

    return GestureDetector(
      onTap: onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MangaDetailScreen(
                  mangaId: manga.id,
                  initialManga: manga,
                ),
              ),
            );
          },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Poster Image with Badges (Borderless Clean Curved Box)
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover Image
                  AppNetworkImage(
                    imageUrl: manga.coverUrl,
                    fit: BoxFit.cover,
                  ),

                  // Top & Bottom Vignette / Gradient Overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                          stops: const [0.0, 0.25, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Top Left: Flag Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: MangaFlag(type: manga.type),
                  ),

                  // Top Right: Status Badge (• ONGOING / • COMPLETED)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: manga.status.toLowerCase() == 'completed'
                            ? const Color(0xFF0E3A5A).withValues(alpha: 0.85)
                            : const Color(0xFF064E3B).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: manga.status.toLowerCase() == 'completed'
                              ? AppColors.cyan.withValues(alpha: 0.6)
                              : AppColors.emerald.withValues(alpha: 0.6),
                          width: 0.6,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: manga.status.toLowerCase() == 'completed'
                                  ? AppColors.cyan
                                  : const Color(0xFF34D399),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            manga.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: manga.status.toLowerCase() == 'completed'
                                  ? AppColors.cyan
                                  : const Color(0xFF34D399),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Left: Rating Pill Badge (★ 8.6)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.35),
                          width: 0.6,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                          const SizedBox(width: 2.5),
                          Text(
                            manga.rating > 0 ? manga.rating.toStringAsFixed(1) : '8.5',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 7),

          // 2. Manga Title
          Text(
            manga.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 2),

          // 3. Genre Subtitle
          Text(
            genre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
