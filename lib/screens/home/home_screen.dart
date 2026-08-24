import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ngomik_flutter/core/constants/app_colors.dart';
import 'package:ngomik_flutter/providers/manga_provider.dart';
import 'package:ngomik_flutter/providers/auth_provider.dart';
import 'package:ngomik_flutter/widgets/hero_carousel.dart';
import 'package:ngomik_flutter/widgets/coverflow_slider.dart';
import 'package:ngomik_flutter/widgets/manga_card.dart';
import 'package:ngomik_flutter/widgets/app_network_image.dart';
import 'package:ngomik_flutter/widgets/google_dots_loading.dart';
import 'package:ngomik_flutter/widgets/bouncing_tap.dart';
import 'package:ngomik_flutter/screens/auth/login_screen.dart';
import 'package:ngomik_flutter/screens/settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MangaProvider>().loadHomeFeed();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      if (maxScroll - currentScroll <= 600) {
        final provider = context.read<MangaProvider>();
        if (provider.isFiltered) {
          provider.loadMoreFiltered();
        } else {
          provider.loadMorePopular();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    final userName = user?.username ?? 'Comic Enjoyer';
    final userInitials = userName.isNotEmpty
        ? userName
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : 'CE';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<MangaProvider>(
          builder: (context, provider, child) {
            if (provider.isLoadingHome && provider.heroManga.isEmpty) {
              return const Center(
                child: GoogleDotsLoading(dotSize: 13, jumpHeight: 18),
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.card,
              onRefresh: () => provider.loadHomeFeed(refresh: true),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // 1. Topbar (Greeting Layout from screenshot)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: Avatar + Greeting Text
                          BouncingTap(
                            scaleFactor: 0.96,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => user != null
                                      ? const SettingsScreen()
                                      : const LoginScreen(),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFF43F5E),
                                        Color(0xFFE11D48),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child:
                                      user?.avatarImageUrl != null &&
                                          user!.avatarImageUrl!.isNotEmpty
                                      ? AppNetworkImage(
                                          imageUrl: user.avatarImageUrl!,
                                          fit: BoxFit.cover,
                                          errorWidget: Center(
                                            child: Text(
                                              userInitials,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        )
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Image.asset(
                                            'assets/images/logo.png',
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user != null
                                          ? 'Halo,'
                                          : 'Selamat Datang,',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Right: Action Button (Login [->] or Settings)
                          BouncingTap(
                            scaleFactor: 0.92,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => user != null
                                      ? const SettingsScreen()
                                      : const LoginScreen(),
                                ),
                              );
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1E293B,
                                ).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Icon(
                                user != null
                                    ? Icons.person_rounded
                                    : Icons.login_rounded,
                                size: 18,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Filter Pills Row (Horizontal Scroll)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _buildFilterPill('Semua', 'all', provider),
                            const SizedBox(width: 8),
                            _buildFilterPill('Project', 'project', provider),
                            const SizedBox(width: 8),
                            _buildFilterPill('Mirror', 'mirror', provider),
                            const SizedBox(width: 8),
                            _buildFilterPill('Baru Update', 'latest', provider),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              'Paling Populer',
                              'popular',
                              provider,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill('Top Rating', 'rating', provider),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Main Content
                  if (provider.isFiltered) ...[
                    // Filtered View
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getFilterTitle(provider.activeFilter),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => provider.setFilter('all'),
                              child: const Text(
                                '🏠 Beranda',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (provider.isLoadingFiltered)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 50),
                          child: Center(
                            child: GoogleDotsLoading(
                              dotSize: 11,
                              jumpHeight: 14,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.58,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 18,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final manga = provider.filteredManga[index];
                            return MangaCard(manga: manga);
                          }, childCount: provider.filteredManga.length),
                        ),
                      ),
                      if (provider.isLoadingMoreFiltered)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ] else ...[
                    // DEFAULT HOME VIEW (Matching Screenshot)

                    // Hero Trending Carousel
                    if (provider.heroManga.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: HeroCarousel(mangaList: provider.heroManga),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 18)),
                    ],

                    // Section 1: Recently Updated
                    if (provider.recentManga.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recently Updated',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => provider.setFilter('latest'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1E293B,
                                    ).withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: const Text(
                                    'See all ➔',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFDA4AF),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Coverflow 3D Slider
                      SliverToBoxAdapter(
                        child: CoverflowSlider(mangaList: provider.recentManga),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 22)),
                    ],

                    // Section 2: Popular Series
                    if (provider.popularManga.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Popular Series',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => provider.setFilter('popular'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1E293B,
                                    ).withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: const Text(
                                    'See all ➔',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFDA4AF),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Popular Manga Grid
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.58,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 18,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final manga = provider.popularManga[index];
                            return MangaCard(manga: manga);
                          }, childCount: provider.popularManga.length),
                        ),
                      ),

                      if (provider.isLoadingMorePopular)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: GoogleDotsLoading(
                                dotSize: 9,
                                spacing: 6,
                                jumpHeight: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterPill(
    String label,
    String filterKey,
    MangaProvider provider,
  ) {
    final isSelected = provider.activeFilter == filterKey;

    return BouncingTap(
      scaleFactor: 0.94,
      onTap: () => provider.setFilter(filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.neonPinkGradient : null,
          color: isSelected ? null : const Color(0xFF131826),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF3366) : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF2E63).withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  String _getFilterTitle(String filter) {
    switch (filter) {
      case 'project':
        return 'Komik Project';
      case 'mirror':
        return 'Komik Mirror';
      case 'latest':
        return 'Recently Updated';
      case 'popular':
        return 'Popular Series';
      case 'rating':
        return 'Top Rated Series';
      default:
        return 'Daftar Komik';
    }
  }
}
