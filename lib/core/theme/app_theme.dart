import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Parchment's design language: modern, minimal, strictly monochrome.
///
/// No hue anywhere in the UI: black, white, and a small gray scale do
/// all the work. The app's launcher icon keeps its original indigo (a
/// deliberate exception for brand recognition on the home screen); the
/// in-app UI itself uses none of it. Buttons and inputs are square with
/// a modest 10px corner radius, never a stadium/pill shape.
///
/// `accent` is kept as the field name (rather than renaming to `ink`)
/// since existing screens already reference `AppTheme.accent` for icon
/// tints and focus states; it just now resolves to near-black instead
/// of indigo, so no screen files needed touching for this pass.
class AppTheme {
  AppTheme._();

  static const double radius = 10;

  // Monochrome scale: the only colors used anywhere in the UI.
  static const Color ink = Color(0xFF0A0A0A); // near-black, primary fill/text
  static const Color paper = Color(0xFFFFFFFF); // pure white background
  static const Color surface = Color(0xFFF7F7F7); // faint card/section tint
  static const Color border = Color(0xFFE4E4E4); // resting hairlines
  static const Color borderStrong = Color(0xFF1A1A1A); // focused borders
  static const Color muted = Color(0xFF6B6B6B); // secondary text
  static const Color subtle = Color(0xFFA0A0A0); // placeholders, disabled

  /// Alias for AppTheme.ink (see class doc). Existing screens use this
  /// name for icon color and focus accents.
  static const Color accent = ink;

  // Error is the one functional exception to strict monochrome: red
  // carries a universal, accessibility-relevant meaning for form
  // validation and failure states, not a brand color choice.
  static const Color _error = Color(0xFFB3261E);

  static ThemeData get light {
    final colorScheme = const ColorScheme.light(
      primary: ink,
      onPrimary: paper,
      secondary: ink,
      onSecondary: paper,
      surface: paper,
      onSurface: ink,
      surfaceContainerHighest: surface,
      outline: border,
      error: _error,
      onError: paper,
    );

    final headlineStyle = GoogleFonts.manrope(
      fontWeight: FontWeight.w700,
      color: ink,
      letterSpacing: -0.3,
    );
    final titleStyle = GoogleFonts.manrope(
      fontWeight: FontWeight.w600,
      color: ink,
    );
    final bodyFont = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: paper,
      splashFactory: NoSplash.splashFactory,

      textTheme: bodyFont.copyWith(
        headlineSmall: headlineStyle.copyWith(fontSize: 24),
        headlineMedium: headlineStyle.copyWith(fontSize: 28),
        titleLarge: titleStyle.copyWith(fontSize: 20),
        titleMedium: titleStyle.copyWith(fontSize: 16),
        bodyLarge: GoogleFonts.inter(color: ink, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: ink, fontSize: 14),
        bodySmall: GoogleFonts.inter(color: muted, fontSize: 12),
        labelMedium: GoogleFonts.inter(
          color: ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: GoogleFonts.inter(color: muted, fontSize: 11),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: titleStyle.copyWith(fontSize: 18),
        iconTheme: const IconThemeData(color: ink),
      ),

      // Every button variant gets the same square-rounded shape and
      // monochrome fill, so no Material 3 default stadium shapes survive.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: paper,
          disabledBackgroundColor: subtle,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: paper,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: border, width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ink,
        foregroundColor: paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius + 4),
        ),
      ),

      // Outline-box fields, not filled gray blobs: a thin resting
      // border that turns solid black on focus.
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: GoogleFonts.inter(color: muted),
        hintStyle: GoogleFonts.inter(color: subtle),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: borderStrong, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: _error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: _error, width: 1.6),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: paper,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius + 2),
          side: const BorderSide(color: border, width: 1),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(color: ink),

      dialogTheme: DialogThemeData(
        backgroundColor: paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius + 4),
        ),
        titleTextStyle: titleStyle.copyWith(fontSize: 18),
        contentTextStyle: GoogleFonts.inter(color: ink, fontSize: 14),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: GoogleFonts.inter(color: paper, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
