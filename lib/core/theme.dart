import 'package:flutter/material.dart';

abstract final class Civic {
  static const navy = Color(0xFF102C46);
  static const blue = Color(0xFF185ADB);
  static const teal = Color(0xFF087F83);
  static const canvas = Color(0xFFF3F6FA);
  static const ink = Color(0xFF172F44);
  static const muted = Color(0xFF526679);
  static ThemeData theme() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: blue,
      primary: blue,
      secondary: teal,
      surface: Colors.white,
      onSurface: ink,
    ),
    scaffoldBackgroundColor: canvas,
    fontFamily: 'Noto Sans',
    fontFamilyFallback: const ['Noto Sans Khmer', 'Noto Sans'],
    appBarTheme: const AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E7EF)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.all(16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFE5EEFF),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE0E7EF), space: 24),
  );
}
