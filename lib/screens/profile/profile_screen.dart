import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/history_provider.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/bouncing_tap.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/liquid_glass_container.dart';
import '../auth/login_screen.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../history/history_screen.dart';
import '../main_navigation_shell.dart';
import '../settings/settings_screen.dart';

/// Profile hub: identity card on top, then Bookmark / Riwayat / Pengaturan
/// as segmented tabs that stick under the header while the content scrolls.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _sections = <(String, IconData)>[
    ('Bookmark', Icons.bookmark_rounded),
    ('Riwayat', Icons.history_rounded),
    ('Pengaturan', Icons.settings_outlined),
  ];

  void _syncAll(BuildContext context) {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) return;
    context.read<BookmarkProvider>().syncRemoteBookmarks(token);
    context.read<HistoryProvider>().syncRemoteHistory(token);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Menyinkronkan bookmark & riwayat…'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final signedIn = auth.token != null;

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: ValueListenableBuilder<int>(
            valueListenable: AppTab.profileSection,
            builder: (context, section, _) {
              return NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  // Title bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Profil',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                          if (signedIn)
                            IconButton(
                              tooltip: 'Sinkronkan',
                              onPressed: () => _syncAll(context),
                              icon: const Icon(Icons.sync_rounded),
                              color: AppColors.textSecondary,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: _IdentityCard()),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SectionTabs(
                      sections: _sections,
                      active: section,
                      onSelect: (i) => AppTab.profileSection.value = i,
                    ),
                  ),
                ],
                body: switch (section) {
                  0 => const BookmarksScreen(embedded: true),
                  1 => const HistoryScreen(embedded: true),
                  _ => const SettingsScreen(embedded: true),
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Identity card ─────────────────────────────────────────────────────────

class _IdentityCard extends StatelessWidget {
  const _IdentityCard();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final bookmarks = context.watch<BookmarkProvider>().count;
    final history = context.watch<HistoryProvider>().count;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: LiquidGlassContainer(
        borderRadius: AppRadius.xl,
        padding: const EdgeInsets.all(16),
        child: user == null
            ? Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.asset('assets/images/logo.png', width: 64, height: 64, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Belum masuk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Hubungkan akun Shinigami untuk sinkron bookmark & riwayat.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 38,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                            ),
                            icon: const Icon(Icons.login_rounded, size: 17),
                            label: const Text('Masuk'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.borderGlow, width: 1.4),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.lg - 3),
                          child: user.avatarImageUrl?.isNotEmpty == true
                              ? AppNetworkImage(
                                  imageUrl: user.avatarImageUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                                )
                              : Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.username,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GlassTag(
                                  label: user.isPremium ? 'Premium' : 'Member',
                                  filled: !user.isPremium,
                                  color: user.isPremium ? AppColors.amber : null,
                                ),
                              ],
                            ),
                            if (user.email?.isNotEmpty == true) ...[
                              const SizedBox(height: 3),
                              Text(
                                user.email!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                            const SizedBox(height: 8),
                            const Text(
                              '"Satu chapter lagi, habis itu tidur."',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Stat(value: '$bookmarks', label: 'Bookmark'),
                      _StatDivider(),
                      _Stat(value: '$history', label: 'Riwayat'),
                      _StatDivider(),
                      _Stat(value: user.isPremium ? 'Premium' : 'Gratis', label: 'Paket'),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: AppColors.border);
  }
}

// ── Segmented section tabs (pinned) ───────────────────────────────────────

class _SectionTabs extends SliverPersistentHeaderDelegate {
  final List<(String, IconData)> sections;
  final int active;
  final ValueChanged<int> onSelect;

  _SectionTabs({required this.sections, required this.active, required this.onSelect});

  static const double _height = 60;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: overlapsContent || shrinkOffset > 0 ? const Color(0xF2272C49) : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: List.generate(sections.length, (i) {
          final (label, icon) = sections[i];
          final selected = i == active;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == sections.length - 1 ? 0 : 8),
              child: Semantics(
                button: true,
                selected: selected,
                child: BouncingTap(
                  scaleFactor: 0.96,
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : const Color(0x591C2038),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: selected ? AppColors.primaryLight.withValues(alpha: 0.5) : AppColors.border,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: selected ? Colors.white : AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SectionTabs old) => old.active != active;
}
