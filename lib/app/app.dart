import 'package:flutter/material.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class PaidiXApp extends StatefulWidget {
  const PaidiXApp({super.key});

  @override
  State<PaidiXApp> createState() => _PaidiXAppState();
}

class _PaidiXAppState extends State<PaidiXApp> {
  @override
  void initState() {
    super.initState();
    AppTheme.init();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppTheme.themeModeNotifier,
        AppTheme.fontFamilyNotifier,
        AppTheme.textScaleNotifier,
      ]),
      builder: (context, _) {
        final themeMode = AppTheme.currentThemeMode;
        final font = AppTheme.currentFontFamily;
        final scale = AppTheme.currentTextScale;

        return MaterialApp.router(
          title: 'PaidiX',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getLightTheme(font),
          darkTheme: AppTheme.getDarkTheme(font),
          themeMode: themeMode,
          routerConfig: appRouter,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            );
          },
        );
      },
    );
  }
}
