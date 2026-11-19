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
import 'services/shngm_api_service.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (.env) with safe fallback
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: .env file could not be loaded: $e');
  }

  // Optimize image cache: 500 images max, 400 MB max — prevents evicting read comic strips when scrolling
  PaintingBinding.instance.imageCache.maximumSize = 500;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 400 * 1024 * 1024;

  // Set immersive dark status bar & navigation bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final authProvider = AuthProvider();
  final bookmarkProvider = BookmarkProvider();
  final historyProvider = HistoryProvider();
  final mangaProvider = MangaProvider();

  // Self-healing auth: transparently refresh session on 401 API responses
  ShngmApiService.onTokenRefresh = () async {
    final refreshed = await authProvider.refreshTokenSilently();
    if (refreshed) {
      return authProvider.token;
    }
    return null;
  };

  // Providers are initialised while the animated splash plays, instead of
  // blocking the first frame.
  // Real progress for the splash bar: auth first, then bookmarks and history
  // in parallel, each finished step moving the bar on.
  Future<void> bootstrap(ValueChanged<double> report) async {
    report(0.08);
    await authProvider.init();
    report(0.45);
    var finished = 0;
    void stepDone() => report(0.45 + 0.55 * (++finished / 2));
    await Future.wait([
      bookmarkProvider.init(token: authProvider.token).whenComplete(stepDone),
      historyProvider.init(token: authProvider.token).whenComplete(stepDone),
    ]);
  }

  runApp(
    NgomikApp(
      authProvider: authProvider,
      bookmarkProvider: bookmarkProvider,
      historyProvider: historyProvider,
      mangaProvider: mangaProvider,
      bootstrap: bootstrap,
    ),
  );
}

class NgomikApp extends StatelessWidget {
  final AuthProvider? authProvider;
  final BookmarkProvider? bookmarkProvider;
  final HistoryProvider? historyProvider;
  final MangaProvider? mangaProvider;
  final SplashBootstrap? bootstrap;

  const NgomikApp({
    super.key,
    this.authProvider,
    this.bookmarkProvider,
    this.historyProvider,
    this.mangaProvider,
    this.bootstrap,
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
        // One shared backdrop for every grouped frosted surface (nav bar,
        // pinned headers, glass panels): the engine reads the scene behind
        // them once per frame instead of once per blur.
        builder: (context, child) => BackdropGroup(child: child!),
        home: SplashScreen(bootstrap: bootstrap),
      ),
    );
  }
}
