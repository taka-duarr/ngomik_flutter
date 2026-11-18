import 'package:flutter/material.dart';
import '../widgets/custom_bottom_nav.dart';
import 'home/home_screen.dart';
import 'search/search_screen.dart';
import 'ranking/ranking_screen.dart';
import 'updates/updates_screen.dart';
import 'profile/profile_screen.dart';

/// Tab order mirrors the bottom bar: Jelajah · Populer · Home · Update · Profil.
/// Home sits in the middle and is the landing tab.
class AppTab {
  AppTab._();
  static const int explore = 0;
  static const int ranking = 1;
  static const int home = 2;
  static const int updates = 3;
  static const int profile = 4;

  /// Lets any screen inside the shell switch tabs without prop-drilling.
  static final ValueNotifier<int> current = ValueNotifier(home);

  /// Which sub-tab the profile hub should show (0 bookmark, 1 riwayat, 2 pengaturan).
  static final ValueNotifier<int> profileSection = ValueNotifier(0);

  static void go(int tab, {int? profileTab}) {
    if (profileTab != null) profileSection.value = profileTab;
    current.value = tab;
  }
}

class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({super.key});

  static const List<Widget> _screens = [
    SearchScreen(),
    RankingScreen(),
    HomeScreen(),
    UpdatesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppTab.current,
      builder: (context, index, _) {
        return PopScope(
          // Back from any tab returns Home first instead of closing the app.
          canPop: index == AppTab.home,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) AppTab.go(AppTab.home);
          },
          child: Scaffold(
            extendBody: true,
            body: IndexedStack(index: index, children: _screens),
            bottomNavigationBar: CustomBottomNav(
              currentIndex: index,
              onTap: AppTab.go,
            ),
          ),
        );
      },
    );
  }
}
