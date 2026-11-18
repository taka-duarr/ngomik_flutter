import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/manga.dart';
import 'manga_flag.dart';
import 'app_network_image.dart';
import 'glass_widgets.dart';
import '../screens/detail/manga_detail_screen.dart';

import 'bouncing_tap.dart';

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
    final genre = manga.genres.isNotEmpty ? manga.genres.first : manga.type;
    final isCompleted = manga.status.toLowerCase() == 'completed';
    final subtitle = manga.latestChapter?.isNotEmpty == true
        ? 'Ch. ${manga.latestChapter}${genre.isNotEmpty ? '  ·  $genre' : ''}'
        : genre;

    return Semantics(
      button: true,
      label: manga.title,
      child: BouncingTap(
        scaleFactor: 0.96,
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
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: AppColors.card,
                  boxShadow: const [
                    BoxShadow(color: Color(0x33101225), blurRadius: 14, offset: Offset(0, 6)),
                  ],
                ),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(imageUrl: manga.coverUrl, fit: BoxFit.cover),

                    // Light vignette: top for badges, bottom for the rating chip
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x59191C30),
                            Color(0x00191C30),
                            Color(0x00191C30),
                            Color(0xA6191C30),
                          ],
                          stops: [0.0, 0.22, 0.65, 1.0],
                        ),
                      ),
                    ),

                    Positioned(top: 8, left: 8, child: MangaFlag(type: manga.type)),

                    if (manga.status.isNotEmpty)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GlassTag(
                          label: isCompleted ? 'Tamat' : 'Ongoing',
                          color: isCompleted ? AppColors.accent : AppColors.emerald,
                          leading: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isCompleted ? AppColors.accent : AppColors.emerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),

                    if (manga.rating > 0)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: GlassTag(
                          label: manga.rating.toStringAsFixed(1),
                          icon: Icons.star_rounded,
                          color: AppColors.amber,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              manga.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
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
      ),
    );
  }
}
