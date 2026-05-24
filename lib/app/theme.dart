import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ─── Semantic Color System (Light Theme) ────────────────────────────────────
  static const Color primary = Color(0xFF00A8E8);         // Primary Cyan
  static const Color primaryHover = Color(0xFF008FCC);    // Primary Hover/Pressed
  static const Color slateText = Color(0xFF1F2937);       // Slate Text (Primary)
  static const Color mutedText = Color(0xFF6B7280);       // Muted Text (Secondary)
  
  static const Color background = Color(0xFFF8FAFC);      // Off-white Background
  static const Color surface = Color(0xFFFFFFFF);         // White Surface
  static const Color border = Color(0xFFE5E7EB);          // Light Grey Border
  
  static const Color success = Color(0xFF16A34A);         // Green
  static const Color warning = Color(0xFFF59E0B);         // Amber
  static const Color danger = Color(0xFFDC2626);          // Red
  static const Color info = Color(0xFF0284C7);            // Blue
  static const Color disabled = Color(0xFFD1D5DB);        // Grey

  // ─── Legacy Colors (mapped to semantic colors to prevent breaking changes) ──
  static const Color primaryDark = primaryHover;
  static const Color primaryLight = Color(0xFF4AC2F0);
  static const Color accent = success;
  
  static const Color bgDark = background;
  static const Color surfaceDark = surface;
  static const Color cardDark = surface;
  static const Color elevatedDark = Color(0xFFF1F5F9); // Slightly darker surface for elevated elements
  static const Color borderDark = border;

  static const Color textPrimary = slateText;
  static const Color textSecondary = mutedText;
  static const Color textHint = Color(0xFF9CA3AF);

  // ─── Gradient ────────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryHover],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [background, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Light Theme ──────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primary,
        primaryContainer: primaryHover,
        secondary: success,
        surface: surface,
        error: danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: slateText,
        onError: Colors.white,
        outline: border,
      ),
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        titleTextStyle: GoogleFonts.inter(
          color: slateText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: slateText),
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: slateText,
        displayColor: slateText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger),
        ),
        hintStyle: const TextStyle(color: textHint),
        labelStyle: const TextStyle(color: mutedText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: slateText,
          side: const BorderSide(color: border),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: slateText,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: GoogleFonts.inter(
          color: slateText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: mutedText,
          fontSize: 14,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: mutedText,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: elevatedDark,
        selectedColor: primary.withValues(alpha: 0.15),
        labelStyle: GoogleFonts.inter(color: slateText, fontSize: 13, fontWeight: FontWeight.w500),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
    );
  }
}
