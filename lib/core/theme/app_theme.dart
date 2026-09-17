import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Manrope'; // falls back to system font
  // if the asset font isn't bundled yet — see pubspec.yaml fonts section.

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBgTop,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accentYellow,
        secondary: AppColors.accentOrange,
        surface: AppColors.darkSurface,
        error: AppColors.danger,
      ),
      textTheme: _textTheme(base.textTheme, AppColors.darkTextPrimary,
          AppColors.darkTextSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      dividerColor: AppColors.darkBorder,
      splashFactory: InkRipple.splashFactory,
    );
  }

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBgTop,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accentYellowDeep,
        secondary: AppColors.accentOrange,
        surface: AppColors.lightSurface,
        error: AppColors.danger,
      ),
      textTheme: _textTheme(base.textTheme, AppColors.lightTextPrimary,
          AppColors.lightTextSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),
      dividerColor: AppColors.lightBorder,
    );
  }

  static TextTheme _textTheme(TextTheme base, Color primary, Color secondary) {
    return base
        .copyWith(
          displayLarge: base.displayLarge
              ?.copyWith(fontWeight: FontWeight.w800, color: primary),
          headlineMedium: base.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: primary),
          titleLarge: base.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700, color: primary),
          titleMedium: base.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, color: primary),
          bodyLarge: base.bodyLarge?.copyWith(color: primary),
          bodyMedium: base.bodyMedium?.copyWith(color: secondary),
          labelSmall: base.labelSmall?.copyWith(color: secondary),
        )
        .apply(fontFamily: fontFamily);
  }

  /// Background gradient used behind every screen.
  static BoxDecoration backgroundDecoration(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [AppColors.darkBgTop, AppColors.darkBgBottom]
            : [AppColors.lightBgTop, AppColors.lightBgBottom],
      ),
    );
  }
}
