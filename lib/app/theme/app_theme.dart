import 'package:flutter/material.dart';

import 'brand_colors.dart';

abstract final class AppTheme {
  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: BrandColors.navy,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? BrandColors.sky : BrandColors.navy,
          onPrimary: isDark ? BrandColors.ink : BrandColors.cream,
          primaryContainer: isDark ? BrandColors.navy : BrandColors.sky,
          onPrimaryContainer: isDark ? BrandColors.cream : BrandColors.ink,
          secondary: isDark ? BrandColors.sky : BrandColors.navy,
          onSecondary: isDark ? BrandColors.ink : BrandColors.cream,
          secondaryContainer: isDark
              ? const Color(0xFF304366)
              : BrandColors.sky,
          onSecondaryContainer: isDark ? BrandColors.cream : BrandColors.ink,
          tertiary: isDark ? BrandColors.pink : const Color(0xFF914354),
          onTertiary: isDark ? BrandColors.ink : BrandColors.cream,
          tertiaryContainer: isDark
              ? const Color(0xFF583445)
              : BrandColors.pink,
          onTertiaryContainer: isDark ? BrandColors.cream : BrandColors.ink,
          surface: isDark ? const Color(0xFF171F33) : BrandColors.cream,
          onSurface: isDark ? BrandColors.cream : BrandColors.ink,
          onSurfaceVariant: isDark
              ? const Color(0xFFC2CCDF)
              : const Color(0xFF505C75),
          surfaceContainerLow: isDark
              ? const Color(0xFF202B42)
              : const Color(0xFFFFFDF5),
          surfaceContainer: isDark
              ? const Color(0xFF26324B)
              : const Color(0xFFFFFAE9),
          surfaceContainerHigh: isDark
              ? const Color(0xFF2D3A55)
              : const Color(0xFFF0EBD9),
          surfaceContainerHighest: isDark
              ? const Color(0xFF354361)
              : const Color(0xFFE8E4D6),
          outline: isDark ? const Color(0xFF9EACC7) : const Color(0xFF6B7590),
          outlineVariant: isDark
              ? const Color(0xFF4D5D7C)
              : const Color(0xFFD3D7E1),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.all(16),
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.tertiaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
