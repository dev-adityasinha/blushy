import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/journal_storage.dart';
import '../../../theme/colors.dart';
import 'note_page_background.dart';
import 'note_stickers.dart';
import 'note_paper.dart';
import 'note_photo.dart';
import 'note_style.dart';
import '../../../l10n/app_localizations.dart';

/// Writing one journal entry.
///
/// A page to write on, and four things to change about it: the paper, the
/// typeface, the colour and whatever gets stuck to it. All four are saved with
/// the entry, so it opens again looking the way it was left.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.entry,
    this.initialTemplate,
    this.initialText,
  });

  /// The entry being edited, or null to start a new one.
  final LocalJournalEntry? entry;

  /// The paper a new entry starts on, chosen before the editor opened.
  ///
  /// Ignored when [entry] is set: an entry already carries the paper it was
  /// written on, and reopening it on a different one would silently restyle
  /// what is already there.
  final NoteTemplate? initialTemplate;

  /// Words the page opens with -- what was said out loud, transcribed.
  ///
  /// A first draft, not a saved entry: it lands in the first block where it
  /// can be corrected, and nothing is stored until Save is tapped. Ignored
  /// when [entry] is set, which already has words of its own.
  final String? initialText;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  /// The writing, in the places it was put.
  late final List<_PlacedBlock> _blocks = _startingBlocks();

  /// Which block the cursor is in, so the format buttons know what to act on.
  int _focusedBlock = 0;

  /// What was on the page when it opened, so leaving can tell whether
  /// anything would actually be lost. Set once the blocks exist.
  late String _openedWithBody;
  late String _openedWithStyle;

  @override
  void initState() {
    super.initState();
    // What was on the page before this visit, which for a transcript is
    // nothing: the words are unsaved the moment they arrive, so leaving has
    // to ask rather than quietly dropping them.
    _openedWithBody = widget.entry?.body ?? '';
    _openedWithStyle = _styleWithBlocks().encode();
  }

  /// The blocks this note opens with.
  ///
  /// A note saved since writing could be placed carries its own. One saved
  /// before that carries its words in the entry's body and nothing else, so a
  /// single block is seeded from it at the top of the page -- which is exactly
  /// where that note has always shown them.
  List<_PlacedBlock> _startingBlocks() {
    final stored = _startingStyle().blocks;
    if (stored.isNotEmpty) {
      return [
        for (var i = 0; i < stored.length; i++)
          _makeBlock(stored[i].text, stored[i].dx, stored[i].dy,
              stored[i].width, i),
      ];
    }
    final opening = widget.entry?.body ?? widget.initialText ?? '';
    return [_makeBlock(opening, 0, 0, 0.95, 0)];
  }

  _PlacedBlock _makeBlock(
      String text, double dx, double dy, double width, int index) {
    final block = _PlacedBlock(
      controller: TextEditingController(text: text),
      focus: FocusNode(),
      dx: dx,
      dy: dy,
      width: width,
    );
    // Rebuilt as it is typed in, so the hint, the Save state and the leaving
    // check all see the current text.
    block.controller.addListener(() {
      if (mounted) setState(() {});
    });
    block.focus.addListener(() {
      if (!mounted) return;
      if (block.focus.hasFocus) {
        setState(() => _focusedBlock = _blocks.indexOf(block));
      } else {
        _dropIfBlank(block);
      }
    });
    return block;
  }

  /// An empty block that has been left is taken off the page.
  ///
  /// Without this, every stray tap on the paper would leave an invisible box
  /// behind, and dragging one later would look like the page had a ghost in it.
  void _dropIfBlank(_PlacedBlock block) {
    if (_blocks.length <= 1) return;
    if (block.controller.text.trim().isNotEmpty) return;
    setState(() {
      _blocks.remove(block);
      _focusedBlock = _focusedBlock.clamp(0, _blocks.length - 1);
    });
    // Disposed after the frame, never here: this runs inside the focus node's
    // own listener, and disposing it mid-notification trips an assertion in
    // ChangeNotifier.
    WidgetsBinding.instance.addPostFrameCallback((_) => block.dispose());
  }

  /// The controller the format buttons act on.
  TextEditingController get _body =>
      _blocks[_focusedBlock.clamp(0, _blocks.length - 1)].controller;

  /// Everything written, in reading order.
  ///
  /// The entry's `body` is still one string: the list card previews it, and
  /// anything that searches a note reads it. Sorting by position is what keeps
  /// that string in the order the page is read rather than the order the
  /// blocks happened to be created.
  String _bodyText() {
    final ordered = [..._blocks]..sort((a, b) {
        final down = a.dy.compareTo(b.dy);
        return down != 0 ? down : a.dx.compareTo(b.dx);
      });
    return ordered
        .map((b) => b.controller.text.trim())
        .where((t) => t.isNotEmpty)
        .join('\n\n');
  }

  /// The style, carrying the blocks as they stand right now.
  NoteStyle _styleWithBlocks() => _style.copyWith(
        blocks: [
          for (final b in _blocks)
            if (b.controller.text.trim().isNotEmpty)
              NoteTextBlock(
                text: b.controller.text,
                dx: b.dx,
                dy: b.dy,
                width: b.width,
              ),
        ],
      );

  late NoteStyle _style = _startingStyle();

  /// The style the editor opens on.
  ///
  /// An existing entry opens on its own stored style. A new one opens on the
  /// paper picked in the gallery, and on the default when it was opened some
  /// other way.
  NoteStyle _startingStyle() {
    final stored = NoteStyle.decode(widget.entry?.rawJson);
    if (widget.entry != null || widget.initialTemplate == null) return stored;
    return stored.copyWith(template: widget.initialTemplate);
  }

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
        SnackBar(
          content: Text(AppLocalizations.of(context).noteNoPhoto),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// The writing area, so a sticker tap lands in fractions of the right box.
  final GlobalKey _pageKey = GlobalKey();

  @override
  void dispose() {
    for (final block in _blocks) {
      block.dispose();
    }
    super.dispose();
  }

  /// Which sticker is being adjusted, if any.
  int? _selectedSticker;

  /// The ink, taken from the chosen colour or from whatever is behind the
  /// words when none has been chosen.
  ///
  /// On a decorated page that is the panel, not the printed ground: the
  /// ground can be a deep red, and reading the ink off it would put white
  /// text on a cream sheet.
  Color get _ink => _style.inkOn(_style.background);

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

  /// The same placement, for one of the drawn stickers.
  void _addDrawnSticker(JournalSticker sticker) {
    setState(() {
      final n = _style.stickers.length;
      _style = _style.copyWith(stickers: [
        ..._style.stickers,
        NoteSticker.drawn(
          sticker,
          dx: 0.5,
          dy: (0.28 + n * 0.06).clamp(0.0, 0.9),
        ),
      ]);
    });
  }

  /// Puts a prefix on the line the cursor is in, or takes it off again.
  ///
  /// The body is one plain string, so a list is characters in the text rather
  /// than a structure around it. That is also why it survives being saved:
  /// there is nothing to save but the text.
  void _toggleLinePrefix(String prefix) {
    final text = _body.text;
    final caret = _body.selection.baseOffset;
    final at = caret < 0 || caret > text.length ? text.length : caret;

    final lineStart = text.lastIndexOf('\n', at > 0 ? at - 1 : 0) + 1;
    var lineEnd = text.indexOf('\n', lineStart);
    if (lineEnd < 0) lineEnd = text.length;
    final line = text.substring(lineStart, lineEnd);

    // Whatever prefix is already on the line comes off first, so tapping
    // bullet on a numbered line swaps it rather than stacking the two.
    var stripped = line;
    for (final existing in _linePrefixes) {
      if (stripped.startsWith(existing)) {
        stripped = stripped.substring(existing.length);
        break;
      }
    }

    final removing = line.startsWith(prefix);
    final replacement = removing ? stripped : '$prefix$stripped';
    final shift = replacement.length - line.length;

    setState(() {
      _body.value = TextEditingValue(
        text: text.replaceRange(lineStart, lineEnd, replacement),
        selection: TextSelection.collapsed(
          offset: (at + shift).clamp(lineStart, text.length + shift),
        ),
      );
    });
  }

  /// Every prefix the list buttons write, longest first so a check box is not
  /// mistaken for a bullet.
  static const List<String> _linePrefixes = ['1. ', '\u2022 ', '\u2610 '];

  void _resizeSticker(int index, double by) {
    setState(() {
      final stickers = [..._style.stickers];
      stickers[index] = stickers[index]
          .copyWith(scale: (stickers[index].scale + by).clamp(0.5, 3.0));
      _style = _style.copyWith(stickers: stickers);
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
      // The indexes below it have all shifted, so a stale selection would
      // point at the wrong sticker.
      _selectedSticker = null;
    });
  }

  bool get _isEmpty => _bodyText().isEmpty;

  /// Whether anything has been written or changed since the page opened.
  bool get _isDirty =>
      _bodyText() != _openedWithBody ||
      _styleWithBlocks().encode() != _openedWithStyle;

  /// The entry's name, taken from what was written.
  ///
  /// There is no title field any more -- a heading to fill in before writing
  /// is a thing to get past, and most entries were left "Untitled". The first
  /// line names the entry instead, which is what it was going to say anyway.
  String get _derivedTitle {
    for (final line in _bodyText().split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // Long enough to identify the entry in the list, short enough that the
      // card shows it rather than an ellipsis.
      return trimmed.length <= 60 ? trimmed : '${trimmed.substring(0, 57)}...';
    }
    return 'Untitled';
  }

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
      title: _derivedTitle,
      body: _bodyText(),
      moodKey: existing?.moodKey ?? '',
      dateTime: existing?.dateTime ?? now.toIso8601String(),
      // The look travels with the writing, and so does where it was put.
      rawJson: _styleWithBlocks().encode(),
      aiMetadata: existing?.aiMetadata,
    ));
  }

  /// Asked on the way out, when there is something that would be lost.
  ///
  /// Returns true once it is safe to leave -- either the writing has been
  /// handed back to the list, or it was deliberately thrown away.
  Future<bool> _confirmLeaving() async {
    if (!_isDirty || _isEmpty) return true;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Save this entry?',
          style: GoogleFonts.manrope(
            height: 1.4,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'You have written something that has not been saved yet.',
          style: GoogleFonts.manrope(height: 1.5, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'stay'),
            child: Text(AppLocalizations.of(context).noteKeepWriting),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(
              'Discard',
              style: GoogleFonts.manrope(color: BlushyColors.danger),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(
              'Save',
              style: GoogleFonts.manrope(
                color: BlushyColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted || choice == null || choice == 'stay') return false;
    if (choice == 'save') {
      // `_save` pops with the entry itself, so leaving is already done.
      _save();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The dialog decides, so the pop is taken over rather than allowed.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Captured before the await, so the pop does not reach for a context
        // that may have gone while the dialog was open.
        final navigator = Navigator.of(context);
        if (await _confirmLeaving() && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
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
            if (_selectedSticker != null) _stickerControls(),
            if (_tray != null) _trayFor(_tray!),
            _toolbar(),
          ],
        ),
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
              rect: _writingArea(size),
              child: Builder(
                builder: (context) {
                  final area = _writingArea(size).size;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Underneath everything: a tap on bare paper starts a
                      // new block there. Translucent so taps that land on a
                      // block reach the block instead.
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapUp: (details) =>
                              _writeAt(details.localPosition, area),
                        ),
                      ),
                      for (int i = 0; i < _blocks.length; i++)
                        _blockAt(i, area),
                    ],
                  );
                },
              ),
            ),
            for (int i = 0; i < _style.stickers.length; i++)
              _stickerAt(i, size),
          ],
        );
      },
    );
  }

  /// Where writing is allowed to go on this paper.
  Rect _writingArea(Size size) => NotePaper
      .panelRect(_style.template, size)
      .deflate(_style.template.isDecorated ? 18 : 12);

  /// Starts a block where the paper was tapped.
  ///
  /// This is the whole point of the change: writing used to begin at the top
  /// of the page and run down, so anything that belonged in the middle had to
  /// be pushed there with blank lines.
  void _writeAt(Offset where, Size area) {
    if (area.width <= 0 || area.height <= 0) return;

    // A tap next to a block that is already empty just puts the cursor back
    // in it, rather than stacking a second empty box on top of the first.
    for (var i = 0; i < _blocks.length; i++) {
      final block = _blocks[i];
      if (block.controller.text.trim().isNotEmpty) continue;
      final at = Offset(block.dx * area.width, block.dy * area.height);
      if ((at - where).distance < 44) {
        block.focus.requestFocus();
        return;
      }
    }

    final block = _makeBlock(
      '',
      (where.dx / area.width).clamp(0.0, 0.9),
      (where.dy / area.height).clamp(0.0, 0.95),
      // Whatever is left to the right edge, so a block started near the middle
      // still has room for a sentence.
      (1 - (where.dx / area.width)).clamp(0.25, 1.0),
      _blocks.length,
    );
    setState(() {
      _blocks.add(block);
      _focusedBlock = _blocks.length - 1;
    });
    block.focus.requestFocus();
  }

  /// One placed piece of writing.
  Widget _blockAt(int index, Size area) {
    final block = _blocks[index];
    final focused = block.focus.hasFocus;
    // The only block on a note nobody has written in yet: it carries the hint
    // that says the page can be written on at all.
    final showHint = _blocks.length == 1 && block.controller.text.isEmpty;

    return Positioned(
      left: block.dx * area.width,
      top: block.dy * area.height,
      width: (block.width * area.width).clamp(80.0, area.width),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A handle rather than a drag on the text: dragging the words
          // themselves is how you select them, and a block you cannot select
          // text in is worse than one you cannot move.
          if (focused)
            GestureDetector(
              onPanUpdate: (d) => _moveBlock(index, d.delta, area),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: BlushyColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.drag_indicator_rounded,
                        size: 14, color: BlushyColors.primary),
                    const SizedBox(width: 2),
                    Text(
                      'Move',
                      style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: BlushyColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          TextField(
            controller: block.controller,
            focusNode: block.focus,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: _style.textStyle(color: _ink),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: showHint ? 'Tap anywhere on the page and write.' : null,
              hintStyle:
                  _style.textStyle(color: _ink.withValues(alpha: 0.35)),
            ),
          ),
        ],
      ),
    );
  }

  void _moveBlock(int index, Offset delta, Size area) {
    if (area.width <= 0 || area.height <= 0) return;
    setState(() {
      final block = _blocks[index];
      block.dx = (block.dx + delta.dx / area.width).clamp(0.0, 0.9);
      block.dy = (block.dy + delta.dy / area.height).clamp(0.0, 0.95);
    });
  }

  Widget _stickerAt(int index, Size size) {
    final sticker = _style.stickers[index];
    return Positioned(
      left: sticker.dx * size.width - 22,
      top: sticker.dy * size.height - 22,
      child: GestureDetector(
        onPanUpdate: (d) => _moveSticker(index, d.delta, size),
        // A tap selects it, which opens the size and delete controls. It used
        // to do nothing, so the only way to get a sticker off the page was a
        // long press nobody would guess at -- that still works.
        onTap: () => setState(
            () => _selectedSticker = _selectedSticker == index ? null : index),
        onLongPress: () => _removeSticker(index),
        // A drawn sticker where there is one, the emoji where the record
        // predates them.
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: _selectedSticker == index
              ? BoxDecoration(
                  border: Border.all(color: BlushyColors.primary, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                )
              : null,
          child: sticker.drawn != null
              ? StickerIcon(sticker: sticker.drawn!, size: 44 * sticker.scale)
              : Text(
                  sticker.emoji,
                  style: TextStyle(fontSize: 34 * sticker.scale),
                ),
        ),
      ),
    );
  }

  // --- the four trays -------------------------------------------------------

  Widget _trayFor(String tray) {
    switch (tray) {
      case 'photo':
        return _tray_(
          'Photo',
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
                  label: AppLocalizations.of(context).noteRemove,
                  selected: false,
                  onTap: () => setState(() => _style = _style.withoutPhoto()),
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
                  Text(AppLocalizations.of(context).noteSize,
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

      case 'format':
        return _tray_(
          'Format',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Emphasis is the note's, not a word's: the writing is one
                  // plain string, and every entry already saved is one too.
                  _formatToggle(
                    icon: Icons.format_bold_rounded,
                    label: AppLocalizations.of(context).noteBold,
                    on: _style.bold,
                    onTap: () => setState(
                        () => _style = _style.copyWith(bold: !_style.bold)),
                  ),
                  _formatToggle(
                    icon: Icons.format_italic_rounded,
                    label: AppLocalizations.of(context).noteItalic,
                    on: _style.italic,
                    onTap: () => setState(
                        () => _style = _style.copyWith(italic: !_style.italic)),
                  ),
                  _formatToggle(
                    icon: Icons.format_underlined_rounded,
                    label: AppLocalizations.of(context).noteUnderline,
                    on: _style.underline,
                    onTap: () => setState(() =>
                        _style = _style.copyWith(underline: !_style.underline)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Lists',
                style: GoogleFonts.manrope(
                    fontSize: 11, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // These write into the line the cursor is in, so they are
                  // actions rather than states -- a second tap takes the
                  // prefix off again.
                  _formatToggle(
                    icon: Icons.format_list_bulleted_rounded,
                    label: AppLocalizations.of(context).noteBullet,
                    on: false,
                    onTap: () => _toggleLinePrefix('\u2022 '),
                  ),
                  _formatToggle(
                    icon: Icons.format_list_numbered_rounded,
                    label: AppLocalizations.of(context).noteNumbered,
                    on: false,
                    onTap: () => _toggleLinePrefix('1. '),
                  ),
                  _formatToggle(
                    icon: Icons.check_box_outline_blank_rounded,
                    label: AppLocalizations.of(context).noteChecklist,
                    on: false,
                    onTap: () => _toggleLinePrefix('\u2610 '),
                  ),
                ],
              ),
            ],
          ),
        );

      case 'colour':
        return _tray_(
          'Colour',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paper',
                style: GoogleFonts.manrope(
                    fontSize: 11, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final colour in NoteBackgrounds.all)
                    _swatch(
                      colour: Color(colour),
                      selected: _style.background == colour,
                      onTap: () => setState(
                          () => _style = _style.copyWith(background: colour)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Writing',
                style: GoogleFonts.manrope(
                    fontSize: 11, color: BlushyColors.secondaryText),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  // First swatch hands the colour back to the paper, which is
                  // what every note did before there was a choice -- and the
                  // only thing that stays legible on the dark papers.
                  _swatch(
                    colour: NoteBackgrounds.inkFor(_style.background),
                    selected: _style.ink == null,
                    auto: true,
                    onTap: () => setState(() => _style = _style.withPaperInk()),
                  ),
                  for (final colour in NoteInks.all)
                    _swatch(
                      colour: Color(colour),
                      selected: _style.ink == colour,
                      onTap: () => setState(
                          () => _style = _style.copyWith(ink: colour)),
                    ),
                ],
              ),
            ],
          ),
        );

      case 'stickers':
        return _tray_(
          'Stickers  \u00b7  tap to add, then tap it to resize or delete',
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // The drawn stickers first: they are the ones with a look of
              // their own, and the emoji below are whatever the device's font
              // happens to draw.
              for (final sticker in JournalSticker.values)
                Semantics(
                  button: true,
                  label: sticker.label,
                  child: GestureDetector(
                    onTap: () => _addDrawnSticker(sticker),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: BlushyColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: BlushyColors.border),
                      ),
                      child: StickerIcon(sticker: sticker, size: 28),
                    ),
                  ),
                ),
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

  /// One colour circle.
  Widget _swatch({
    required Color colour,
    required bool selected,
    required VoidCallback onTap,
    bool auto = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colour,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? BlushyColors.primary : BlushyColors.border,
            width: selected ? 2.4 : 1,
          ),
        ),
        // The automatic one is marked, or it reads as just another colour
        // that happens to match the paper.
        child: auto
            ? Icon(Icons.auto_awesome_rounded,
                size: 13,
                color: colour.computeLuminance() < 0.4
                    ? Colors.white
                    : Colors.black54)
            : null,
      ),
    );
  }

  /// A labelled button in the Format tray.
  Widget _formatToggle({
    required IconData icon,
    required String label,
    required bool on,
    required VoidCallback onTap,
  }) {
    return Material(
      color: on ? BlushyColors.primary.withValues(alpha: 0.10) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: on ? BlushyColors.primary : BlushyColors.border,
              width: on ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: on ? BlushyColors.primary : BlushyColors.text),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Size and delete for the sticker that was tapped.
  ///
  /// Dragging moved one and a long press removed it, but neither was
  /// discoverable and there was no way at all to change the size.
  Widget _stickerControls() {
    final index = _selectedSticker;
    if (index == null || index >= _style.stickers.length) {
      return const SizedBox.shrink();
    }
    final sticker = _style.stickers[index];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: BlushyColors.background,
        border: Border(top: BorderSide(color: BlushyColors.border)),
      ),
      child: Row(
        children: [
          if (sticker.drawn != null)
            StickerIcon(sticker: sticker.drawn!, size: 22)
          else
            Text(sticker.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text(
            AppLocalizations.of(context).noteSize,
            style: GoogleFonts.manrope(
                fontSize: 11, color: BlushyColors.secondaryText),
          ),
          IconButton(
            onPressed: () => _resizeSticker(index, -0.25),
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
            color: BlushyColors.text,
            tooltip: AppLocalizations.of(context).noteSmaller,
          ),
          Text(
            '${(sticker.scale * 100).round()}%',
            style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
          IconButton(
            onPressed: () => _resizeSticker(index, 0.25),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
            color: BlushyColors.text,
            tooltip: AppLocalizations.of(context).noteBigger,
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _removeSticker(index),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(AppLocalizations.of(context).actionDelete),
            style: TextButton.styleFrom(foregroundColor: BlushyColors.danger),
          ),
          TextButton(
            onPressed: () => setState(() => _selectedSticker = null),
            child: Text(AppLocalizations.of(context).actionDone),
          ),
        ],
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
            // No Paper tool: the page is chosen in the gallery before the
            // editor opens, so a second picker here only offered a way to
            // undo that choice by accident.
            //
            // The photo control lives on its own tool instead of inside that
            // tray, and only for the paper that uses one -- otherwise picking
            // Photo in the gallery left no way to choose the photo.
            if (_style.template == NoteTemplate.photo)
              _tool('photo', Icons.image_rounded, 'Photo'),
            _tool('font', Icons.text_fields_rounded, 'Font'),
            _tool('format', Icons.format_bold_rounded, 'Format'),
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

/// One block of writing while it is being edited.
///
/// The saved form is [NoteTextBlock]; this is that plus the controller and
/// focus node it needs on screen, and a position that moves as it is dragged.
class _PlacedBlock {
  _PlacedBlock({
    required this.controller,
    required this.focus,
    required this.dx,
    required this.dy,
    required this.width,
  });

  final TextEditingController controller;
  final FocusNode focus;

  double dx;
  double dy;
  double width;

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}
