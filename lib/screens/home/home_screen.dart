import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ngomik_flutter/core/constants/app_colors.dart';
import 'package:ngomik_flutter/models/manga.dart';
import 'package:ngomik_flutter/providers/manga_provider.dart';
import 'package:ngomik_flutter/providers/auth_provider.dart';
import 'package:ngomik_flutter/widgets/hero_carousel.dart';
import 'package:ngomik_flutter/widgets/manga_card.dart';
import 'package:ngomik_flutter/widgets/app_network_image.dart';
import 'package:ngomik_flutter/widgets/google_dots_loading.dart';
import 'package:ngomik_flutter/widgets/bouncing_tap.dart';
import 'package:ngomik_flutter/widgets/app_backdrop.dart';
import 'package:ngomik_flutter/widgets/glass_widgets.dart';
import 'package:ngomik_flutter/screens/auth/login_screen.dart';
import 'package:ngomik_flutter/screens/main_navigation_shell.dart';

/// Home: a profile strip on the canvas, then one large glass "sheet" that
/// carries everything else — title, hero, format tabs and the grid.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  static const _tabs = <(String, String)>[
    ('Untukmu', 'all'),
    ('Manga', 'manga'),
    ('Manhwa', 'manhwa'),
    ('Manhua', 'manhua'),
  ];

  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 0.6,
    crossAxisSpacing: 12,
    mainAxisSpacing: 18,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MangaProvider>();
      // Home only offers the format tabs now; fall back if an old filter is active.
      if (!_tabs.any((t) => t.$2 == provider.activeFilter)) {
        provider.setFilter('all');
      }
      provider.loadHomeFeed();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels <= 600) {
      final provider = context.read<MangaProvider>();
      provider.isFiltered
          ? provider.loadMoreFiltered()
          : provider.loadMorePopular();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Consumer<MangaProvider>(
            builder: (context, provider, child) {
              final loadingFirst =
                  provider.isLoadingHome && provider.heroManga.isEmpty;

              return RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: () => provider.isFiltered
                    ? provider.setFilter(provider.activeFilter)
                    : provider.loadHomeFeed(refresh: true),
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: _ProfileStrip(
                        name: user?.username,
                        email: user?.email,
                        avatarUrl: user?.avatarImageUrl,
                      ),
                    ),

                    // ── The glass sheet ─────────────────────────────────
                    DecoratedSliver(
                      decoration: BoxDecoration(
                        color: AppColors.glassFill,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x99262B48), Color(0x591C2038)],
                          stops: [0.0, 0.4],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        border: Border.all(color: AppColors.glassEdge),
                      ),
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          // Sheet title
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                18,
                                12,
                                14,
                              ),
                              child: Row(
                                children: [
                                  Image.asset(
                                    'assets/images/logo_mark.png',
                                    width: 34,
                                    height: 34,
                                    excludeFromSemantics: true,
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'komik ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          TextSpan(
                                            text: 'populer',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w400,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      style: TextStyle(
                                        fontSize: 22,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Cari komik',
                                    onPressed: () => AppTab.go(AppTab.explore),
                                    icon: const Icon(
                                      Icons.search_rounded,
                                      size: 24,
                                    ),
                                    color: AppColors.textPrimary,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (loadingFirst)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 120),
                                child: Center(
                                  child: GoogleDotsLoading(
                                    dotSize: 13,
                                    jumpHeight: 18,
                                  ),
                                ),
                              ),
                            )
                          else ...[
                            if (provider.heroManga.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: HeroCarousel(
                                  mangaList: provider.heroManga,
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 18),
                              ),
                            ],

                            // Format tabs — sticky so the grid always has context
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _TabsHeader(
                                tabs: _tabs,
                                active: provider.activeFilter,
                                onSelect: provider.setFilter,
                              ),
                            ),

                            ..._buildTabContent(provider),
                          ],

                          // Room for the floating nav bar
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 110),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTabContent(MangaProvider provider) {
    if (provider.isFiltered) {
      if (provider.isLoadingFiltered) {
        return const [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: GoogleDotsLoading(dotSize: 11, jumpHeight: 14),
              ),
            ),
          ),
        ];
      }
      return [
        _grid(provider.filteredManga),
        if (provider.isLoadingMoreFiltered) _loadingMore(),
      ];
    }

    return [
      if (provider.recentManga.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Baru update',
            actionLabel: 'Semua',
            onAction: () => AppTab.go(AppTab.updates),
            padding: const EdgeInsets.fromLTRB(20, 6, 8, 10),
          ),
        ),
        SliverToBoxAdapter(
          child: _RecentStrip(mangaList: provider.recentManga),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 18)),
      ],
      if (provider.popularManga.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Paling banyak disimpan',
            actionLabel: 'Peringkat',
            onAction: () => AppTab.go(AppTab.ranking),
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 10),
          ),
        ),
        _grid(provider.popularManga),
        if (provider.isLoadingMorePopular) _loadingMore(),
      ],
    ];
  }

  Widget _grid(List<Manga> list) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      sliver: SliverGrid(
        gridDelegate: _gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (context, index) => MangaCard(manga: list[index]),
          childCount: list.length,
        ),
      ),
    );
  }

  Widget _loadingMore() {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: GoogleDotsLoading(dotSize: 9, spacing: 6, jumpHeight: 10),
        ),
      ),
    );
  }
}

// ── Profile strip ─────────────────────────────────────────────────────────

class _ProfileStrip extends StatelessWidget {
  final String? name;
  final String? email;
  final String? avatarUrl;

  const _ProfileStrip({this.name, this.email, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final signedIn = name != null;
    final handle = signedIn
        ? '@${(email?.isNotEmpty ?? false) ? email!.split('@').first : name!.toLowerCase().replaceAll(' ', '_')}'
        : 'Masuk untuk sinkron bookmark';

    void openProfile() {
      if (signedIn) {
        AppTab.go(AppTab.profile);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: BouncingTap(
        scaleFactor: 0.98,
        onTap: openProfile,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatarUrl?.isNotEmpty == true
                  ? AppNetworkImage(
                      imageUrl: avatarUrl!,
                      fit: BoxFit.cover,
                      errorWidget: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset('assets/images/logo.png', fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signedIn ? name! : 'Tamu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (!signedIn)
              TextButton.icon(
                onPressed: openProfile,
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Masuk'),
              )
            else
              IconButton(
                tooltip: 'Riwayat baca',
                onPressed: () => AppTab.go(AppTab.profile, profileTab: 1),
                icon: const Icon(Icons.history_rounded),
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Format tabs (pinned) ──────────────────────────────────────────────────

class _TabsHeader extends SliverPersistentHeaderDelegate {
  final List<(String, String)> tabs;
  final String active;
  final ValueChanged<String> onSelect;

  _TabsHeader({
    required this.tabs,
    required this.active,
    required this.onSelect,
  });

  static const double _height = 54;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Once pinned, give the tabs an opaque-ish strip so cards don't show through.
    final pinned = shrinkOffset > 0 || overlapsContent;
    final tabsRow = ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: tabs.length,
      separatorBuilder: (_, _) => const SizedBox(width: 4),
      itemBuilder: (context, i) {
        final (label, key) = tabs[i];
        final selected = key == active;
        return Semantics(
          button: true,
          selected: selected,
          child: BouncingTap(
            scaleFactor: 0.95,
            onTap: () => onSelect(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!pinned) return tabsRow;

    // Pinned: frosted strip so the grid scrolling underneath stays out of the way.
    return ClipRect(
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xD9262B48),
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: tabsRow,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabsHeader old) =>
      old.active != active || old.tabs != tabs;
}

// ── Recently updated strip ────────────────────────────────────────────────

class _RecentStrip extends StatelessWidget {
  final List<Manga> mangaList;

  const _RecentStrip({required this.mangaList});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: mangaList.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) =>
            SizedBox(width: 118, child: MangaCard(manga: mangaList[i])),
      ),
    );
  }
}
