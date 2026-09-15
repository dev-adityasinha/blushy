import 'package:flutter/material.dart';

class BlushyColors {
  static const Color background = Color(0xFFFAF6F0);
  static const Color primary = Color(0xFFDD0D22);
  static const Color secondary = Color(0xFFFF9B9E);
  static const Color accent = Color(0xFFFF4A00);
  static const Color dark = Color(0xFF221510);
  static const Color text = Color(0xFF191716);
  static const Color secondaryText = Color(0xFF77716D);
  static const Color cardBg = Color(0xFFFFFDFC);
  static const Color border = Color(0xFFEAE3DC);
  static const Color shadow = Color(0x082E2623);
  
  // Semantic brand colors
  static const Color success = Color(0xFF8FAE8A);  // Soft Sage
  static const Color successSoft = Color(0xFFEAF1E8); // Soft Sage, as a surface tint
  static const Color info = Color(0xFFDCCFC2);     // Warm Sand
  static const Color warning = Color(0xFFFF4A00);  // Accent Orange
  static const Color danger = Color(0xFFDD0D22);   // Brand Red
  static const Color disabled = Color(0xFFA8A29E);  // Muted neutral
  static const Color clay = Color(0xFFE8DCC4);     // Soft Clay
  static const Color taupe = Color(0xFFF3EDE9);    // Soft Taupe
  static const Color surface = Color(0xFFFFFDFC);  // Card / Surface
  static const Color lutealSoft = Color(0xFFFDE8E0); // Luteal Soft
  static const Color lutealAccent = Color(0xFFA56A52); // Warm Cocoa Accent for Luteal phase
  static const Color textDark = Color(0xFF191716);
  static const Color textMuted = Color(0xFF77716D);
  static const Color textLight = Color(0xFFFFFFFF);

  /// The luteal phase's colour on the cycle ring and its legend, and nowhere
  /// else. The design spec removes purple as a UI colour and allows it only
  /// as a phase indicator; this constant is that allowance, named so a use
  /// anywhere else is visible for what it is.
  static const Color lutealPhase = Color(0xFF7C5CE0);
}
