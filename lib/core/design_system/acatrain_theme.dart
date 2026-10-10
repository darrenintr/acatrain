import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:acatrain/expressive.dart';
import 'package:acatrain/subscription.dart';

/// Branded font tokens shared by the theme and feature widgets.
const acatrainFontFamily = 'Google Sans Flex';
const acatrainFontFallback = ['Figtree'];

FontWeight _nearestWeight(double weight) {
  final steps = [100, 200, 300, 400, 500, 600, 700, 800, 900];
  final nearest = steps.reduce(
    (a, b) => (weight - a).abs() < (weight - b).abs() ? a : b,
  );
  return FontWeight.values[(nearest ~/ 100) - 1];
}

TextStyle _type({
  required double size,
  required double height,
  required double weight,
  double letterSpacing = 0,
}) => TextStyle(
  fontFamily: acatrainFontFamily,
  fontFamilyFallback: acatrainFontFallback,
  fontSize: size,
  height: height / size,
  fontWeight: _nearestWeight(weight),
  fontVariations: [FontVariation('wght', weight)],
  letterSpacing: letterSpacing,
);

/// Single source of truth for ACATRAIN Material 3 light/dark themes.
ThemeData buildAcatrainTheme(Brightness brightness, AcatrainPlan plan) {
  final colors =
      planColorScheme(plan, brightness) ??
      (brightness == Brightness.light
          ? const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF36684F),
            onPrimary: Color(0xFFFFFFFF),
            primaryContainer: Color(0xFFB8F0CF),
            onPrimaryContainer: Color(0xFF0E3A26),
            secondary: Color(0xFF4E6356),
            onSecondary: Color(0xFFFFFFFF),
            secondaryContainer: Color(0xFFD0E8D7),
            onSecondaryContainer: Color(0xFF0B2616),
            tertiary: Color(0xFF3B6470),
            onTertiary: Color(0xFFFFFFFF),
            tertiaryContainer: Color(0xFFBFE9F8),
            onTertiaryContainer: Color(0xFF0A3642),
            error: Color(0xFFBA1A1A),
            onError: Color(0xFFFFFFFF),
            errorContainer: Color(0xFFFFDAD6),
            onErrorContainer: Color(0xFF410002),
            surface: Color(0xFFF6FBF4),
            onSurface: Color(0xFF171D19),
            surfaceContainerLowest: Color(0xFFFFFFFF),
            surfaceContainerLow: Color(0xFFF0F5EE),
            surfaceContainer: Color(0xFFEAEFE9),
            surfaceContainerHigh: Color(0xFFE4EAE3),
            surfaceContainerHighest: Color(0xFFDFE4DD),
            onSurfaceVariant: Color(0xFF404943),
            outline: Color(0xFF707973),
            outlineVariant: Color(0xFFC0C9C1),
            inverseSurface: Color(0xFF2C322E),
            onInverseSurface: Color(0xFFEDF2EB),
            inversePrimary: Color(0xFF9DD4B4),
          )
          : ColorScheme.fromSeed(
            seedColor: const Color(0xFF426B58),
            brightness: Brightness.dark,
          ));
  final tones =
      plan != AcatrainPlan.free
          ? planTones(plan, colors)
          : brightness == Brightness.light
          ? AcatrainTones.light
          : AcatrainTones.dark(colors);

  final textTheme = TextTheme(
    displaySmall: _type(
      size: 36,
      height: 42,
      weight: 750,
      letterSpacing: -1.2,
    ),
    headlineLarge: _type(
      size: 32,
      height: 38,
      weight: 750,
      letterSpacing: -1.0,
    ),
    headlineMedium: _type(
      size: 28,
      height: 34,
      weight: 700,
      letterSpacing: -0.5,
    ),
    headlineSmall: _type(
      size: 24,
      height: 30,
      weight: 700,
      letterSpacing: -0.4,
    ),
    titleLarge: _type(size: 20, height: 26, weight: 700, letterSpacing: -0.3),
    titleMedium: _type(
      size: 16,
      height: 22,
      weight: 650,
      letterSpacing: -0.1,
    ),
    titleSmall: _type(size: 14, height: 20, weight: 650),
    bodyLarge: _type(size: 16, height: 24, weight: 400),
    bodyMedium: _type(size: 14, height: 20, weight: 400),
    bodySmall: _type(size: 12, height: 16, weight: 400),
    labelLarge: _type(size: 14, height: 20, weight: 650),
    labelMedium: _type(size: 12, height: 16, weight: 600),
    labelSmall: _type(size: 12, height: 16, weight: 700, letterSpacing: 0.8),
  ).apply(bodyColor: colors.onSurface, displayColor: colors.onSurface);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    visualDensity: VisualDensity.standard,
    fontFamily: _fontFamily,
    textTheme: textTheme,
    extensions: [tones],
    appBarTheme: AppBarTheme(
      toolbarHeight: 64,
      scrolledUnderElevation: 0,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: colors.onSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerHigh,
      hintStyle: TextStyle(color: colors.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AcatrainRadii.full),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AcatrainRadii.full),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AcatrainRadii.full),
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AcatrainRadii.xl),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      elevation: 0,
      backgroundColor: colors.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.secondaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AcatrainRadii.l),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return _type(
          size: 12,
          height: 16,
          weight: selected ? 700 : 550,
        ).copyWith(
          color: selected ? colors.onSurface : colors.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color:
              selected
                  ? colors.onSecondaryContainer
                  : colors.onSurfaceVariant,
        );
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: _type(size: 16, height: 20, weight: 650),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: _type(size: 16, height: 20, weight: 650),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const StadiumBorder(),
        textStyle: _type(size: 14, height: 20, weight: 650),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
      },
    ),
  );
}
