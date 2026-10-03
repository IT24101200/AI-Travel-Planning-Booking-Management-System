import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_constants.dart';

/// Centralized light and dark ThemeData for Serendib Trails.
class AppTheme {
  // ── Dark-mode specific color tokens ──
  static const Color darkSurface = Color(0xFF121A17);
  static const Color darkCard = Color(0xFF1A2722);
  static const Color darkLine = Color(0xFF2E3D36);
  static const Color darkInk = Color(0xFFE0EDE6);
  static const Color darkInk2 = Color(0xFFB0C7BA);
  static const Color darkInk3 = Color(0xFF7FA393);

  // ── Light Theme (matches existing design exactly) ──
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.ivory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.jungle600,
        brightness: Brightness.light,
        primary: AppColors.jungle600,
        secondary: AppColors.sand500,
        surface: AppColors.paper,
        surfaceContainerLowest: AppColors.ivory,
        error: AppColors.coral500,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
        bodyColor: AppColors.ink2,
        displayColor: AppColors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.jungle800,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.jungle600,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.jungle600, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.ink3, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line, width: 0.8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }

  // ── Dark Theme (forest-green dark palette) ──
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkSurface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.jungle600,
        brightness: Brightness.dark,
        primary: AppColors.leaf400,
        secondary: AppColors.sand400,
        surface: darkCard,
        error: AppColors.coral400,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: darkInk2,
        displayColor: darkInk,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0E1F18),
        foregroundColor: darkInk,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: darkInk,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: Color(0xFFE0EDE6)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.leaf400,
          foregroundColor: const Color(0xFF06231B),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E3D36)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E3D36)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.leaf400, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: darkInk3, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF2E3D36), width: 0.8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}
