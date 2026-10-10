import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:acatrain/core/design_system/acatrain_theme.dart';
import 'package:acatrain/features/shell/presentation/home_shell.dart';
import 'package:acatrain/launch_screen.dart';
import 'package:acatrain/store.dart';
import 'package:acatrain/subscription.dart';

class AcatrainApp extends StatelessWidget {
  const AcatrainApp({super.key, required this.store, this.ready});
  final AppStore store;

  /// Start-up work to play the launch animation over. Without it the home
  /// screen shows straight away (the store must already be loaded).
  final Future<void>? ready;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder:
        (context, _) => MaterialApp(
          title: 'Acatrain',
          debugShowCheckedModeBanner: false,
          locale:
              store.languageCode == 'zh_HK'
                  ? const Locale('zh', 'HK')
                  : const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('zh', 'HK')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: switch (store.appearance) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          // A slower morph so switching plans feels like an unveiling.
          themeAnimationDuration: const Duration(milliseconds: 900),
          themeAnimationCurve: Curves.easeInOutCubic,
          // Settings → Motion → Reduced forces the reduce-motion path
          // everywhere, whatever the device setting says.
          builder:
              (context, child) =>
                  store.motion == 'reduced'
                      ? MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(disableAnimations: true),
                        child: child!,
                      )
                      : child!,
          theme: buildAcatrainTheme(Brightness.light, AcatrainPlan.fromId(store.plan)),
          darkTheme: buildAcatrainTheme(Brightness.dark, AcatrainPlan.fromId(store.plan)),
          home:
              ready == null
                  ? HomeShell(store: store)
                  : AcatrainLaunchScreen(
                    ready: ready,
                    child: HomeShell(store: store),
                  ),
        ),
  );
}

