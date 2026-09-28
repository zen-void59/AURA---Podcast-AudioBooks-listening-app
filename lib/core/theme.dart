import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class AuraColors {
  // Warm Cream palette
  static const Color cream = Color(0xFFFEFBF0);
  static const Color creamDeep = Color(0xFFF5F0DC);
  static const Color creamCard = Color(0xFFFAF7E8);
  static const Color creamBorder = Color(0xFFE8E2CC);
  static const Color creamMuted = Color(0xFFC8C4B4);

  // Dark charcoal text
  static const Color charcoal = Color(0xFF2A2820);
  static const Color charcoalMed = Color(0xFF5A5648);
  static const Color charcoalLight = Color(0xFF8A8474);

  // Accent — muted warm gold
  static const Color accent = Color(0xFFB8975A);
  static const Color accentLight = Color(0xFFD4B87A);

  // Now Playing dark palette
  static const Color darkBg = Color(0xFF1A1915);
  static const Color darkSurface = Color(0xFF252320);
  static const Color darkCard = Color(0xFF2F2D28);
  static const Color darkBorder = Color(0xFF3A3830);

  // Semantic
  static const Color success = Color(0xFF7A9E7E);
  static const Color error = Color(0xFFB85A5A);
  static const Color rust = Color(0xFFC06C4E);
  static const Color primaryDark = accent;
  static const Color surfaceDark = darkSurface;

  // Waveform
  static const Color waveformActive = Color(0xFFD4B87A);
  static const Color waveformInactive = Color(0xFF3A3830);

  // Dynamic Theme Helpers
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color primary(BuildContext context) => accent;

  static Color bg(BuildContext context) =>
      isDark(context) ? darkBg : cream;

  static Color card(BuildContext context) =>
      isDark(context) ? darkCard : creamCard;

  static Color cardDeep(BuildContext context) =>
      isDark(context) ? darkSurface : creamDeep;

  static Color border(BuildContext context) =>
      isDark(context) ? darkBorder : creamBorder;

  static Color text(BuildContext context) =>
      isDark(context) ? cream : charcoal;

  static Color subtext(BuildContext context) =>
      isDark(context) ? const Color(0xFFB8B4A8) : charcoalLight;

  static Color textMed(BuildContext context) =>
      isDark(context) ? const Color(0xFFD4D0C4) : charcoalMed;
}

class AuraTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AuraColors.cream,
      colorScheme: ColorScheme.light(
        primary: AuraColors.charcoal,
        secondary: AuraColors.accent,
        surface: AuraColors.creamCard,
        onPrimary: AuraColors.cream,
        onSecondary: AuraColors.cream,
        onSurface: AuraColors.charcoal,
        outline: AuraColors.creamBorder,
      ),
      textTheme: _buildTextTheme(isLight: true),
      appBarTheme: AppBarTheme(
        backgroundColor: AuraColors.cream,
        foregroundColor: AuraColors.charcoal,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 22,
          color: AuraColors.charcoal,
          fontWeight: FontWeight.w400,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AuraColors.cream,
        selectedItemColor: AuraColors.charcoal,
        unselectedItemColor: AuraColors.charcoalLight,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: AuraColors.creamCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AuraColors.creamBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AuraColors.creamBorder,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AuraColors.creamCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuraColors.creamBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuraColors.creamBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuraColors.charcoal, width: 1.5),
        ),
        hintStyle: GoogleFonts.dmSans(
          color: AuraColors.charcoalLight,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AuraColors.darkBg,
      colorScheme: ColorScheme.dark(
        primary: AuraColors.cream,
        secondary: AuraColors.accentLight,
        surface: AuraColors.darkSurface,
        onPrimary: AuraColors.darkBg,
        onSecondary: AuraColors.darkBg,
        onSurface: AuraColors.cream,
        outline: AuraColors.darkBorder,
      ),
      textTheme: _buildTextTheme(isLight: false),
      appBarTheme: AppBarTheme(
        backgroundColor: AuraColors.darkBg,
        foregroundColor: AuraColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 22,
          color: AuraColors.cream,
          fontWeight: FontWeight.w400,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AuraColors.darkBg,
        selectedItemColor: AuraColors.cream,
        unselectedItemColor: AuraColors.charcoalMed,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: AuraColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AuraColors.darkBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AuraColors.darkBorder,
        thickness: 1,
      ),
    );
  }

  static TextTheme _buildTextTheme({required bool isLight}) {
    final textColor = isLight ? AuraColors.charcoal : AuraColors.cream;
    final subtitleColor = isLight
        ? AuraColors.charcoalMed
        : const Color(0xFFB8B4A8);

    return TextTheme(
      // Display — DM Serif for headings
      displayLarge: GoogleFonts.dmSans(
        fontSize: 48,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      displayMedium: GoogleFonts.dmSans(
        fontSize: 36,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      displaySmall: GoogleFonts.dmSans(
        fontSize: 28,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      headlineLarge: GoogleFonts.dmSans(
        fontSize: 24,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      headlineMedium: GoogleFonts.dmSans(
        fontSize: 20,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      headlineSmall: GoogleFonts.dmSans(
        fontSize: 18,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      // Body — DM Sans
      titleLarge: GoogleFonts.dmSans(
        fontSize: 16,
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 14,
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: GoogleFonts.dmSans(
        fontSize: 12,
        color: subtitleColor,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        color: textColor,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12,
        color: subtitleColor,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14,
        color: textColor,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12,
        color: subtitleColor,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 10,
        color: subtitleColor,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
      ),
    );
  }
}
