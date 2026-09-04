import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/journal_storage.dart';
import '../../../theme/colors.dart';
import 'note_page_background.dart';
import 'note_paper.dart';
import 'note_photo.dart';
import 'note_style.dart';

/// Writing one journal entry.
///
/// A page to write on, and four things to change about it: the paper, the
/// typeface, the colour and whatever gets stuck to it. All four are saved with
/// the entry, so it opens again looking the way it was left.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.entry});

  /// The entry being edited, or null to start a new one.
  final LocalJournalEntry? entry;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _title =
      TextEditingController(text: widget.entry?.title ?? '');
  late final TextEditingController _body =
      TextEditingController(text: widget.entry?.body ?? '');

  late NoteStyle _style = NoteStyle.decode(widget.entry?.rawJson);

  /// Which customisation tray is open, if any.
  String? _tray;

  /// True while the picker is open, so the button cannot be tapped twice.
  bool _pickingPhoto = false;

  Future<void> _choosePhoto() async {
    setState(() => _pickingPhoto = true);
    final encoded = await NotePhoto.pick();
    if (!mounted) return;
    setState(() {
      _pickingPhoto = false;
      if (encoded != null) _style = _style.copyWith(photo: encoded);
    });

    if (encoded == null && mounted) {
      // Covers cancelling and failing alike. The distinction is not worth an
      // error dialog for a background, and the picker gives no reliable way to
      // tell them apart.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No photo added.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// The writing area, so a sticker tap lands in fractions of the right box.
  final GlobalKey _pageKey = GlobalKey();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  /// The ink, taken from whatever is actually behind the words.
  ///
  /// On a decorated page that is the panel, not the printed ground: the
  /// ground can be a deep red, and reading the ink off it would put white
  /// text on a cream sheet.
  Color get _ink => NoteBackgrounds.inkFor(_style.background);

  /// What the screen behind the page shows.
  Color get _pageGround => _style.template.isDecorated
      ? Color(_style.template.ground!)
      : _style.backgroundColor;

  /// Contrast for the bar, which sits on the ground rather than the panel.
  Color get _chrome => NoteBackgrounds.inkFor(
      _style.template.isDecorated ? _style.template.ground! : _style.background);

  void _addSticker(String emoji) {
    setState(() {
      // Dropped a little above centre, then dragged. Stacking each new one
      // slightly lower means adding several does not hide them all under one.
      final n = _style.stickers.length;
      _style = _style.copyWith(stickers: [
        ..._style.stickers,
        NoteSticker(emoji: emoji, dx: 0.5, dy: (0.28 + n * 0.06).clamp(0.0, 0.9)),
      ]);
    });
  }

  void _moveSticker(int index, Offset delta, Size pageSize) {
    if (pageSize.width <= 0 || pageSize.height <= 0) return;
    setState(() {
      final stickers = [..._style.stickers];
      final current = stickers[index];
      stickers[index] = current.copyWith(
        dx: (current.dx + delta.dx / pageSize.width).clamp(0.0, 1.0),
        dy: (current.dy + delta.dy / pageSize.height).clamp(0.0, 1.0),
      );
      _style = _style.copyWith(stickers: stickers);
    });
  }

  void _removeSticker(int index) {
    setState(() {
      final stickers = [..._style.stickers]..removeAt(index);
      _style = _style.copyWith(stickers: stickers);
    });
  }

  bool get _isEmpty =>
      _title.text.trim().isEmpty && _body.text.trim().isEmpty;

  /// Hands the finished entry back to the list, which owns saving.
  void _save() {
    if (_isEmpty) {
      // Nothing written. Closing is the right outcome rather than storing a
      // blank entry that then has to be found and deleted.
      Navigator.of(context).pop();
      return;
    }

    final now = DateTime.now();
    final existing = widget.entry;
    Navigator.of(context).pop(LocalJournalEntry(
      id: existing?.id ?? 'note_${now.microsecondsSinceEpoch}',
      date: existing?.date ??
          '${now.year}-${now.month.toString().padLeft(2, '0')}-'
              '${now.day.toString().padLeft(2, '0')}',
      title: _title.text.trim().isEmpty ? 'Untitled' : _title.text.trim(),
      body: _body.text,
      moodKey: existing?.moodKey ?? '',
      dateTime: existing?.dateTime ?? now.toIso8601String(),
      // The look travels with the writing.
      rawJson: _style.encode(),
      aiMetadata: existing?.aiMetadata,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageGround,
      appBar: AppBar(
        backgroundColor: _pageGround,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _chrome),
        title: Text(
          widget.entry == null ? 'New entry' : 'Entry',
          style: GoogleFonts.manrope(height: 1.5, 
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _chrome,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: GoogleFonts.manrope(height: 1.5, 
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BlushyColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _page()),
            if (_tray != null) _trayFor(_tray!),
            _toolbar(),
          ],
        ),
      ),
    );
  }

  /// The page: ruling behind, writing on top, stickers above that.
  Widget _page() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          key: _pageKey,
          children: [
            Positioned.fill(
              child: NotePageBackground(style: _style, ink: _ink),
            ),
            // Inside the panel on a decorated page, or the whole page on a
            // ruled one. Taken from the painter's own measurement so the words
            // cannot end up written across the border.
            Positioned.fromRect(
              rect: NotePaper.panelRect(_style.template, size)
                  .deflate(_style.template.isDecorated ? 18 : 0),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  _style.template.isDecorated ? 4 : 20,
                  12,
                  _style.template.isDecorated ? 4 : 20,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _title,
                      style: _style
                          .textStyle(color: _ink)
                          .copyWith(
                            fontSize: _style.fontSize + 6,
                            fontWeight: FontWeight.w700,
                          ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Title',
                        hintStyle: _style
                            .textStyle(color: _ink.withValues(alpha: 0.35))
                            .copyWith(fontSize: _style.fontSize + 6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _body,
                      maxLines: null,
                      minLines: 12,
                      keyboardType: TextInputType.multiline,
                      style: _style.textStyle(color: _ink),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Write whatever you like.',
                        hintStyle: _style.textStyle(
                            color: _ink.withValues(alpha: 0.35)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (int i = 0; i < _style.stickers.length; i++)
              _stickerAt(i, size),
          ],
        );
      },
    );
  }

  Widget _stickerAt(int index, Size size) {
    final sticker = _style.stickers[index];
    return Positioned(
      left: sticker.dx * size.width - 22,
      top: sticker.dy * size.height - 22,
      child: GestureDetector(
        onPanUpdate: (d) => _moveSticker(index, d.delta, size),
        // Long press rather than tap: a tap on a note is for putting the
        // cursor somewhere, and a sticker that vanished on a stray tap would
        // be infuriating.
        onLongPress: () => _removeSticker(index),
        child: Text(
          sticker.emoji,
          style: TextStyle(fontSize: 34 * sticker.scale),
        ),
      ),
    );
  }

  // --- the four trays -------------------------------------------------------

  Widget _trayFor(String tray) {
    switch (tray) {
      case 'template':
        return _tray_(
          'Paper',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in NoteTemplate.values)
                    _pill(
                      label: t.label,
                      selected: _style.template == t,
                      onTap: () => setState(
                          () => _style = _style.copyWith(template: t)),
                    ),
                ],
              ),
              if (_style.template == NoteTemplate.photo) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    _pill(
                      label: _pickingPhoto
                          ? 'Choosing...'
                          : _style.photo == null
                              ? 'Choose photo'
                              : 'Change photo',
                      selected: false,
                      onTap: _pickingPhoto ? () {} : _choosePhoto,
                    ),
                    if (_style.photo != null) ...[
                      const SizedBox(width: 8),
                      _pill(
                        label: 'Remove',
                        selected: false,
                        onTap: () =>
                            setState(() => _style = _style.withoutPhoto()),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );

      case 'font':
        return _tray_(
          'Font',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in NoteFonts.all)
                    _pill(
                      label: f.label,
                      selected: _style.fontId == f.id,
                      // Each pill shown in its own face, so the choice is
                      // visible before it is made.
                      textStyle: f.builder(const TextStyle(fontSize: 13)),
                      onTap: () => setState(
                          () => _style = _style.copyWith(fontId: f.id)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('Size',
                      style: GoogleFonts.manrope(height: 1.5, 
                          fontSize: 11, color: BlushyColors.secondaryText)),
                  Expanded(
                    child: Slider(
                      value: _style.fontSize,
                      min: 12,
                      max: 30,
                      divisions: 18,
                      activeColor: BlushyColors.primary,
                      label: _style.fontSize.round().toString(),
                      onChanged: (v) => setState(
                          () => _style = _style.copyWith(fontSize: v)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case 'colour':
        return _tray_(
          'Paper colour',
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final colour in NoteBackgrounds.all)
                GestureDetector(
                  onTap: () => setState(
                      () => _style = _style.copyWith(background: colour)),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(colour),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _style.background == colour
                            ? BlushyColors.primary
                            : BlushyColors.border,
                        width: _style.background == colour ? 2.4 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

      case 'stickers':
        return _tray_(
          'Stickers  ·  tap to add, drag to move, hold to remove',
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final emoji in _stickerPalette)
                GestureDetector(
                  onTap: () => _addSticker(emoji),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BlushyColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: BlushyColors.border),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
            ],
          ),
        );
    }
    return const SizedBox.shrink();
  }

  static const List<String> _stickerPalette = [
    '🌸', '💗', '🌙', '⭐', '☁️', '🌿', '🦋', '🍓',
    '☕', '📖', '🕯️', '🧸', '🎧', '✨', '🌊', '🔥',
  ];

  Widget _tray_(String heading, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: BlushyColors.background,
        border: Border(top: BorderSide(color: BlushyColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading.toUpperCase(),
            style: GoogleFonts.manrope(height: 1.5, 
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.7,
              color: BlushyColors.secondaryText,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    TextStyle? textStyle,
  }) {
    return Material(
      color: selected
          ? BlushyColors.primary.withValues(alpha: 0.10)
          : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? BlushyColors.primary : BlushyColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: (textStyle ?? GoogleFonts.manrope(height: 1.5, fontSize: 13)).copyWith(
              color: BlushyColors.text,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    return Container(
      decoration: const BoxDecoration(
        color: BlushyColors.background,
        border: Border(top: BorderSide(color: BlushyColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _tool('template', Icons.article_rounded, 'Paper'),
            _tool('font', Icons.text_fields_rounded, 'Font'),
            _tool('colour', Icons.palette_rounded, 'Colour'),
            _tool('stickers', Icons.emoji_emotions_rounded, 'Stickers'),
          ],
        ),
      ),
    );
  }

  Widget _tool(String id, IconData icon, String label) {
    final open = _tray == id;
    return Expanded(
      child: InkWell(
        // Tapping the open one closes it, so the page can be seen without
        // choosing something first.
        onTap: () => setState(() => _tray = open ? null : id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 20,
                  color: open ? BlushyColors.primary : BlushyColors.text),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.manrope(height: 1.5, 
                  fontSize: 10,
                  fontWeight: open ? FontWeight.w600 : FontWeight.w500,
                  color:
                      open ? BlushyColors.primary : BlushyColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
