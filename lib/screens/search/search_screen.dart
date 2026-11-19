import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/manga_provider.dart';
import '../../widgets/sakuga_search_field.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/liquid_glass_container.dart';
import '../../widgets/manga_card.dart';
import '../../widgets/google_dots_loading.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String? _selectedGenre;
  String? _selectedStatus;
  String? _selectedType;
  final String _selectedSort = 'latest';

  final List<String> _genres = [
    'Action', 'Adventure', 'Comedy', 'Drama', 'Fantasy', 'Isekai',
    'Martial Arts', 'Mystery', 'Psychological', 'Romance', 'Sci-Fi',
    'Slice of Life', 'Supernatural', 'Thriller', 'Magic', 'School Life'
  ];

  bool get _hasAdvancedFilter => _selectedStatus != null || _selectedType != null;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      context.read<MangaProvider>().loadMoreSearch();
    }
  }

  void _executeSearch() {
    context.read<MangaProvider>().search(
      _searchCtrl.text,
      genre: _selectedGenre,
      status: _selectedStatus,
      type: _selectedType,
      sort: _selectedSort,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  'Jelajah',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
              ),

              // Search field + filter button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SakugaSearchField(
                        controller: _searchCtrl,
                        hintText: 'Judul manga, manhwa, manhua…',
                        onSubmitted: (_) => _executeSearch(),
                        showClear: _searchCtrl.text.isNotEmpty,
                        onClear: () {
                          _searchCtrl.clear();
                          context.read<MangaProvider>().clearSearch();
                          setState(() {});
                        },
                        onChanged: (val) {
                          setState(() {});
                          _debounce?.cancel();
                          _debounce = Timer(const Duration(milliseconds: 600), _executeSearch);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GlassIconButton(
                          icon: Icons.tune_rounded,
                          tooltip: 'Filter',
                          size: 46,
                          active: _hasAdvancedFilter,
                          onTap: _showFilterBottomSheet,
                        ),
                        if (_hasAdvancedFilter)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Genre pills — only once a search is active; idle state shows the genre grid
              if (_searchCtrl.text.isNotEmpty || _selectedGenre != null) SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _genres.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final genre = _genres[i];
                    final isSelected = _selectedGenre == genre;
                    return GlassPill(
                      label: genre,
                      selected: isSelected,
                      onTap: () {
                        setState(() => _selectedGenre = isSelected ? null : genre);
                        _executeSearch();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Results
              Expanded(
                child: Consumer<MangaProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoadingSearch) {
                      return const Center(child: GoogleDotsLoading(dotSize: 12, jumpHeight: 16));
                    }

                    if (provider.searchResults.isEmpty) {
                      final idle = _searchCtrl.text.isEmpty && _selectedGenre == null;
                      if (idle) return _buildGenreGrid();
                      return ListView(
                        children: const [
                          SizedBox(height: 40),
                          GlassEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'Tidak ditemukan',
                            message: 'Coba kata kunci lain atau longgarkan filternya.',
                          ),
                        ],
                      );
                    }

                    return CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.58,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 20,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => MangaCard(manga: provider.searchResults[index]),
                              childCount: provider.searchResults.length,
                            ),
                          ),
                        ),
                        if (provider.isLoadingMoreSearch)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: GoogleDotsLoading(dotSize: 9, spacing: 6, jumpHeight: 10),
                              ),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 110)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const Map<String, IconData> _genreIcons = {
    'Action': Icons.sports_martial_arts_rounded,
    'Adventure': Icons.explore_rounded,
    'Comedy': Icons.sentiment_very_satisfied_rounded,
    'Drama': Icons.theater_comedy_rounded,
    'Fantasy': Icons.auto_awesome_rounded,
    'Isekai': Icons.public_rounded,
    'Martial Arts': Icons.sports_kabaddi_rounded,
    'Mystery': Icons.search_rounded,
    'Psychological': Icons.psychology_rounded,
    'Romance': Icons.favorite_rounded,
    'Sci-Fi': Icons.rocket_launch_rounded,
    'Slice of Life': Icons.local_cafe_rounded,
    'Supernatural': Icons.nights_stay_rounded,
    'Thriller': Icons.bolt_rounded,
    'Magic': Icons.auto_fix_high_rounded,
    'School Life': Icons.school_rounded,
  };

  /// Idle state: browse by genre instead of staring at an empty screen.
  Widget _buildGenreGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 64,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _genres.length,
      itemBuilder: (context, i) {
        final genre = _genres[i];
        return LiquidGlassContainer(
          borderRadius: AppRadius.md,
          boxShadow: const [],
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: () {
            setState(() => _selectedGenre = genre);
            _executeSearch();
          },
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(_genreIcons[genre] ?? Icons.category_rounded, size: 19, color: AppColors.primaryLight),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  genre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Filter',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (_selectedStatus != null || _selectedType != null)
                          TextButton(
                            onPressed: () => setModalState(() {
                              _selectedStatus = null;
                              _selectedType = null;
                            }),
                            child: const Text('Reset'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _sheetLabel('Status'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (label, value) in const [
                          ('Semua', null),
                          ('Ongoing', 'ongoing'),
                          ('Tamat', 'completed'),
                        ])
                          GlassPill(
                            label: label,
                            selected: _selectedStatus == value,
                            onTap: () => setModalState(() => _selectedStatus = value),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    _sheetLabel('Tipe'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (label, value) in const [
                          ('Semua', null),
                          ('🇰🇷 Manhwa', 'manhwa'),
                          ('🇯🇵 Manga', 'manga'),
                          ('🇨🇳 Manhua', 'manhua'),
                        ])
                          GlassPill(
                            label: label,
                            selected: _selectedType == value,
                            onTap: () => setModalState(() => _selectedType = value),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {});
                          _executeSearch();
                        },
                        child: const Text('Terapkan'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted),
      ),
    );
  }
}
