import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// The type scale.
///
/// Seven sizes, and every piece of text on the redesigned screens is one of
/// them. Before this each widget chose its own -- 9, 9.5, 10, 10.5, 11, 11.5,
/// 12, 12.5, 13, 13.5 all appeared as "small text" -- so nothing lined up and
/// the same kind of thing was a different size on every card.
///
/// Two faces, per the home design spec: Instrument Serif for the editorial
/// sizes -- the greeting, a section's headline, a card's title -- set
/// regular, because the serif carries the weight itself; Manrope for
/// everything read as interface.
abstract final class BlushyType {
  /// The editorial headline: the greeting.
  static TextStyle display({Color color = BlushyColors.text}) =>
      GoogleFonts.instrumentSerif(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        height: 1.1,
        color: color,
      );

  /// A major section's title, in the display face.
  static TextStyle headline({Color color = BlushyColors.text}) =>
      GoogleFonts.instrumentSerif(
        fontSize: 22,
        fontWeight: FontWeight.w400,
        height: 1.15,
        color: color,
      );

  /// A card's title, in the display face.
  static TextStyle title({Color color = BlushyColors.text}) =>
      GoogleFonts.instrumentSerif(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.2,
        color: color,
      );

  /// A row label, a name, a button.
  static TextStyle heading({
    Color color = BlushyColors.text,
    FontWeight weight = FontWeight.w600,
  }) =>
      GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: weight,
        height: 1.4,
        color: color,
      );

  /// Running text.
  static TextStyle body({
    Color color = BlushyColors.secondaryText,
    FontWeight weight = FontWeight.w400,
  }) =>
      GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: weight,
        height: 1.55,
        color: color,
      );

  /// Taglines, timestamps, day ranges, the small line under a title.
  static TextStyle caption({
    Color color = BlushyColors.secondaryText,
    FontWeight weight = FontWeight.w400,
  }) =>
      GoogleFonts.manrope(
        fontSize: 11.5,
        fontWeight: weight,
        height: 1.45,
        color: color,
      );

  /// A section eyebrow: uppercase, spaced.
  ///
  /// Spaced less than the classic eyebrow. At this size, two points of
  /// tracking made the longer headings run off the line.
  static TextStyle eyebrow({Color color = BlushyColors.primary}) =>
      GoogleFonts.manrope(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.8,
        height: 1.2,
        color: color,
      );

  /// The smallest thing set in type: a chip, a nav label.
  static TextStyle micro({
    Color color = BlushyColors.secondaryText,
    FontWeight weight = FontWeight.w600,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: 1.2,
        color: color,
      );
}

/// The spacing scale.
///
/// Multiples of four, and only these. A gap that is not on the list is a gap
/// someone eyeballed, and eyeballed gaps are why two cards on the same screen
/// sat 14 and 18 apart.
abstract final class BlushySpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// The edge of every page. The spec asks 20-24 on phones.
  static const double page = 20;

  /// Inside every card. 20, the spec's spacing.card.
  static const EdgeInsets card = EdgeInsets.all(20);

  /// Between cards in a list.
  static const double betweenCards = lg;

  /// Between one section and the next.
  static const double betweenSections = xl;

  /// A round control in the header or on a card: the bell, the account, the
  /// edit button.
  static const double control = 36;

  /// A square tile holding an icon on a row.
  static const double tile = 38;

  /// A tap target's minimum height: buttons, pills, fields.
  static const double tapHeight = 40;

  /// Icon sizes, so they are chosen once. A row's leading icon, an inline
  /// icon beside text, and a trailing chevron.
  static const double iconTile = 18;
  static const double iconInline = 14;
  static const double iconChevron = 18;
}
