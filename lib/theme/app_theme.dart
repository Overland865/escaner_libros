import 'package:flutter/material.dart';

/// Sistema de diseño editorial clásico y amigable para la Biblioteca Digital,
/// derivado directamente del modelado generado en Google Stitch.
class AppTheme {
  // Paleta Modo Claro (Papel pergamino, café espresso, cuero y ámbar cálido)
  static const Color lightBackground = Color(0xFFFAF7F2);
  static const Color lightSurface = Color(0xFFFCF9F4);
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainer = Color(0xFFF0EDE9);
  static const Color lightPrimary = Color(0xFF2C1810); // Espresso profundo
  static const Color lightPrimaryContainer = Color(0xFFEFE6DF);
  static const Color lightSecondary = Color(0xFF8C4E26); // Cuero cálido
  static const Color lightSecondaryContainer = Color(0xFFFCEFE7);
  static const Color lightTertiary = Color(0xFFB07D48); // Ámbar / dorado
  static const Color lightOutline = Color(0xFFD6CBC3);
  static const Color lightOutlineVariant = Color(0xFFE8E0D8);
  static const Color lightTextPrimary = Color(0xFF1C1C19);
  static const Color lightTextSecondary = Color(0xFF6B5E57);

  // Paleta Modo Oscuro (Biblioteca Nocturna en nogal cálido y cuero suave)
  static const Color darkBackground = Color(0xFF161311); // Carbón y madera
  static const Color darkSurface = Color(0xFF211C19); // Nogal oscuro
  static const Color darkSurfaceCard = Color(0xFF28221E);
  static const Color darkSurfaceContainer = Color(0xFF2F2925);
  static const Color darkPrimary = Color(0xFFE3BFB2); // Pergamino luminoso
  static const Color darkPrimaryContainer = Color(0xFF3F2B22);
  static const Color darkSecondary = Color(0xFFD4A373); // Cuero tostado cálido
  static const Color darkSecondaryContainer = Color(0xFF453023);
  static const Color darkTertiary = Color(0xFFE5C399);
  static const Color darkOutline = Color(0xFF4D4037);
  static const Color darkOutlineVariant = Color(0xFF372D26);
  static const Color darkTextPrimary = Color(0xFFF5EFEB);
  static const Color darkTextSecondary = Color(0xFFAFA399);

  /// Tema Claro Editorial
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: lightPrimary,
      onPrimary: Colors.white,
      primaryContainer: lightPrimaryContainer,
      onPrimaryContainer: lightPrimary,
      secondary: lightSecondary,
      onSecondary: Colors.white,
      secondaryContainer: lightSecondaryContainer,
      onSecondaryContainer: lightSecondary,
      tertiary: lightTertiary,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFF5E5D3),
      onTertiaryContainer: const Color(0xFF4A3010),
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
      surface: lightSurface,
      onSurface: lightTextPrimary,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: lightSurface,
      surfaceContainer: lightSurfaceContainer,
      surfaceContainerHigh: const Color(0xFFEAE5DF),
      surfaceContainerHighest: const Color(0xFFE2DDD7),
      onSurfaceVariant: lightTextSecondary,
      outline: lightOutline,
      outlineVariant: lightOutlineVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: lightSurface,
        foregroundColor: lightPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: lightPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: lightPrimary),
      ),
      cardTheme: CardThemeData(
        color: lightSurfaceCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightOutlineVariant, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        elevation: 0,
        indicatorColor: lightSecondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? lightSecondary : lightTextSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: isSelected ? lightSecondary : lightTextSecondary,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: Color(0xFF9E928A), fontSize: 14),
        labelStyle: const TextStyle(color: lightTextSecondary, fontSize: 14),
        prefixIconColor: lightSecondary,
        suffixIconColor: lightSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightOutlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightOutlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightSecondary, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lightSecondary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurfaceContainer,
        labelStyle: const TextStyle(
          fontSize: 12,
          color: lightTextPrimary,
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: lightOutlineVariant, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Tema Oscuro Biblioteca Nocturna
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: darkPrimary,
      onPrimary: darkBackground,
      primaryContainer: darkPrimaryContainer,
      onPrimaryContainer: darkPrimary,
      secondary: darkSecondary,
      onSecondary: darkBackground,
      secondaryContainer: darkSecondaryContainer,
      onSecondaryContainer: darkSecondary,
      tertiary: darkTertiary,
      onTertiary: darkBackground,
      tertiaryContainer: const Color(0xFF4A341E),
      onTertiaryContainer: darkTertiary,
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      surface: darkSurface,
      onSurface: darkTextPrimary,
      surfaceContainerLowest: const Color(0xFF110E0D),
      surfaceContainerLow: darkBackground,
      surfaceContainer: darkSurfaceContainer,
      surfaceContainerHigh: const Color(0xFF352F2B),
      surfaceContainerHighest: const Color(0xFF3D3631),
      onSurfaceVariant: darkTextSecondary,
      outline: darkOutline,
      outlineVariant: darkOutlineVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: darkSurfaceCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkOutlineVariant, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        elevation: 0,
        indicatorColor: darkSecondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? darkSecondary : darkTextSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: isSelected ? darkSecondary : darkTextSecondary,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceContainer,
        hintStyle: const TextStyle(color: Color(0xFF8A7F76), fontSize: 14),
        labelStyle: const TextStyle(color: darkTextSecondary, fontSize: 14),
        prefixIconColor: darkSecondary,
        suffixIconColor: darkSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkOutlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkOutlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkSecondary, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkSecondary,
          foregroundColor: darkBackground,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkSecondary,
        foregroundColor: darkBackground,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceContainer,
        labelStyle: const TextStyle(
          fontSize: 12,
          color: darkTextPrimary,
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: darkOutlineVariant, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

