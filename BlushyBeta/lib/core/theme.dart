import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BlushyColors {
  // Brand Colors
  static const Color background = Color(0xFFFAF6F0); // 90% neutral interface
  static const Color primary = Color(0xFFDD0D22);    // 10% strategic brand red
  static const Color secondary = Color(0xFFFF9B9E);  // Blush pink
  static const Color accent = Color(0xFFFF4A00);     // Spark orange

  // Neutral Colors
  static const Color surface = Color(0xFFFDFAF6);
  static const Color border = Color(0xFFEFEAE2);
  static const Color dark = Color(0xFF221510);
  static const Color text = Color(0xFF2E2623);
  static const Color secondaryText = Color(0xFF6E6762);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color shadow = Color(0x082E2623);

  // Custom Status Backgrounds (extremely soft)
  static const Color lutealSoft = Color(0xFFFDF2F2);
  static const Color lutealText = Color(0xFF9B1C1C);

  // Semantic brand colors
  static const Color success = Color(0xFF8FAE8A);  // Soft Sage
  static const Color info = Color(0xFFDCCFC2);     // Warm Sand
  static const Color warning = Color(0xFFFF4A00);  // Accent Orange
  static const Color danger = Color(0xFFDD0D22);   // Brand Red
  static const Color disabled = Color(0xFFA8A29E);  // Muted neutral
  static const Color clay = Color(0xFFE8DCC4);     // Soft Clay
  static const Color taupe = Color(0xFFF3EDE9);    // Soft Taupe
  static const Color lutealAccent = Color(0xFFA56A52); // Warm Cocoa Accent
}

class BlushyTypography {
  static double _getResponsiveSize(double mobileSize, double desktopSize) {
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final width = MediaQueryData.fromView(view).size.width;
      if (width >= 768) {
        return desktopSize;
      }
      if (width <= 390) {
        return mobileSize;
      }
      final t = (width - 390) / (768 - 390);
      return mobileSize + (desktopSize - mobileSize) * t;
    } catch (_) {
      return mobileSize;
    }
  }

  static TextStyle displayXL({Color color = BlushyColors.dark}) => GoogleFonts.poppins(
    fontSize: _getResponsiveSize(26, 32),
    fontWeight: FontWeight.w300,
    height: 1.1,
    color: color,
  );

  static TextStyle displayL({Color color = BlushyColors.dark}) => GoogleFonts.poppins(
    fontSize: _getResponsiveSize(38, 44),
    fontWeight: FontWeight.w700,
    height: 1.0,
    color: color,
  );

  static TextStyle heading1({Color color = BlushyColors.dark}) => GoogleFonts.poppins(
    fontSize: _getResponsiveSize(22, 26),
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: color,
  );

  static TextStyle heading2({Color color = BlushyColors.dark}) => GoogleFonts.poppins(
    fontSize: _getResponsiveSize(20, 22),
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: color,
  );

  static TextStyle heading3({Color color = BlushyColors.dark}) => GoogleFonts.poppins(
    fontSize: _getResponsiveSize(17, 20),
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: color,
  );

  static TextStyle bodyLarge({Color color = BlushyColors.text}) => GoogleFonts.poppins(
    fontSize: _getResponsiveSize(16, 17),
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: color,
  );

  static TextStyle body({Color color = BlushyColors.text}) => GoogleFonts.poppins(
    fontSize: _getResponsiveSize(15, 16),
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: color,
  );

  static TextStyle bodySmall({Color color = BlushyColors.text}) => GoogleFonts.poppins(
    fontSize: _getResponsiveSize(13, 14),
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: color,
  );

  static TextStyle caption({Color color = BlushyColors.secondaryText}) => GoogleFonts.poppins(
    fontSize: _getResponsiveSize(11, 12),
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: color,
  );

  static TextStyle button({Color color = Colors.white}) => GoogleFonts.poppins(
    fontSize: _getResponsiveSize(14, 15),
    fontWeight: FontWeight.w600,
    color: color,
  );

  static TextStyle navLabel({Color color = BlushyColors.text}) => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: color,
  );

  static TextStyle chipLabel({Color color = BlushyColors.text}) => GoogleFonts.poppins(
    fontSize: _getResponsiveSize(12, 13),
    fontWeight: FontWeight.w600,
    color: color,
  );

  static TextStyle sectionLabel({Color color = BlushyColors.primary}) => GoogleFonts.poppins(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 11 * 0.18,
    color: color,
  );
}

class BlushyTheme {
  static double getPagePadding(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return width < 1200 ? 20.0 : 48.0;
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: BlushyColors.background,
      colorScheme: const ColorScheme.light(
        primary: BlushyColors.primary,
        secondary: BlushyColors.secondary,
        surface: BlushyColors.surface,
        error: BlushyColors.accent,
      ),
      fontFamily: 'Courier', // Fallback to Courier/Georgia for elegant editorial layout headings if platform sans isn't styled
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: BlushyColors.dark,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: BlushyColors.dark,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: BlushyColors.dark,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: BlushyColors.dark,
          height: 1.5,
          letterSpacing: 0.1,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: BlushyColors.secondaryText,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: BlushyColors.dark,
          letterSpacing: 0.8,
        ),
      ),
      cardTheme: CardThemeData(
        color: BlushyColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: BlushyColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
