import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class BlushyTypography {
  static TextStyle headlineLarge(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: BlushyColors.text,
      height: 1.15,
    );
  }

  static TextStyle headlineMedium(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: BlushyColors.text,
      height: 1.25,
    );
  }

  static TextStyle titleMedium(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: BlushyColors.text,
      letterSpacing: -0.2,
    );
  }

  static TextStyle bodyLarge(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: BlushyColors.text,
      height: 1.5,
    );
  }

  static TextStyle bodyMedium(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: BlushyColors.secondaryText,
      height: 1.5,
    );
  }

  static TextStyle labelLarge(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: BlushyColors.text,
      letterSpacing: 0.8,
    );
  }
}
