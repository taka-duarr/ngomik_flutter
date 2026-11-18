import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/manga.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/google_dots_loading.dart';
import '../../widgets/manga_row_tile.dart';
import '../../widgets/paged_manga_list.dart';

/// Feed of series that just got a new chapter, newest first.
class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  final PagedMangaList _list = PagedMangaList(sort: 'latest');
  final ScrollController _scroll = ScrollController();

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

  Widget _meta(Manga m) {
    return Row(
      children: [
        if (m.latestChapter?.isNotEmpty == true) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: AppColors.borderAccent),
            ),
            child: Text(
              'Ch. ${m.latestChapter}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryLight),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (m.latestChapterTime?.isNotEmpty == true)
          Flexible(
            child: Text(
              DateFormatter.timeAgo(m.latestChapterTime),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ),
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
                          'Update terbaru',
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
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Text(
                          'Chapter yang baru rilis, diurutkan dari yang paling baru.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
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
                            title: 'Gagal memuat update',
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
                          itemBuilder: (context, i) => MangaRowTile(
                            manga: _list.items[i],
                            meta: _meta(_list.items[i]),
                          ),
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
