// App theme — dark, cable-box style (TiviMate-like layout, our own look).
//
// Very dark background, one accent colour, large touch targets (>=48dp).
// No TiviMate branding anywhere: neutral name "TVmagic", our own blue
// accent (not TiviMate's teal), no copied logo/artwork.
import 'package:flutter/material.dart';

class AppTheme {
  // Core palette.
  static const Color background = Color(0xFF0B0D12); // near-black page
  static const Color surface = Color(0xFF161A23); // cards, sheets, rails
  static const Color surfaceVariant = Color(0xFF1E2330); // raised / hover
  static const Color accent = Color(0xFF0A84FF); // primary accent (blue)
  static const Color accentDim = Color(0xFF2E6DB4);
  static const Color textPrimary = Color(0xFFF2F3F7);
  static const Color textSecondary = Color(0xFF9AA0B4);
  static const Color border = Color(0xFF2A2F3D);
  static const Color danger = Color(0xFFFF453A);
  static const Color success = Color(0xFF30D158);

  /// Minimum touch-target size (dp). Every tappable row/button is >= this.
  static const double minTouchTarget = 48.0;

  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;

  static ThemeData get dark {
    final colorScheme = const ColorScheme.dark(
      primary: accent,
      secondary: accent,
      surface: surface,
      onPrimary: Colors.white,
      onSurface: textPrimary,
      error: danger,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.02,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 11),
        elevation: 0,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: surface,
        selectedIconTheme: IconThemeData(color: accent, size: 26),
        unselectedIconTheme: IconThemeData(color: textSecondary, size: 26),
        selectedLabelTextStyle: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: TextStyle(color: textSecondary, fontSize: 12),
        indicatorColor: Color(0xFF1E2A3A),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
          side: BorderSide(color: border),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 8,
        iconColor: textSecondary,
        textColor: textPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceVariant,
        contentTextStyle: TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12),
        labelLarge: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
