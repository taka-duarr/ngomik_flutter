import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/history_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/manga.dart';
import '../../models/reading_history.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/liquid_glass_container.dart';
import '../../widgets/bouncing_tap.dart';
import '../detail/manga_detail_screen.dart';
import '../reader/reader_screen.dart';
import '../auth/login_screen.dart';

class HistoryScreen extends StatefulWidget {
  /// Embedded in the profile hub: no Scaffold/app bar, actions move inline.
  final bool embedded;

  const HistoryScreen({super.key, this.embedded = false});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.token != null && auth.token!.isNotEmpty) {
        context.read<HistoryProvider>().syncRemoteHistory(auth.token!);
      }
    });
  }

  void _sync(HistoryProvider historyProvider, String? token) {
    if (token != null && token.isNotEmpty) {
      historyProvider.syncRemoteHistory(token);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Menyinkronkan riwayat baca…'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hubungkan akun terlebih dahulu.')),
      );
    }
  }

  void _confirmClear(HistoryProvider historyProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Hapus semua riwayat?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Semua riwayat komik yang kamu baca akan dibersihkan dari server. Tindakan ini tidak bisa dibatalkan.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              historyProvider.clearHistory();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Hapus semua'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyProvider = context.watch<HistoryProvider>();
    final authProvider = context.watch<AuthProvider>();

    if (widget.embedded) return _buildBody(historyProvider, authProvider);

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          titleSpacing: 20,
          title: Row(
            children: [
              const Text('Riwayat'),
              if (historyProvider.count > 0) ...[
                const SizedBox(width: 8),
                GlassTag(
                  label: '${historyProvider.count}',
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),
          actions: [
            GlassIconButton(
              icon: Icons.sync_rounded,
              tooltip: 'Sinkronkan riwayat',
              onTap: () => _sync(historyProvider, authProvider.token),
            ),
            if (historyProvider.history.isNotEmpty) ...[
              const SizedBox(width: 8),
              GlassIconButton(
                icon: Icons.delete_sweep_outlined,
                tooltip: 'Hapus semua riwayat',
                iconColor: AppColors.textSecondary,
                onTap: () => _confirmClear(historyProvider),
              ),
            ],
            const SizedBox(width: 16),
          ],
        ),
        body: _buildBody(historyProvider, authProvider),
      ),
    );
  }

  Widget _buildBody(
    HistoryProvider historyProvider,
    AuthProvider authProvider,
  ) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        final token = authProvider.token;
        if (token != null && token.isNotEmpty) {
          await historyProvider.syncRemoteHistory(token);
        }
      },
      child: authProvider.token == null
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 48),
                GlassEmptyState(
                  icon: Icons.history_rounded,
                  title: 'Hubungkan akun Shinigami',
                  message:
                      'Masuk untuk menyinkronkan riwayat komik yang sudah kamu baca di semua perangkat.',
                  actionLabel: 'Masuk akun',
                  actionIcon: Icons.login_rounded,
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                ),
              ],
            )
          : historyProvider.history.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 64),
                GlassEmptyState(
                  icon: Icons.auto_stories_outlined,
                  title: 'Belum ada riwayat',
                  message:
                      'Chapter yang kamu baca akan tercatat otomatis di sini.',
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              itemCount:
                  historyProvider.history.length + (widget.embedded ? 1 : 0),
              itemBuilder: (context, index) {
                if (widget.embedded) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${historyProvider.count} komik · geser untuk hapus',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _confirmClear(historyProvider),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                            child: const Text('Hapus semua'),
                          ),
                        ],
                      ),
                    );
                  }
                  index -= 1;
                }
                final item = historyProvider.history[index];
                return Dismissible(
                  key: Key('hist_${item.mangaId}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.danger,
                          size: 20,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Hapus',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  onDismissed: (_) =>
                      historyProvider.removeHistoryItem(item.mangaId),
                  child: _HistoryTile(item: item),
                );
              },
            ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ReadingHistoryItem item;

  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final manga = Manga(
      id: item.mangaId,
      title: item.mangaTitle,
      coverUrl: item.coverUrl,
      rating: item.userRate ?? 0,
    );
    final hasChapter =
        item.chapterNumber.isNotEmpty && item.chapterNumber != '0';

    return LiquidGlassContainer(
      margin: const EdgeInsets.only(bottom: 10),
      borderRadius: AppRadius.lg,
      boxShadow: const [],
      padding: const EdgeInsets.all(10),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MangaDetailScreen(mangaId: item.mangaId),
          ),
        );
      },
      child: Row(
        children: [
          // Cover thumbnail
          Container(
            width: 52,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            clipBehavior: Clip.antiAlias,
            child: AppNetworkImage(
              imageUrl: item.coverUrl,
              fit: BoxFit.cover,
              errorWidget: Container(color: AppColors.card),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.mangaTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      hasChapter
                          ? 'Ch. ${item.chapterNumber}'
                          : 'Terakhir dibaca',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    Container(
                      width: 3,
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: const BoxDecoration(
                        color: AppColors.textDisabled,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        DateFormatter.timeAgo(item.readAt.toIso8601String()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Resume
          Semantics(
            button: true,
            label: 'Lanjut baca ${item.mangaTitle}',
            child: BouncingTap(
              scaleFactor: 0.9,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReaderScreen(
                      chapterId: item.chapterId,
                      chapterNumber: item.chapterNumber,
                      manga: manga,
                    ),
                  ),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
