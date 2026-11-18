import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/manga.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/google_dots_loading.dart';
import '../../widgets/manga_row_tile.dart';
import '../../widgets/paged_manga_list.dart';

/// Ranked list of series, switchable between "most bookmarked" and "rating".
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final PagedMangaList _list = PagedMangaList(sort: 'bookmark');
  final ScrollController _scroll = ScrollController();

  static const _modes = <(String, String, IconData)>[
    ('Paling disimpan', 'bookmark', Icons.bookmark_rounded),
    ('Rating tertinggi', 'rating', Icons.star_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _list.refresh();
    _scroll.addListener(() {
      if (_scroll.position.maxScrollExtent - _scroll.position.pixels < 500) _list.loadMore();
    });
  }

  @override
  void dispose() {
    _list.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  Widget _meta(Manga m) {
    return Row(
      children: [
        if (m.rating > 0) ...[
          const Icon(Icons.star_rounded, size: 14, color: AppColors.amber),
          const SizedBox(width: 3),
          Text(
            m.rating.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
        ],
        if (m.bookmarkCount > 0) ...[
          const Icon(Icons.bookmark_rounded, size: 13, color: AppColors.primaryLight),
          const SizedBox(width: 3),
          Text(
            _compact(m.bookmarkCount),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: _list,
            builder: (context, _) {
              return RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: _list.refresh,
                child: CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: Text(
                          'Peringkat',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
                        child: Text(
                          'Komik yang lagi ramai dibaca pembaca Ngomik.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Row(
                          children: [
                            for (final (label, key, icon) in _modes) ...[
                              GlassPill(
                                label: label,
                                icon: icon,
                                selected: _list.sort == key,
                                onTap: () => _list.changeSort(key),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (_list.isLoading && _list.items.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 100),
                          child: Center(child: GoogleDotsLoading(dotSize: 12, jumpHeight: 16)),
                        ),
                      )
                    else if (_list.items.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: GlassEmptyState(
                            icon: Icons.wifi_off_rounded,
                            title: 'Gagal memuat peringkat',
                            message: 'Periksa koneksi lalu coba lagi.',
                            actionLabel: 'Coba lagi',
                            actionIcon: Icons.refresh_rounded,
                            onAction: _list.refresh,
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.builder(
                          itemCount: _list.items.length,
                          itemBuilder: (context, i) {
                            final m = _list.items[i];
                            return MangaRowTile(manga: m, rank: i + 1, meta: _meta(m));
                          },
                        ),
                      ),
                    if (_list.isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: GoogleDotsLoading(dotSize: 9, spacing: 6, jumpHeight: 10)),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 110)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
