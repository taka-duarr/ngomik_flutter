import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';
import '../models/manga.dart';
import '../screens/detail/manga_detail_screen.dart';
import 'manga_flag.dart';

class CoverflowSlider extends StatefulWidget {
  final List<Manga> mangaList;

  const CoverflowSlider({super.key, required this.mangaList});

  @override
  State<CoverflowSlider> createState() => _CoverflowSliderState();
}

class _CoverflowSliderState extends State<CoverflowSlider> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.mangaList.isEmpty) return const SizedBox.shrink();

    return CarouselSlider.builder(
      itemCount: widget.mangaList.length,
      options: CarouselOptions(
        height: 255,
        viewportFraction: 0.58,
        enlargeCenterPage: true,
        enlargeFactor: 0.28,
        enableInfiniteScroll: true,
        onPageChanged: (index, reason) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      itemBuilder: (context, index, realIndex) {
        final manga = widget.mangaList[index];
        final isCenter = index == _currentIndex;

        return _buildCard(context, manga, isCenter);
      },
    );
  }

  Widget _buildCard(BuildContext context, Manga manga, bool isCenter) {
    final genre = manga.genres.isNotEmpty ? manga.genres.first : 'Comic';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MangaDetailScreen(mangaId: manga.id, initialManga: manga),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCenter ? AppColors.primary.withValues(alpha: 0.6) : AppColors.border,
            width: isCenter ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isCenter
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.5),
              blurRadius: isCenter ? 20 : 10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover Image
            CachedNetworkImage(
              imageUrl: manga.coverUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: AppColors.surface),
              errorWidget: (context, url, error) => Container(color: AppColors.surface),
            ),

            // Gradient Overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x66000000),
                    Colors.transparent,
                    Color(0xCC000000),
                    Color(0xF50B0F19),
                  ],
                  stops: [0.0, 0.35, 0.7, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // Top Left: Flag
            Positioned(
              top: 10,
              left: 10,
              child: MangaFlag(type: manga.type),
            ),

            // Top Right: Genre & Status Badge
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Genre Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B4B).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
                    ),
                    child: Text(
                      genre,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFDA4AF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF064E3B).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3), width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF34D399),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          manga.status.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF34D399),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Content
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rating & Top Rated badge
                  Row(
                    children: [
                      if (manga.rating > 0) ...[
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEA580C),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            manga.rating.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TOP RATED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Manga Title
                  Text(
                    manga.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Author
                  Text(
                    manga.alternativeTitle?.isNotEmpty == true
                        ? manga.alternativeTitle!
                        : 'by Author',
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
          ],
        ),
      ),
    );
  }
}
