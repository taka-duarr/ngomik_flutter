import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/google_dots_loading.dart';
import '../../widgets/manga_card.dart';
import '../auth/login_screen.dart';

class BookmarksScreen extends StatefulWidget {
  /// Embedded in the profile hub: returns the body only.
  final bool embedded;

  const BookmarksScreen({super.key, this.embedded = false});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final TextEditingController _filterCtrl = TextEditingController();
  String _filterQuery = '';

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkProvider = context.watch<BookmarkProvider>();
    final authProvider = context.watch<AuthProvider>();
    final signedIn = authProvider.token != null;

    final appBar = AppBar(
      titleSpacing: 20,
      title: Row(
        children: [
          const Text('Bookmark'),
          if (signedIn && bookmarkProvider.count > 0) ...[
            const SizedBox(width: 8),
            GlassTag(label: '${bookmarkProvider.count}', color: AppColors.textSecondary),
          ],
        ],
      ),
      actions: [
        if (signedIn)
          GlassIconButton(
            icon: Icons.sync_rounded,
            tooltip: 'Sinkronkan bookmark',
            onTap: () {
              bookmarkProvider.syncRemoteBookmarks(authProvider.token!);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Menyinkronkan bookmark…'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        const SizedBox(width: 16),
      ],
    );

    Widget body;
    if (!signedIn) {
      body = ListView(
        children: [
          const SizedBox(height: 48),
          GlassEmptyState(
            icon: Icons.bookmark_border_rounded,
            title: 'Masuk untuk melihat bookmark',
            message: 'Komik favoritmu tersimpan di akun Shinigami, jadi tidak membebani memori HP.',
            actionLabel: 'Hubungkan akun',
            actionIcon: Icons.login_rounded,
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
          ),
        ],
      );
    } else if (bookmarkProvider.isLoading) {
      body = const Center(child: GoogleDotsLoading(dotSize: 12, jumpHeight: 16));
    } else if (bookmarkProvider.bookmarks.isEmpty) {
      body = ListView(
        children: const [
          SizedBox(height: 64),
          GlassEmptyState(
            icon: Icons.bookmark_add_outlined,
            title: 'Belum ada komik tersimpan',
            message: 'Tekan ikon bookmark di halaman komik untuk menyimpannya di sini.',
          ),
        ],
      );
    } else {
      final query = _filterQuery.toLowerCase();
      final filteredList = bookmarkProvider.bookmarks
          .where((m) => query.isEmpty || m.title.toLowerCase().contains(query))
          .toList();

      body = RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () => bookmarkProvider.syncRemoteBookmarks(authProvider.token!),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: GlassSearchField(
                  controller: _filterCtrl,
                  hintText: 'Cari di bookmark…',
                  onChanged: (val) => setState(() => _filterQuery = val),
                  showClear: _filterQuery.isNotEmpty,
                  onClear: () {
                    _filterCtrl.clear();
                    setState(() => _filterQuery = '');
                  },
                ),
              ),
            ),
            if (filteredList.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  child: Text(
                    'Tidak ada bookmark dengan judul "$_filterQuery"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.58,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 20,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => MangaCard(manga: filteredList[index]),
                    childCount: filteredList.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      );
    }

    if (widget.embedded) return body;

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: body,
      ),
    );
  }
}
