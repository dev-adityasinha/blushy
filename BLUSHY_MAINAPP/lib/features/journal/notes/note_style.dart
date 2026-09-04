import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// One sticker placed on a note.
///
/// Position is a fraction of the page rather than pixels, so a note written on
/// a phone opens with its stickers in the same places on a tablet.
class NoteSticker {
  const NoteSticker({
    required this.emoji,
    required this.dx,
    required this.dy,
    this.scale = 1.0,
  });

  final String emoji;

  /// 0..1 across and down the writing area.
  final double dx;
  final double dy;

  final double scale;

  NoteSticker copyWith({double? dx, double? dy, double? scale}) => NoteSticker(
        emoji: emoji,
        dx: dx ?? this.dx,
        dy: dy ?? this.dy,
        scale: scale ?? this.scale,
      );

  Map<String, dynamic> toJson() =>
      {'emoji': emoji, 'dx': dx, 'dy': dy, 'scale': scale};

  static NoteSticker? fromJson(Map<String, dynamic> json) {
    final emoji = json['emoji']?.toString();
    if (emoji == null || emoji.isEmpty) return null;
    return NoteSticker(
      emoji: emoji,
      // Clamped on the way in: a value from a corrupted or hand-edited record
      // would otherwise place a sticker outside the page, where it cannot be
      // seen or dragged back.
      dx: _fraction(json['dx']),
      dy: _fraction(json['dy']),
      scale: _clampScale(json['scale']),
    );
  }

  static double _fraction(Object? value) {
    final n = value is num ? value.toDouble() : 0.5;
    return n.isFinite ? n.clamp(0.0, 1.0) : 0.5;
  }

  static double _clampScale(Object? value) {
    final n = value is num ? value.toDouble() : 1.0;
    return n.isFinite ? n.clamp(0.5, 3.0) : 1.0;
  }
}

/// How a note looks: paper, typeface, colour and whatever was stuck on it.
///
/// Stored as JSON in the entry's `rawJson`, so a note reopens looking the way
/// it was written. Every field falls back to the default rather than throwing:
/// an entry saved by an older build has no style at all, and it has to open.
class NoteStyle {
  const NoteStyle({
    this.template = NoteTemplate.plain,
    this.fontId = 'poppins',
    this.fontSize = 16,
    this.background = 0xFFFFFBF5,
    this.stickers = const [],
    this.photo,
  });

  final NoteTemplate template;
  final String fontId;
  final double fontSize;

  /// ARGB. Stored as an int so it survives JSON without a colour codec.
  final int background;

  final List<NoteSticker> stickers;

  /// Her chosen background, base64-encoded, for [NoteTemplate.photo].
  ///
  /// Carried in the entry rather than as a file path: a path breaks when the
  /// photo is moved or the gallery entry deleted, and does not exist on web at
  /// all. See [NotePhoto] for why it is shrunk before it gets here.
  final String? photo;

  static const NoteStyle fallback = NoteStyle();

  NoteStyle copyWith({
    NoteTemplate? template,
    String? fontId,
    double? fontSize,
    int? background,
    List<NoteSticker>? stickers,
    String? photo,
  }) =>
      NoteStyle(
        template: template ?? this.template,
        fontId: fontId ?? this.fontId,
        fontSize: fontSize ?? this.fontSize,
        background: background ?? this.background,
        stickers: stickers ?? this.stickers,
        photo: photo ?? this.photo,
      );

  /// The same style with no background photograph.
  ///
  /// `copyWith` cannot express this: passing null there means "leave it as it
  /// is", so without this the photo could be changed but never taken off.
  NoteStyle withoutPhoto() => NoteStyle(
        template: template,
        fontId: fontId,
        fontSize: fontSize,
        background: background,
        stickers: stickers,
      );

  Color get backgroundColor => Color(background);

  /// The text style, with a fallback that cannot throw.
  ///
  /// `GoogleFonts` fetches a family the first time it is used, so an unknown
  /// id or a device that cannot reach the font host must not take the note
  /// down with it -- the writing matters more than the typeface.
  TextStyle textStyle({Color? color}) {
    final base = TextStyle(
      fontSize: fontSize,
      height: 1.55,
      color: color ?? const Color(0xFF2E2623),
    );
    try {
      return NoteFonts.byId(fontId).builder(base);
    } catch (_) {
      return GoogleFonts.manrope(textStyle: base);
    }
  }

  Map<String, dynamic> toJson() => {
        'template': template.id,
        'fontId': fontId,
        'fontSize': fontSize,
        'background': background,
        'stickers': [for (final s in stickers) s.toJson()],
        // Omitted when there is none, so every entry without a photo does not
        // carry a null for one.
        if (photo != null) 'photo': photo,
      };

  String encode() => jsonEncode(toJson());

  /// Reads a style back, whatever state the stored value is in.
  ///
  /// Returns [fallback] for null, for text that is not JSON, and for JSON that
  /// is not a style — all three exist in storage already, because `rawJson`
  /// was used for scrapbook items long before it held one of these.
  static NoteStyle decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return fallback;
      return fromJson(decoded);
    } catch (_) {
      return fallback;
    }
  }

  static NoteStyle fromJson(Map<String, dynamic> json) {
    final size = json['fontSize'];
    final background = json['background'];
    return NoteStyle(
      template: NoteTemplate.byId(json['template']?.toString()),
      fontId: NoteFonts.has(json['fontId']?.toString())
          ? json['fontId'].toString()
          : fallback.fontId,
      fontSize: size is num && size.isFinite
          ? size.toDouble().clamp(12.0, 30.0)
          : fallback.fontSize,
      background: background is int ? background : fallback.background,
      photo: json['photo'] is String && (json['photo'] as String).isNotEmpty
          ? json['photo'] as String
          : null,
      stickers: [
        for (final item in (json['stickers'] as List? ?? const []))
          if (item is Map<String, dynamic>)
            ?NoteSticker.fromJson(item),
      ],
    );
  }
}

/// The paper a note is written on.
///
/// Two kinds. The first four are ruling -- lines or dots on whatever colour
/// was picked. The rest are decorated pages: a printed ground with a panel of
/// paper laid on it, which is what gets written on.
///
/// The decorated ones are drawn rather than shipped as images. The references
/// they follow are other people's artwork, and a drawn page also scales to any
/// screen, takes the ink colour with it and adds nothing to the bundle.
enum NoteTemplate {
  plain('plain', 'Plain'),
  lined('lined', 'Lined'),
  dotted('dotted', 'Dotted'),
  grid('grid', 'Grid'),

  /// A wavy border on a striped ground.
  wavyFrame('wavy', 'Wavy frame',
      ground: 0xFFF4573B, accent: 0xFFF9A8B8, inset: 0.09),

  /// Checked cloth with a torn sheet on it.
  gingham('gingham', 'Gingham',
      ground: 0xFFF7E9A8, accent: 0xFFFFFFFF, inset: 0.08),

  /// A deckle-edged sheet on a soft ground.
  tornPaper('torn', 'Torn paper',
      ground: 0xFFCFD9C4, accent: 0xFFFFFFFF, inset: 0.08),

  /// The same sheet, with pressed flowers at two corners.
  pressedFlowers('pressed', 'Pressed flowers',
      ground: 0xFFF6E7C8, accent: 0xFFD98BA5, inset: 0.10),

  /// Graph paper with a ribbon trailing across it.
  ribbon('ribbon', 'Ribbon',
      ground: 0xFFFBF7F2, accent: 0xFFD22B3A, inset: 0.08),

  /// Her own photograph behind a torn sheet.
  ///
  /// The ground here is only the fallback: it is what shows before a photo is
  /// chosen, and if the stored one ever fails to decode. The template is still
  /// usable in that state rather than rendering as a blank page.
  photo('photo', 'Photo', ground: 0xFF4A4A4A, accent: 0xFFFFFFFF, inset: 0.10),

  /// A pressed botanical drawn up one side.
  ///
  /// The wider left inset is the point: the stems grow in that margin, and at
  /// an even inset the panel covered them and left a plain sheet.
  botanical('botanical', 'Botanical',
      ground: 0xFFF5E3C0, accent: 0xFF8E6FA8, inset: 0.07, insetLeft: 0.30);

  const NoteTemplate(
    this.id,
    this.label, {
    this.ground,
    this.accent,
    this.inset = 0,
    this.insetLeft,
  });

  final String id;
  final String label;

  /// The printed ground behind the writing panel. Null for the ruled papers,
  /// which sit straight on the colour she picked.
  final int? ground;

  /// The second colour the decoration is drawn in.
  final int? accent;

  /// How far the writing panel sits in from the edge, as a fraction of the
  /// shorter side. Zero means write to the margins.
  final double inset;

  /// A wider left margin, where a template draws something down that side.
  final double? insetLeft;

  bool get isDecorated => ground != null;

  static NoteTemplate byId(String? id) => values.firstWhere(
        (t) => t.id == id,
        orElse: () => NoteTemplate.plain,
      );
}

/// One typeface a note can be written in.
class NoteFont {
  const NoteFont(this.id, this.label, this.builder);

  final String id;
  final String label;

  /// Applied to a base style, so size and colour stay with the note.
  final TextStyle Function(TextStyle base) builder;
}

/// The typefaces on offer.
///
/// Deliberately a short list of families already used elsewhere in the app:
/// each one is another download on first use, and a picker of forty would be
/// slower to open than it is useful.
class NoteFonts {
  const NoteFonts._();

  static final List<NoteFont> all = [
    NoteFont('poppins', 'Poppins', (b) => GoogleFonts.manrope(textStyle: b)),
    NoteFont('lora', 'Serif', (b) => GoogleFonts.instrumentSerif(textStyle: b)),
    NoteFont('caveat', 'Handwritten', (b) => GoogleFonts.caveat(textStyle: b)),
    NoteFont('architects', 'Notes',
        (b) => GoogleFonts.architectsDaughter(textStyle: b)),
    NoteFont('mono', 'Typewriter', (b) => GoogleFonts.robotoMono(textStyle: b)),
    NoteFont('inter', 'Plain', (b) => GoogleFonts.inter(textStyle: b)),
  ];

  static bool has(String? id) => all.any((f) => f.id == id);

  static NoteFont byId(String id) =>
      all.firstWhere((f) => f.id == id, orElse: () => all.first);
}

/// The paper colours on offer.
class NoteBackgrounds {
  const NoteBackgrounds._();

  static const List<int> all = [
    0xFFFFFBF5, // warm white
    0xFFFFFFFF, // white
    0xFFFDF2F4, // blush
    0xFFF3F8F4, // sage
    0xFFF1F5FB, // sky
    0xFFFBF4E8, // sand
    0xFFF6F2FA, // lilac
    0xFF2E2A28, // dark
  ];

  /// Ink that stays legible on [background].
  ///
  /// Without this the dark paper renders near-black text on near-black paper,
  /// which is a note you cannot read back.
  static Color inkFor(int background) {
    final colour = Color(background);
    return colour.computeLuminance() < 0.4
        ? const Color(0xFFF6F1EC)
        : const Color(0xFF2E2623);
  }
}
