import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/manga_provider.dart';
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
  String? _selectedGenre;
  String? _selectedStatus;
  String? _selectedType;
  final String _selectedSort = 'latest';

  final List<String> _genres = [
    'Action', 'Adventure', 'Comedy', 'Drama', 'Fantasy', 'Isekai',
    'Martial Arts', 'Mystery', 'Psychological', 'Romance', 'Sci-Fi',
    'Slice of Life', 'Supernatural', 'Thriller', 'Magic', 'School Life'
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
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
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 42,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _executeSearch(),
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Cari judul manga, manhwa...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                      onPressed: () {
                        _searchCtrl.clear();
                        context.read<MangaProvider>().clearSearch();
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (val) => setState(() {}),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Horizontal Scroll
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Filter Button
                  GestureDetector(
                    onTap: _showFilterBottomSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (_selectedStatus != null || _selectedType != null)
                            ? AppColors.primary
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Filter',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Genre Chips
                  ..._genres.map((genre) {
                    final isSelected = _selectedGenre == genre;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(genre),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedGenre = selected ? genre : null;
                          });
                          _executeSearch();
                        },
                        backgroundColor: AppColors.card,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? AppColors.primaryLight : AppColors.textSecondary,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        showCheckmark: false,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Search Results
          Expanded(
            child: Consumer<MangaProvider>(
              builder: (context, provider, child) {
                if (provider.isLoadingSearch) {
                  return const Center(
                    child: GoogleDotsLoading(dotSize: 12, jumpHeight: 16),
                  );
                }

                if (provider.searchResults.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: AppColors.textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchCtrl.text.isEmpty
                              ? 'Ketik judul komik atau pilih genre untuk mencari'
                              : 'Tidak ada komik yang ditemukan',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 18,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final manga = provider.searchResults[index];
                            return MangaCard(manga: manga);
                          },
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
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Pencarian',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status
                  const Text(
                    'Status Komik',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildModalChip('Semua', null, _selectedStatus, (val) {
                        setModalState(() => _selectedStatus = val);
                      }),
                      const SizedBox(width: 8),
                      _buildModalChip('Ongoing', 'ongoing', _selectedStatus, (val) {
                        setModalState(() => _selectedStatus = val);
                      }),
                      const SizedBox(width: 8),
                      _buildModalChip('Tamat (Completed)', 'completed', _selectedStatus, (val) {
                        setModalState(() => _selectedStatus = val);
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Type
                  const Text(
                    'Tipe Komik',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildModalChip('Semua', null, _selectedType, (val) {
                        setModalState(() => _selectedType = val);
                      }),
                      const SizedBox(width: 8),
                      _buildModalChip('🇰🇷 Manhwa', 'manhwa', _selectedType, (val) {
                        setModalState(() => _selectedType = val);
                      }),
                      const SizedBox(width: 8),
                      _buildModalChip('🇯🇵 Manga', 'manga', _selectedType, (val) {
                        setModalState(() => _selectedType = val);
                      }),
                      const SizedBox(width: 8),
                      _buildModalChip('🇨🇳 Manhua', 'manhua', _selectedType, (val) {
                        setModalState(() => _selectedType = val);
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {});
                        _executeSearch();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Terapkan Filter',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalChip(
    String label,
    String? value,
    String? currentValue,
    ValueChanged<String?> onSelected,
  ) {
    final isSelected = value == currentValue;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
