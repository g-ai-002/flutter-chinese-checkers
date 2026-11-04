import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'providers/settings_provider.dart';
import 'services/music_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';

class TiaoqiApp extends StatefulWidget {
  const TiaoqiApp({super.key, required this.storage});

  final StorageService storage;

  @override
  State<TiaoqiApp> createState() => _TiaoqiAppState();
}

class _TiaoqiAppState extends State<TiaoqiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        MusicService.resumeForLifecycle();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        MusicService.pauseForLifecycle();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = appFontFamily();
    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(widget.storage),
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(fontFamily: fontFamily),
            darkTheme: buildDarkTheme(fontFamily: fontFamily),
            themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh', 'CN')],
            locale: const Locale('zh', 'CN'),
            // Web 首次点击用于解除浏览器的自动播放限制。
            builder: (context, child) => Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: kIsWeb
                  ? (_) => MusicService.retryOnInteraction()
                  : null,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
