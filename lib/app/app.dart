/// Builds the root Material application and listens for global theme changes.

import 'package:flutter/material.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class PaidiXApp extends StatefulWidget {
  const PaidiXApp({super.key});

  /// Creates the mutable state object that backs this stateful widget.
  @override
  State<PaidiXApp> createState() => _PaidiXAppState();
}

class _PaidiXAppState extends State<PaidiXApp> {
  /// Initializes controllers, listeners, and other state owned by this widget.
  @override
  void initState() {
    super.initState();
    AppTheme.init();
  }

  /// Builds the widget subtree from its current properties and inherited context.
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
          themeAnimationDuration: const Duration(milliseconds: 350),
          themeAnimationCurve: Curves.easeInOutCubic,
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
