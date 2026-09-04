import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart' hide BlushyColors;
import '../../../services/auth_storage.dart';
import '../../../services/journal_storage.dart';
import '../../../theme/colors.dart';
import '../repository/journal_repository.dart';
import 'note_editor_screen.dart';
import 'note_page_background.dart';
import 'note_style.dart';

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

  Future<void> _openEditor({LocalJournalEntry? entry}) async {
    final saved = await Navigator.of(context).push<LocalJournalEntry>(
      MaterialPageRoute(builder: (_) => NoteEditorScreen(entry: entry)),
    );
    if (saved == null || !mounted) return;

    await _repository.addOrUpdateEntry(_userId, saved);
    await _load();
  }

  Future<void> _confirmDelete(LocalJournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete this entry?',
            style: GoogleFonts.manrope(height: 1.5, 
                fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text(
          'It will not be recoverable.',
          style: GoogleFonts.manrope(height: 1.5, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Delete',
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
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: BlushyColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: BlushyColors.text),
        title: Text(
          'Journal',
          style: GoogleFonts.manrope(height: 1.5, 
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: BlushyColors.text,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: BlushyColors.primary,
        foregroundColor: Colors.white,
        tooltip: 'New entry',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _entries.isEmpty
                ? _empty()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        BlushyTheme.getPagePadding(context),
                        12,
                        BlushyTheme.getPagePadding(context),
                        // Clear of the button, which would otherwise sit on
                        // top of the last entry.
                        96,
                      ),
                      itemCount: _entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) =>
                          _entryCard(_entries[index]),
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
              'Tap the button to start your first entry. '
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
            child: Stack(
              children: [
                Positioned.fill(
                  child: NotePageBackground(
                    style: style,
                    ink: ink,
                    lineHeight: 22,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.title.isEmpty ? 'Untitled' : entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: style.textStyle(color: ink).copyWith(
                                    fontSize: style.fontSize + 2,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (style.stickers.isNotEmpty)
                            Text(
                              // A glance at what was stuck on it, without
                              // reproducing the whole page in a list row.
                              style.stickers
                                  .take(3)
                                  .map((s) => s.emoji)
                                  .join(),
                              style: const TextStyle(fontSize: 14),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dateLabel(entry),
                        style: GoogleFonts.manrope(height: 1.5, 
                          fontSize: 10,
                          color: ink.withValues(alpha: 0.55),
                        ),
                      ),
                      if (entry.body.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          entry.body.trim(),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: style.textStyle(color: ink),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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
