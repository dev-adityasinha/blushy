import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart' hide BlushyColors;
import '../../../services/auth_storage.dart';
import '../../../services/api_sia_service.dart';
import '../../../services/html_audio_helper.dart';
import '../../../services/journal_storage.dart';
import '../../../theme/colors.dart';
import '../repository/journal_repository.dart';
import 'note_editor_screen.dart';
import 'note_page_background.dart';
import 'note_paper.dart';
import 'note_stickers.dart';
import 'note_style.dart';
import 'note_template_picker_screen.dart';
import '../../../l10n/app_localizations.dart';

/// The journal: every entry, one after another, newest first.
///
/// This replaced a hub of two cards -- Reflection and Scrapbook -- that had to
/// be chosen between before anything could be written. Opening the journal now
/// shows what is in it, and the button writes the next one.
///
/// Each entry is drawn in the paper, colour and typeface it was written in,
/// rather than flattened into a uniform list row: the customisation is the
/// point, and a list that ignored it would make it pointless.
class NotesJournalScreen extends StatefulWidget {
  const NotesJournalScreen({super.key});

  @override
  State<NotesJournalScreen> createState() => _NotesJournalScreenState();
}

class _NotesJournalScreenState extends State<NotesJournalScreen> {
  final JournalRepository _repository = JournalRepository();

  List<LocalJournalEntry> _entries = [];
  bool _loading = true;

  /// Voice capture, while it is running.
  HtmlAudioRecorder? _recorder;
  bool _recording = false;
  bool _transcribing = false;
  int _recordedSeconds = 0;

  /// How many times "not this one" has been tapped this session.
  ///
  /// The first prompt of the day is the same every time the screen is opened
  /// -- a question that changed on every rebuild could not be sat with. This
  /// offset is what lets her move past one she does not want, without making
  /// the first one arbitrary.
  int _promptOffset = 0;

  /// How the entries are shown. Pages by default -- they were chosen as pages
  /// and the grid shows the paper each was written on; the timeline is for
  /// reading back through them by date.
  bool _timeline = false;

  // The Stage 1 tokens, as STAGE1_DESIGN_RULES.md names them.
  static const Color _canvas = Color(0xFFFAF7F2);
  static const Color _crimson = Color(0xFFDD0D22);
  static const Color _cardBorder = Color(0xFFEFE8E0);
  static const Color _charcoal = Color(0xFF221510);
  static const Color _mutedText = Color(0xFF7A6B72);
  static const Color _hairline = Color(0xFFF3EEE9);

  String get _userId => AuthStorage.getUserId() ?? 'anon';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _repository.getAllEntries(_userId);
    if (!mounted) return;
    setState(() {
      // Newest first: the last thing written is the thing most likely to be
      // wanted, and the list is otherwise unbounded.
      _entries = entries.toList()
        ..sort((a, b) => _sortKey(b).compareTo(_sortKey(a)));
      _loading = false;
    });
  }

  /// Sorted on the timestamp where there is one, falling back to the date.
  ///
  /// Entries written before `dateTime` existed only carry a day, so two from
  /// the same day would otherwise swap places on every load.
  String _sortKey(LocalJournalEntry entry) =>
      entry.dateTime ?? '${entry.date}T00:00:00.000';

  /// Writing a new entry: pick the page first, then write on it.
  ///
  /// The papers were always there, but inside the editor behind a toolbar
  /// icon, so a new entry always began on the plain default. Backing out of
  /// the gallery writes nothing -- the editor is never opened.
  Future<void> _createEntry({String? initialText}) async {
    final template = await Navigator.of(context).push<NoteTemplate>(
      MaterialPageRoute(builder: (_) => const NoteTemplatePickerScreen()),
    );
    if (template == null || !mounted) return;

    await _openEditor(template: template, initialText: initialText);
  }

  /// Opens the editor, and keeps whatever comes back.
  ///
  /// [entry] is an existing entry being reopened; [template] is the page a new
  /// one was started on. They are never both set.
  Future<void> _openEditor({
    LocalJournalEntry? entry,
    NoteTemplate? template,
    String? initialText,
  }) async {
    final saved = await Navigator.of(context).push<LocalJournalEntry>(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          entry: entry,
          initialTemplate: template,
          initialText: initialText,
        ),
      ),
    );
    if (saved == null || !mounted) return;

    await _repository.addOrUpdateEntry(_userId, saved);
    await _load();
  }

  Future<void> _confirmDelete(LocalJournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context).noteDeleteEntry,
            style: GoogleFonts.manrope(height: 1.5, 
                fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text(
          'It will not be recoverable.',
          style: GoogleFonts.manrope(height: 1.5, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.of(context).noteKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppLocalizations.of(context).actionDelete,
                style: GoogleFonts.manrope(color: BlushyColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _repository.deleteEntry(_userId, entry.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final padding = BlushyTheme.getPagePadding(context);

    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: _canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _charcoal),
        // The name is in the editorial heading below, where it can breathe.
        title: const SizedBox.shrink(),
      ),
      bottomNavigationBar: _createButton(),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(padding, 4, padding, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildJournalHeading(),
                          const SizedBox(height: 26),
                          _buildTodayBlock(),
                          const SizedBox(height: 26),
                          if (_entries.isNotEmpty) _buildMemoriesHeader(),
                        ]),
                      ),
                    ),
                    if (_entries.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _empty(),
                      )
                    else if (_timeline)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(padding, 0, padding, 24),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(_timelineSlivers()),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(padding, 0, padding, 24),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            // The same proportions as the gallery, so an entry
                            // looks like the page it was written on.
                            childAspectRatio: 0.66,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _entryCard(_entries[index]),
                            childCount: _entries.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  /// The heading: what this place is, in its own words.
  Widget _buildJournalHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Journal'),
        Text(
          'Your life, in your words.',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: _charcoal,
            height: 1.15,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "A private place for everything you don't want to lose.",
          style: GoogleFonts.manrope(
            fontSize: 12.5,
            color: _mutedText,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildEyebrow(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: _crimson,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  /// Today: the question, and the two ways in that actually exist.
  ///
  /// Voice capture is deliberately absent rather than shown greyed out: a way
  /// in that does nothing is worse than one that is not offered yet.
  Widget _buildTodayBlock() {
    final written = _writtenToday();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow('Today'),
        Container(height: 1, color: _hairline),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            written ? 'Anything left unsaid?' : 'What happened today?',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 21,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: _charcoal,
              height: 1.35,
            ),
          ),
        ),
        // Wrapped, not a Row: three of these are wider than a phone, and a
        // fixed Row simply cut the last one off.
        if (_recording)
          _buildRecordingBar()
        else if (_transcribing)
          _buildTranscribingBar()
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildWayIn(
                icon: Icons.mic_rounded,
                label: AppLocalizations.of(context).noteTellMe,
                onTap: _toggleVoice,
              ),
              _buildWayIn(
                icon: Icons.edit_rounded,
                label: AppLocalizations.of(context).noteWriteIt,
                onTap: () => _createEntry(),
              ),
              _buildWayIn(
                icon: Icons.lightbulb_outline_rounded,
                label: AppLocalizations.of(context).noteGivePrompt,
                onTap: _showPrompt,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildWayIn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: _crimson),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// While she is talking: the time so far, and the way to stop.
  Widget _buildRecordingBar() {
    final minutes = (_recordedSeconds ~/ 60).toString();
    final seconds = (_recordedSeconds % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: _crimson,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Listening  $minutes:$seconds',
          style: GoogleFonts.manrope(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _charcoal,
          ),
        ),
        const Spacer(),
        _buildWayIn(
          icon: Icons.stop_rounded,
          label: AppLocalizations.of(context).actionDone,
          onTap: _toggleVoice,
        ),
      ],
    );
  }

  Widget _buildTranscribingBar() {
    return Row(
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: _crimson),
        ),
        const SizedBox(width: 10),
        Text(
          'Writing that down...',
          style: GoogleFonts.manrope(fontSize: 12.5, color: _mutedText),
        ),
      ],
    );
  }

  /// Whether anything was written today, so the question can change.
  bool _writtenToday() {
    final now = DateTime.now();
    for (final entry in _entries) {
      final at = DateTime.tryParse(entry.dateTime ?? entry.date);
      if (at == null) continue;
      if (at.year == now.year && at.month == now.month && at.day == now.day) {
        return true;
      }
    }
    return false;
  }

  /// One question to start from, then the page chooser.
  ///
  /// Chosen by the day rather than at random: a prompt that changes every time
  /// the screen rebuilds is not something anybody can sit with.
  static const List<String> _prompts = [
    'What is taking up the most space in your mind right now?',
    'What would you like to remember about today?',
    'What did you need today that you did not ask for?',
    'What went better than you expected?',
    'What can wait until tomorrow?',
    'What would you tell yourself this morning?',
    'What are you carrying that you would rather put down?',
  ];

  /// The question currently on offer.
  String get _currentPrompt {
    final now = DateTime.now();
    final day = now.difference(DateTime(now.year, 1, 1)).inDays;
    return _prompts[(day + _promptOffset) % _prompts.length];
  }

  Future<void> _showPrompt() async {
    final prompt = _currentPrompt;

    // Named outcomes rather than a bool: dismissing the sheet by tapping
    // outside it also returns null, and that is not the same as asking for a
    // different question.
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Something to start from',
          style: GoogleFonts.manrope(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: _mutedText),
        ),
        content: Text(
          prompt,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 21,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            color: _charcoal,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'another'),
            child: Text(AppLocalizations.of(context).noteNotThisOne),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'write'),
            child: Text(
              'Write about it',
              style: GoogleFonts.manrope(
                  color: _crimson, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (choice == 'write') {
      await _createEntry();
      return;
    }
    if (choice == 'another') {
      // Shown straight away rather than sending her back to the page to tap
      // again. Dismissing the sheet falls through to neither.
      setState(() => _promptOffset++);
      await _showPrompt();
    }
  }

  // --- voice ---------------------------------------------------------------

  /// Starts recording, or stops and turns what was said into an entry.
  ///
  /// The transcript opens in the editor rather than saving itself: what comes
  /// back from speech recognition is a first draft, and the page it lands on
  /// is where it gets corrected. That is also the confirmation step -- nothing
  /// is stored until Save is tapped.
  Future<void> _toggleVoice() async {
    if (_recording) {
      await _finishVoice();
      return;
    }

    try {
      final recorder = HtmlAudioRecorder();
      recorder.onProgress = (seconds) {
        if (mounted) setState(() => _recordedSeconds = seconds);
      };
      await recorder.start();
      if (!mounted) return;
      setState(() {
        _recorder = recorder;
        _recording = true;
        _recordedSeconds = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _recording = false);
      _say('Microphone not available: $e');
    }
  }

  Future<void> _finishVoice() async {
    final recorder = _recorder;
    if (recorder == null) return;

    setState(() {
      _recording = false;
      _transcribing = true;
    });

    try {
      final result = await recorder.stop();
      final bytes = result?.bytes ?? const <int>[];
      if (bytes.isEmpty) {
        if (mounted) setState(() => _transcribing = false);
        _say('Nothing was recorded.');
        return;
      }

      final text = await ApiSiaService().transcribeAudioBytes(
        bytes,
        'journal_voice_${DateTime.now().millisecondsSinceEpoch}'
            '.${recorder.fileExtension}',
        mimeType: recorder.mimeType,
      );

      if (!mounted) return;
      setState(() => _transcribing = false);

      if (text.trim().isEmpty) {
        _say('No speech was recognised. You can write it instead.');
        return;
      }

      // Straight to the page, with the words already on it.
      await _createEntry(initialText: text.trim());
    } on TranscriptionUnavailable catch (e) {
      if (!mounted) return;
      setState(() => _transcribing = false);
      _say('${e.message} You can write it instead.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _transcribing = false);
      _say('Could not transcribe that: $e');
    } finally {
      _recorder = null;
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// The memories header, and the two ways of looking at them.
  Widget _buildMemoriesHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildEyebrow('Your memories')),
        _buildViewToggle(Icons.grid_view_rounded, 'Pages', !_timeline,
            () => setState(() => _timeline = false)),
        const SizedBox(width: 4),
        _buildViewToggle(Icons.notes_rounded, 'Timeline', _timeline,
            () => setState(() => _timeline = true)),
      ],
    );
  }

  Widget _buildViewToggle(
      IconData icon, String label, bool on, VoidCallback onTap) {
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: on ? _crimson.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 16, color: on ? _crimson : _mutedText),
        ),
      ),
    );
  }

  /// The entries as a timeline, grouped by the month they were written in.
  List<Widget> _timelineSlivers() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    final widgets = <Widget>[];
    String? currentMonth;

    for (final entry in _entries) {
      final at = DateTime.tryParse(entry.dateTime ?? entry.date);
      final now = DateTime.now();
      final month = at == null
          ? 'Earlier'
          : at.year == now.year
              ? months[at.month - 1]
              : '${months[at.month - 1]} ${at.year}';

      if (month != currentMonth) {
        currentMonth = month;
        widgets.add(Padding(
          padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 20, bottom: 6),
          child: Text(
            month,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _charcoal,
            ),
          ),
        ));
      } else {
        widgets.add(Container(height: 1, color: _hairline));
      }

      widgets.add(_timelineRow(entry, at));
    }

    return widgets;
  }

  /// One entry on the timeline: the day, and the first thing it says.
  Widget _timelineRow(LocalJournalEntry entry, DateTime? at) {
    final style = NoteStyle.decode(entry.rawJson);
    final firstLine = entry.title.trim().isEmpty ? 'Untitled' : entry.title.trim();

    return InkWell(
      onTap: () => _openEditor(entry: entry),
      onLongPress: () => _confirmDelete(entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Text(
                at == null ? '--' : at.day.toString().padLeft(2, '0'),
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _crimson,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: _charcoal,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // The paper it was written on -- the one thing the app
                      // actually knows about the entry beyond its words.
                      Text(
                        style.template.label,
                        style: GoogleFonts.manrope(
                            fontSize: 11, color: _mutedText),
                      ),
                      if (style.stickers.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${style.stickers.length} sticker'
                          '${style.stickers.length == 1 ? '' : 's'}',
                          style: GoogleFonts.manrope(
                              fontSize: 11, color: _mutedText),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: _mutedText),
          ],
        ),
      ),
    );
  }

  /// The way in, at the bottom where the thumb is.
  ///
  /// In the Scaffold's bottom slot rather than floating over the list, so it
  /// never covers the last entry and the list never has to leave a gap for it.
  Widget _createButton() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          BlushyTheme.getPagePadding(context),
          8,
          BlushyTheme.getPagePadding(context),
          12,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _createEntry,
            style: FilledButton.styleFrom(
              backgroundColor: BlushyColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 22),
            label: Text(
              'Create Journal',
              style: GoogleFonts.manrope(
                height: 1.5,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_stories_rounded,
                size: 40, color: BlushyColors.secondaryText),
            const SizedBox(height: 14),
            Text(
              'Nothing written yet.',
              style: GoogleFonts.manrope(height: 1.5, 
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: BlushyColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap Create Journal to pick a page and start writing. '
              'Nobody sees it but you.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.5,
                color: BlushyColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One entry, shown in the paper it was written on.
  Widget _entryCard(LocalJournalEntry entry) {
    final style = NoteStyle.decode(entry.rawJson);
    // Read off the panel, which is what the words sit on.
    final ink = NoteBackgrounds.inkFor(style.background);
    final ground = style.template.isDecorated
        ? Color(style.template.ground!)
        : style.backgroundColor;

    return Material(
      color: ground,
      borderRadius: BorderRadius.circular(BlushyTheme.radius),
      child: InkWell(
        onTap: () => _openEditor(entry: entry),
        onLongPress: () => _confirmDelete(entry),
        borderRadius: BorderRadius.circular(BlushyTheme.radius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BlushyTheme.radius),
            border: Border.all(color: BlushyColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BlushyTheme.radius),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                // The same measurement the editor writes inside, so the card
                // shows the entry where the entry actually sits. Without it
                // the title was drawn over Botanical's stems.
                final panel = NotePaper.panelRect(style.template, size)
                    .deflate(style.template.isDecorated ? 8 : 12);

                return Stack(
              children: [
                Positioned.fill(
                  child: NotePageBackground(
                    style: style,
                    ink: ink,
                    lineHeight: 14,
                  ),
                ),
                Positioned.fromRect(
                  rect: panel,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.title.isEmpty ? 'Untitled' : entry.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: style.textStyle(color: ink).copyWith(
                                    fontSize: 13,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (style.stickers.isNotEmpty)
                            // A glance at what was stuck on it, without
                            // reproducing the whole page at thumbnail size.
                            // A drawn sticker has no emoji to print, so it is
                            // drawn small rather than left as a blank.
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final s in style.stickers.take(2))
                                  s.drawn != null
                                      ? Padding(
                                          padding:
                                              const EdgeInsets.only(left: 2),
                                          child: StickerIcon(
                                              sticker: s.drawn!, size: 14),
                                        )
                                      : Text(
                                          s.emoji,
                                          style:
                                              const TextStyle(fontSize: 12),
                                        ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _dateLabel(entry),
                        style: GoogleFonts.manrope(
                          height: 1.4,
                          fontSize: 9.5,
                          color: ink.withValues(alpha: 0.55),
                        ),
                      ),
                      if (entry.body.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        // Fills whatever the title left and ellipsizes there,
                        // so a long first line cannot push the page open.
                        Expanded(
                          child: Text(
                            entry.body.trim(),
                            overflow: TextOverflow.ellipsis,
                            style: style
                                .textStyle(color: ink)
                                .copyWith(fontSize: 11, height: 1.35),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _dateLabel(LocalJournalEntry entry) {
    final parsed = DateTime.tryParse(entry.dateTime ?? entry.date);
    if (parsed == null) return entry.date;

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    final sameDay = parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
    if (sameDay) return 'Today';

    final label = '${parsed.day} ${months[parsed.month - 1]}';
    return parsed.year == now.year ? label : '$label ${parsed.year}';
  }
}
