import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'note_stickers.dart';

/// One piece of writing, placed where it was put.
///
/// A note used to be a single field anchored to the top of the page, so
/// everything had to start on the first line and run down. Writing is placed
/// the way stickers are now: tap a spot and it begins there.
///
/// Position is a fraction of the writing area, like [NoteSticker], so a note
/// written on a phone opens with its words in the same places on a tablet.
class NoteTextBlock {
  const NoteTextBlock({
    required this.text,
    required this.dx,
    required this.dy,
    this.width = 0.9,
  });

  final String text;

  /// 0..1 across and down the writing area, at the block's top-left.
  final double dx;
  final double dy;

  /// How much of the width the block may use before it wraps.
  final double width;

  NoteTextBlock copyWith({
    String? text,
    double? dx,
    double? dy,
    double? width,
  }) =>
      NoteTextBlock(
        text: text ?? this.text,
        dx: dx ?? this.dx,
        dy: dy ?? this.dy,
        width: width ?? this.width,
      );

  Map<String, dynamic> toJson() =>
      {'text': text, 'dx': dx, 'dy': dy, 'width': width};

  static NoteTextBlock? fromJson(Map<String, dynamic> json) {
    final text = json['text'];
    if (text is! String) return null;
    return NoteTextBlock(
      text: text,
      // Clamped on the way in, for the reason a sticker's position is: a value
      // from a corrupted record would put the words off the page, where they
      // could not be read or dragged back.
      dx: _fraction(json['dx']),
      dy: _fraction(json['dy']),
      width: _width(json['width']),
    );
  }

  static double _fraction(Object? value) {
    final n = value is num ? value.toDouble() : 0.0;
    return n.isFinite ? n.clamp(0.0, 0.98) : 0.0;
  }

  static double _width(Object? value) {
    final n = value is num ? value.toDouble() : 0.9;
    // Never narrower than a few words, never wider than the page.
    return n.isFinite ? n.clamp(0.25, 1.0) : 0.9;
  }
}

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
    this.stickerId,
  });

  /// A drawn sticker, by its id.
  ///
  /// Kept beside [emoji] rather than replacing it: every note already saved
  /// carries an emoji and has to keep opening. A record with an id is drawn;
  /// one without falls back to the emoji, which is what the older notes are.
  NoteSticker.drawn(
    JournalSticker sticker, {
    required this.dx,
    required this.dy,
    this.scale = 1.0,
  })  : stickerId = sticker.id,
        emoji = '';

  final String emoji;

  /// Set when this is one of the drawn stickers. See [JournalSticker].
  final String? stickerId;

  /// The drawn sticker this record names, or null when it is an emoji.
  JournalSticker? get drawn => JournalSticker.byId(stickerId);

  /// 0..1 across and down the writing area.
  final double dx;
  final double dy;

  final double scale;

  NoteSticker copyWith({double? dx, double? dy, double? scale}) => NoteSticker(
        emoji: emoji,
        dx: dx ?? this.dx,
        dy: dy ?? this.dy,
        scale: scale ?? this.scale,
        stickerId: stickerId,
      );

  Map<String, dynamic> toJson() => {
        'emoji': emoji,
        'dx': dx,
        'dy': dy,
        'scale': scale,
        // Written only when there is one, so an emoji sticker's record is
        // unchanged from what older builds wrote.
        if (stickerId != null) 'stickerId': stickerId,
      };

  static NoteSticker? fromJson(Map<String, dynamic> json) {
    final emoji = json['emoji']?.toString() ?? '';
    final id = json['stickerId']?.toString();
    // One or the other has to be there, or there is nothing to draw.
    if (emoji.isEmpty && (id == null || id.isEmpty)) return null;
    return NoteSticker(
      emoji: emoji,
      stickerId: id,
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
    this.blocks = const [],
    this.photo,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.ink,
  });

  final NoteTemplate template;
  final String fontId;
  final double fontSize;

  /// ARGB. Stored as an int so it survives JSON without a colour codec.
  final int background;

  final List<NoteSticker> stickers;

  /// The writing, in the places it was put.
  ///
  /// Empty for every note saved before writing could be placed. Those carry
  /// their words in the entry's `body` instead, and the editor seeds a single
  /// block from it when one is opened -- see `NoteEditorScreen`.
  final List<NoteTextBlock> blocks;

  /// Her chosen background, base64-encoded, for [NoteTemplate.photo].
  ///
  /// Carried in the entry rather than as a file path: a path breaks when the
  /// photo is moved or the gallery entry deleted, and does not exist on web at
  /// all. See [NotePhoto] for why it is shrunk before it gets here.
  final String? photo;

  /// Emphasis, applied to the whole note.
  ///
  /// The writing is one plain text field, so these are the note's voice rather
  /// than a run inside it. Per-word emphasis would need the body stored as a
  /// document instead of a string, and every entry already saved is a string.
  final bool bold;
  final bool italic;
  final bool underline;

  /// The colour of the writing, ARGB, when one has been chosen.
  ///
  /// Null means "whatever stays legible on this paper", which is what every
  /// note did before there was a choice -- see [NoteBackgrounds.inkFor].
  final int? ink;

  /// The writing colour for this style on [paperColour].
  Color inkOn(int paperColour) =>
      ink != null ? Color(ink!) : NoteBackgrounds.inkFor(paperColour);

  static const NoteStyle fallback = NoteStyle();

  NoteStyle copyWith({
    NoteTemplate? template,
    String? fontId,
    double? fontSize,
    int? background,
    List<NoteSticker>? stickers,
    List<NoteTextBlock>? blocks,
    String? photo,
    bool? bold,
    bool? italic,
    bool? underline,
    int? ink,
  }) =>
      NoteStyle(
        template: template ?? this.template,
        fontId: fontId ?? this.fontId,
        fontSize: fontSize ?? this.fontSize,
        background: background ?? this.background,
        stickers: stickers ?? this.stickers,
        blocks: blocks ?? this.blocks,
        photo: photo ?? this.photo,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        ink: ink ?? this.ink,
      );

  /// The same style with the writing colour handed back to the paper.
  ///
  /// `copyWith` cannot express it, for the reason [withoutPhoto] exists:
  /// passing null there means "leave it alone".
  NoteStyle withPaperInk() => NoteStyle(
        template: template,
        fontId: fontId,
        fontSize: fontSize,
        background: background,
        stickers: stickers,
        blocks: blocks,
        photo: photo,
        bold: bold,
        italic: italic,
        underline: underline,
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
        blocks: blocks,
        bold: bold,
        italic: italic,
        underline: underline,
        ink: ink,
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
      fontWeight: bold ? FontWeight.w700 : null,
      fontStyle: italic ? FontStyle.italic : null,
      decoration: underline ? TextDecoration.underline : null,
      // Without this the underline sits on the text's own colour only by
      // luck; on the dark papers it drew in the default black.
      decorationColor: color,
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
        // Omitted when the writing has never been placed, so a note saved by
        // an older build round-trips byte-identically.
        if (blocks.isNotEmpty)
          'blocks': [for (final b in blocks) b.toJson()],
        // Omitted when there is none, so every entry without a photo does not
        // carry a null for one.
        if (photo != null) 'photo': photo,
        // Same reasoning: an unemphasised note's record is byte-identical to
        // what older builds wrote.
        if (bold) 'bold': true,
        if (italic) 'italic': true,
        if (underline) 'underline': true,
        if (ink != null) 'ink': ink,
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
      blocks: [
        for (final item in (json['blocks'] as List? ?? const []))
          if (item is Map<String, dynamic>)
            ?NoteTextBlock.fromJson(item),
      ],
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      underline: json['underline'] == true,
      ink: json['ink'] is int ? json['ink'] as int : null,
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
      ground: 0xFFF5E3C0, accent: 0xFF8E6FA8, inset: 0.07, insetLeft: 0.30),

  // --- written-on papers --------------------------------------------------
  //
  // These carry a `ground`, so they are decorated pages and get their own
  // painting, but they deliberately lay no panel over it: the ruling *is* the
  // page, and a sheet on top would hide it. The insets are small for the same
  // reason -- the writing runs across the page the way it does on real paper,
  // with a wider left margin only where something is drawn down that side.

  /// School exercise paper: wavy mint rules and a pink margin rule.
  notebookMint('notebook-mint', 'Mint notebook',
      ground: 0xFFFFFFFF, accent: 0xFF9CCFC4, inset: 0.03, insetLeft: 0.17),

  /// The same hand, warmer: blue rules on cream.
  notebookBlue('notebook-blue', 'Blue notebook',
      ground: 0xFFFDF6E3, accent: 0xFF6B8FD4, inset: 0.04),

  /// Fine squared paper in oat.
  gridOat('grid-oat', 'Oat grid',
      ground: 0xFFF4EDE4, accent: 0xFFC3B5A6, inset: 0.04),

  /// The same squares, in red on cream.
  gridRed('grid-red', 'Red grid',
      ground: 0xFFFFFBF2, accent: 0xFFE0705E, inset: 0.04),

  // --- drawn-on pages -----------------------------------------------------

  /// Crayon squiggles looping across squared paper.
  squiggleGrid('squiggle-grid', 'Red squiggle',
      ground: 0xFFF6F0E8, accent: 0xFFB4222C, inset: 0.11),

  /// Squared paper with a blue ribbon wandering down it, and small hearts.
  heartsGrid('hearts-grid', 'Blue hearts',
      ground: 0xFFFFFFFF, accent: 0xFF9CC9E8, inset: 0.11),

  /// A gold wave drawn as a frame, pinned with hearts.
  wavyGold('wavy-gold', 'Gold wave',
      ground: 0xFFF7F2E9, accent: 0xFFF2B430, inset: 0.12),

  /// A rainbow washed in behind the ruling.
  rainbowPage('rainbow', 'Rainbow',
      ground: 0xFFF7FAFD, accent: 0xFFAFC6E0, inset: 0.05),

  /// Watercolour blossoms, soft enough to write straight over.
  blossomPage('blossom', 'Blossom',
      ground: 0xFFFFFDFD, accent: 0xFFF4A7B9, inset: 0.05),

  /// A sun in one corner and tulips in the other.
  sunTulips('sun-tulips', 'Sun and tulips',
      ground: 0xFFFDF8EC, accent: 0xFF7BAEC0, inset: 0.05);

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

  /// The typefaces on offer, all from Google Fonts and all free to ship.
  ///
  /// The ids are what get written into a saved note, so they never change --
  /// several of the older ones name a family the app no longer uses, and
  /// renaming them would restyle every note already written.
  static final List<NoteFont> all = [
    NoteFont('poppins', 'Poppins', (b) => GoogleFonts.manrope(textStyle: b)),
    NoteFont('lora', 'Serif', (b) => GoogleFonts.instrumentSerif(textStyle: b)),
    NoteFont('caveat', 'Handwritten', (b) => GoogleFonts.caveat(textStyle: b)),
    NoteFont('architects', 'Notes',
        (b) => GoogleFonts.architectsDaughter(textStyle: b)),
    NoteFont('mono', 'Typewriter', (b) => GoogleFonts.robotoMono(textStyle: b)),
    NoteFont('inter', 'Plain', (b) => GoogleFonts.inter(textStyle: b)),

    // Hands.
    NoteFont('patrick', 'Print', (b) => GoogleFonts.patrickHand(textStyle: b)),
    NoteFont('indie', 'Felt tip', (b) => GoogleFonts.indieFlower(textStyle: b)),
    NoteFont('shadows', 'Pencil',
        (b) => GoogleFonts.shadowsIntoLight(textStyle: b)),
    NoteFont('gloria', 'Marker',
        (b) => GoogleFonts.gloriaHallelujah(textStyle: b)),
    NoteFont('dancing', 'Script',
        (b) => GoogleFonts.dancingScript(textStyle: b)),
    // Kalam carries Devanagari as well as Latin, so a Hindi entry written in
    // it does not fall back to the system face mid-note.
    NoteFont('kalam', 'Brush', (b) => GoogleFonts.kalam(textStyle: b)),

    // Set type.
    NoteFont('playfair', 'Editorial',
        (b) => GoogleFonts.playfairDisplay(textStyle: b)),
    NoteFont('garamond', 'Book', (b) => GoogleFonts.ebGaramond(textStyle: b)),
    NoteFont('baskerville', 'Letterpress',
        (b) => GoogleFonts.libreBaskerville(textStyle: b)),
    NoteFont('quicksand', 'Rounded',
        (b) => GoogleFonts.quicksand(textStyle: b)),
    NoteFont('nunito', 'Soft', (b) => GoogleFonts.nunito(textStyle: b)),
    NoteFont('courier', 'Courier',
        (b) => GoogleFonts.courierPrime(textStyle: b)),
  ];

  static bool has(String? id) => all.any((f) => f.id == id);

  static NoteFont byId(String id) =>
      all.firstWhere((f) => f.id == id, orElse: () => all.first);
}

/// The writing colours on offer.
///
/// Darker and more saturated than the papers, because they have to hold their
/// own as small text rather than as a field of colour behind it.
class NoteInks {
  const NoteInks._();

  static const List<int> all = [
    0xFF2E2623, // near black
    0xFF4A5B74, // slate
    0xFF1F5F4B, // pine
    0xFF8A4B12, // umber
    0xFFB23A48, // rose
    0xFF7A3E9D, // plum
    0xFF1C4E8A, // ink blue
    0xFFC2410C, // clay
  ];
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
