import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_colors.dart';
import 'providers/auth_provider.dart';
import 'providers/bookmark_provider.dart';
import 'providers/history_provider.dart';
import 'providers/manga_provider.dart';
import 'screens/main_navigation_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (.env) with safe fallback
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: .env file could not be loaded: $e');
  }

  // Clear in-memory image cache to avoid decoder artifacts
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();

  // Set immersive dark status bar & navigation bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final authProvider = AuthProvider();
  final bookmarkProvider = BookmarkProvider();
  final historyProvider = HistoryProvider();
  final mangaProvider = MangaProvider();

  // Initialize storage & providers
  await authProvider.init();
  await bookmarkProvider.init(token: authProvider.token);
  await historyProvider.init(token: authProvider.token);

  runApp(
    NgomikApp(
      authProvider: authProvider,
      bookmarkProvider: bookmarkProvider,
      historyProvider: historyProvider,
      mangaProvider: mangaProvider,
    ),
  );
}

class NgomikApp extends StatelessWidget {
  final AuthProvider? authProvider;
  final BookmarkProvider? bookmarkProvider;
  final HistoryProvider? historyProvider;
  final MangaProvider? mangaProvider;

  const NgomikApp({
    super.key,
    this.authProvider,
    this.bookmarkProvider,
    this.historyProvider,
    this.mangaProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        if (authProvider != null)
          ChangeNotifierProvider.value(value: authProvider!)
        else
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        if (bookmarkProvider != null)
          ChangeNotifierProvider.value(value: bookmarkProvider!)
        else
          ChangeNotifierProvider(create: (_) => BookmarkProvider()),
        if (historyProvider != null)
          ChangeNotifierProvider.value(value: historyProvider!)
        else
          ChangeNotifierProvider(create: (_) => HistoryProvider()),
        if (mangaProvider != null)
          ChangeNotifierProvider.value(value: mangaProvider!)
        else
          ChangeNotifierProvider(create: (_) => MangaProvider()),
      ],
      child: MaterialApp(
        title: 'Ngomik',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainNavigationShell(),
      ),
    );
  }
}
