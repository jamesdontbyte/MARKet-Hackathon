import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MarketColors {
  MarketColors._();

  static const Color primary = Color(0xFF006689);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF3EC4FF);
  static const Color onPrimaryContainer = Color(0xFF004E6B);

  static const Color surface = Color(0xFFF8F9FF);
  static const Color onSurface = Color(0xFF0B1C30);
  static const Color onSurfaceVariant = Color(0xFF3E484F);

  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color surfaceContainer = Color(0xFFE5EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDCE9FF);
  static const Color surfaceContainerHighest = Color(0xFFD3E4FE);

  static const Color cardBorder = Color(0xFFF1F5F9);
  static const Color fieldBorder = Color(0xFFCBD5E1);
  static const Color outline = Color(0xFF6E7980);
  static const Color outlineVariant = Color(0xFFBDC8D1);

  static const Color link = Color(0xFF0284C7);
  static const Color promoBadgeBorder = Color(0xFFBAE6FD);
  static const Color promoBadgeBg = Color(0xFFF0F9FF);
  static const Color promoBadgeText = Color(0xFF0369A1);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
}

class MarketElevation {
  MarketElevation._();

  static const List<BoxShadow> level1 = [
    BoxShadow(
      color: Color(0x0A0F172A),
      offset: Offset(0, 4),
      blurRadius: 20,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x050F172A),
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: -1,
    ),
  ];

  static const List<BoxShadow> level2 = [
    BoxShadow(
      color: Color(0x140F172A),
      offset: Offset(0, 12),
      blurRadius: 32,
      spreadRadius: -4,
    ),
    BoxShadow(
      color: Color(0x080F172A),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: -2,
    ),
  ];
}

class MarketSpacing {
  MarketSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;

  static const double screenMargin = 16.0;
  static const double cardPadding = 16.0;
}

class MarketRadii {
  MarketRadii._();

  static const double sm = 4.0;
  static const double md = 8.0;
  static const double input = 10.0;
  static const double button = 12.0;
  static const double card = 16.0;
  static const double sheet = 24.0;
  static const double pill = 9999.0;
}

ThemeData buildMarketTheme() {
  final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

  final textTheme = baseTextTheme.copyWith(
    displayLarge: GoogleFonts.plusJakartaSans(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      height: 34 / 26,
      color: MarketColors.onSurface,
    ),
    headlineLarge: GoogleFonts.plusJakartaSans(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 32 / 24,
      color: MarketColors.onSurface,
    ),
    headlineMedium: GoogleFonts.plusJakartaSans(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 28 / 20,
      color: MarketColors.onSurface,
    ),
    headlineSmall: GoogleFonts.plusJakartaSans(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 24 / 18,
      color: MarketColors.onSurface,
    ),
    bodyLarge: GoogleFonts.plusJakartaSans(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 24 / 16,
      color: MarketColors.onSurface,
    ),
    bodyMedium: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
      color: MarketColors.onSurface,
    ),
    bodySmall: GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 18 / 13,
      color: MarketColors.onSurfaceVariant,
    ),
    labelLarge: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 20 / 14,
      color: MarketColors.onSurface,
    ),
    labelMedium: GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 16 / 12,
      color: MarketColors.onSurface,
    ),
    labelSmall: GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      height: 14 / 11,
      letterSpacing: 0.22,
      color: MarketColors.onSurfaceVariant,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: MarketColors.surface,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: MarketColors.primary,
      onPrimary: MarketColors.onPrimary,
      primaryContainer: MarketColors.primaryContainer,
      onPrimaryContainer: MarketColors.onPrimaryContainer,
      secondary: Color(0xFF565E74),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFDAE2FD),
      onSecondaryContainer: Color(0xFF5C647A),
      surface: MarketColors.surface,
      onSurface: MarketColors.onSurface,
      error: MarketColors.error,
      onError: Colors.white,
      outline: MarketColors.outline,
      outlineVariant: MarketColors.outlineVariant,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: MarketColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.headlineSmall,
      iconTheme: const IconThemeData(color: MarketColors.onSurface),
    ),
  );
}
