import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../core/constants/app_colors.dart';
import '../models/manga.dart';
import '../screens/detail/manga_detail_screen.dart';
import 'app_network_image.dart';

import 'bouncing_tap.dart';
import 'glass_widgets.dart';

class HeroCarousel extends StatefulWidget {
  final List<Manga> mangaList;

  const HeroCarousel({super.key, required this.mangaList});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.mangaList.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: widget.mangaList.length,
          options: CarouselOptions(
            height: 196,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 5),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            enlargeCenterPage: true,
            viewportFraction: 0.9,
            enlargeFactor: 0.18,
            onPageChanged: (index, reason) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          itemBuilder: (context, index, realIndex) {
            final manga = widget.mangaList[index];
            return _buildCarouselCard(context, manga, index);
          },
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: widget.mangaList.asMap().entries.map((entry) {
            final isSelected = _currentIndex == entry.key;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSelected ? 18 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.22),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCarouselCard(BuildContext context, Manga manga, int index) {
    final image = manga.bannerUrl?.isNotEmpty == true ? manga.bannerUrl! : manga.coverUrl;
    final genresText = manga.genres.isNotEmpty ? manga.genres.take(3).join(' • ') : 'Action • Adventure';

    return BouncingTap(
      scaleFactor: 0.97,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MangaDetailScreen(mangaId: manga.id, initialManga: manga),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: const [
            BoxShadow(color: Color(0x40101225), blurRadius: 24, offset: Offset(0, 12)),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.borderGlow),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppNetworkImage(imageUrl: image, fit: BoxFit.cover),
            const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.coverScrim)),

            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    manga.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    genresText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GlassTag(
                        label: '#${index + 1} Trending',
                        icon: Icons.local_fire_department_rounded,
                        filled: true,
                      ),
                      if (manga.rating > 0) ...[
                        const SizedBox(width: 6),
                        GlassTag(
                          label: manga.ratingCount >= 100
                              ? '${manga.rating.toStringAsFixed(1)} · ${_compact(manga.ratingCount)}'
                              : manga.rating.toStringAsFixed(1),
                          icon: Icons.star_rounded,
                          color: AppColors.amber,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
