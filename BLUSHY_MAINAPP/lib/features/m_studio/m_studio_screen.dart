import 'package:flutter/material.dart';
import '../../shared/skeleton.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../services/api_blushy_service.dart';
import 'recovery_session_player.dart';
import '../../core/theme.dart' hide BlushyColors;
import '../../core/storage.dart';
import '../journal/journal_screen.dart';
import '../journal/notes/notes_journal_screen.dart';
import 'view_models/m_studio_view_model.dart';

import '../../l10n/app_localizations.dart';
import '../../services/journal_storage.dart';
import 'dart:convert';
import '../partner/digibouquet/state/bouquet_state.dart';
import '../partner/digibouquet/screens/home_screen.dart' show HomeScreen;
import '../partner/digibouquet/models/auth_models.dart';
import '../../services/auth_storage.dart';
import 'package:provider/provider.dart';
import '../../services/user_state_store.dart';


class BlushyMStudioScreen extends StatefulWidget {
  const BlushyMStudioScreen({super.key});

  @override
  State<BlushyMStudioScreen> createState() => _BlushyMStudioScreenState();
}

class _BlushyMStudioScreenState extends State<BlushyMStudioScreen> with TickerProviderStateMixin {
  // Tab index names
  ///
  /// M Studio used to be three horizontal tabs with everything else buried in
  /// a bottom sheet inside the embedded journal. It is a hub now: every area
  /// is a card, and opening one shows that area's own cards.

  /// A destination inside the Journal section that needs the embedded journal
  /// to be mounted first. Run once the section has been laid out.
  /// Set while a section screen is open, so data loaded here can redraw it.
  VoidCallback? _refreshOpenSection;

  /// The hub, in the order it is shown.
  ///
  /// Smart Calendar & Map, Smart AI Search, Memory Vault and the Reflective
  /// Content Garden used to sit here too. They were removed from the hub, not
  /// from the app: all four are still reached from inside the Journal, which
  /// is where the writing they read actually lives.
  // The Stage 1 tokens, named as STAGE1_DESIGN_RULES.md names them, so this
  // page and the dashboards are demonstrably the same system rather than two
  // that happen to look alike.
  static const Color _canvas = Color(0xFFFAF7F2);
  static const Color _crimson = Color(0xFFDD0D22);
  static const Color _cardBorder = Color(0xFFEFE8E0);
  static const Color _charcoal = Color(0xFF221510);
  static const Color _mutedText = Color(0xFF7A6B72);

  static const List<Map<String, dynamic>> _sections = [
    {
      'title': 'Journal',
      // The kind of thing this is, not a second title. Four cards that all
      // start with a bold noun are hard to tell apart at a glance; the chip is
      // what separates writing from resting from saving.
      'kind': 'WRITE & REFLECT',
      // Two or three words under a name in a small tile. The long sentences
      // these replaced belonged to a full-width row and wrapped to four lines
      // in a grid.
      'sub': 'Write it out',
      'icon': Icons.auto_stories_rounded,
      // From the accent table in STAGE1_DESIGN_RULES.md. These were the theme's
      // primary and secondary, and `secondary` is #FF9B9E -- a pastel, which
      // the rules rule out: at a 12% tint it is barely a badge at all.
      'accent': Color(0xFF7209B7), // Royal Purple
    },
    {
      'title': 'Recovery',
      'kind': 'HEAL & RECHARGE',
      'sub': 'Slow down',
      'icon': Icons.spa_rounded,
      'accent': Color(0xFF0D9488), // Emerald Teal
    },
    {
      'title': 'Time Capsules',
      'kind': 'SAVE FOR LATER',
      'sub': 'For future you',
      'icon': Icons.hourglass_bottom_rounded,
      'accent': Color(0xFFD97706), // Warm Amber
    },
    {
      'title': 'Bouquet',
      'kind': 'CREATE & SHARE',
      'sub': 'Send some love',
      'icon': Icons.local_florist_rounded,
      'accent': Color(0xFFF72585), // Vivid Magenta
    },
  ];

  // Active view states
  bool _isEditorOpen = false;
  final String _activeJournalTemplate = 'Daily Reflection';
  String _editorTheme = 'Default'; // Default, Travel, Gratitude, Pink Self-Love
  bool _isDecorated = false;

  final TextEditingController _editorController = TextEditingController(
    text: "Walked along the botanical paths today. Felt extremely introspective and calm as my luteal cycle starts to set in. Focus is high."
  );


  // Simulation variables for Recovery

  // Time capsules state variables
  /// Capsules live on the account now.
  ///
  /// They were kept in device storage, so "Deliver in 6 Months" delivered
  /// nothing, a reinstall lost them all, and the list seeded two invented
  /// capsules -- one of which referred to a daughter.
  List<Map<String, dynamic>> _capsules = [];
  bool _capsulesLoading = false;

  /// This screen is the View; the three reads live in the tested
  /// MStudioViewModel and are mirrored back by _onStudioChanged.
  final MStudioViewModel _vm = MStudioViewModel();

  /// Guided sessions from the server. Empty until a reviewer approves them.
  List<Map<String, dynamic>> _sessions = [];
  bool _sessionsLoading = false;

  /// Delegated to the view model; _onStudioChanged mirrors the result.
  Future<void> _loadRecoverySessions() => _vm.loadSessions();

  Future<void> _loadCapsules() => _vm.loadCapsules();

  /// The View reacting to its ViewModel.
  void _onStudioChanged() {
    if (!mounted) return;
    setState(() {
      _sessions = _vm.sessions;
      _sessionsLoading = _vm.sessionsLoading;
      _capsules = _vm.capsules;
      _capsulesLoading = _vm.capsulesLoading;
      _latestEntry = _vm.latestEntry;
    });
  }

  /// Opens a capsule that has come due.
  ///
  /// The server refuses to return a sealed body, so an early tap is answered
  /// with the date rather than the contents.
  Future<void> _openCapsule(Map<String, dynamic> capsule) async {
    final capsuleId = capsule['capsuleId']?.toString() ?? '';
    if (capsuleId.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);

    if (capsule['sealed'] == true) {
      final deliverAt = DateTime.tryParse(capsule['deliverAt']?.toString() ?? '');
      messenger.showSnackBar(
        SnackBar(
          content: Text(deliverAt == null
              ? 'This one is still sealed.'
              : 'Still sealed. It opens on ${deliverAt.day}/${deliverAt.month}/${deliverAt.year}.'),
        ),
      );
      return;
    }

    final opened = await CapsulesApi.open(capsuleId);
    if (!mounted) return;

    if (opened.data == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(opened.errorMessage ?? 'Could not open that capsule.')),
      );
      return;
    }

    await _loadCapsules();
    _refreshOpenSection?.call();
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(opened.data!['title']?.toString() ?? 'Capsule'),
        content: SingleChildScrollView(
          child: Text(opened.data!['body']?.toString() ?? ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onStudioChanged);
    _loadCapsules();
    _loadRecoverySessions();
    _loadLatestEntry();
  }

  /// Delegated to the view model; _onStudioChanged mirrors the result.
  Future<void> _loadLatestEntry() => _vm.loadLatestEntry();

  LocalJournalEntry? _latestEntry;

  @override
  void dispose() {
    _vm.removeListener(_onStudioChanged);
    _vm.dispose();
    _editorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditorOpen) {
      return _buildJournalEditor();
    }

    return Scaffold(
      backgroundColor: _canvas, // Warm cream neutral canvas -- never stark white
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. EDITORIAL HEADER & AI CONTEXT MESSAGE
                _buildHeader(),

                // 2. HORIZONTAL TAB NAVIGATION (Pill capsules list)

                // 3. MAIN WORKSPACE CONTAINER (Morphing view switcher)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: BlushyTheme.getPagePadding(context), vertical: 16.0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: child,
                      ),
                      child: _buildWorkspaceTabContent(),
                    ),
                  ),
                ),
              ],
            ),

            // 4. FLOATING ADAPTIVE ACTION BUTTON
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final bool canPop = Navigator.canPop(context);
    final double pagePadding = BlushyTheme.getPagePadding(context);

    if (!canPop) {
      return const SizedBox(height: 16);
    }

    return Padding(
      padding: EdgeInsets.only(left: pagePadding, right: pagePadding, top: 16.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        ],
      ),
    );
  }

  /// The hub: one card per area of the studio.
  ///
  /// Four identical cards stacked on a plain canvas read as a settings list.
  /// The greeting and the eyebrow are deliberately unboxed, which is the rule
  /// the dashboards follow to break up a run of cards -- see
  /// STAGE1_DESIGN_RULES.md, "Card vs. Unboxed Component Layout Rules".
  Widget _buildStudioHub() {
    return Column(
      key: const ValueKey('studio_hub'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The greeting -- the "Studio & mindfulness" eyebrow, "Your quiet
        // space, <name>." and the line under it -- was removed on request.
        // The page opens on today's reflection now.
        _buildTodaysReflection(),
        const SizedBox(height: 26),
        _buildEyebrow('Explore'),
        _buildStudioGrid(),
        if (_recentItems().isNotEmpty) ...[
          const SizedBox(height: 26),
          _buildEyebrow('Recently in your studio'),
          _buildRecentList(),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  /// The four areas, two to a row.
  ///
  /// Full-width rows put four near-identical slabs down the page; a grid of
  /// small tiles reads as a set of places rather than a list of settings. The
  /// cards stay -- these are the only things here you tap, and a tap target
  /// is what a card is for.
  Widget _buildStudioGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.02,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [for (final section in _sections) _buildStudioHubCard(section)],
    );
  }

  /// One quiet question, and the way in to answering it.
  ///
  /// Unboxed between two hairlines. A prompt inside a card is another feature
  /// on the page; on the canvas it is the page saying something.
  Widget _buildTodaysReflection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEyebrow("Today's reflection"),
        Container(height: 1, color: const Color(0xFFF3EEE9)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            _reflectionPrompt(),
            style: GoogleFonts.cormorantGaramond(
              fontSize: 21,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: _charcoal,
              height: 1.35,
            ),
          ),
        ),
        Container(height: 1, color: const Color(0xFFF3EEE9)),
        // No button under it. The question is something to sit with; a call
        // to action turns it into a task, and the Journal is one tap away in
        // the grid below either way.
      ],
    );
  }

  /// The question, chosen from what is actually known.
  ///
  /// Deliberately not a claim about how she feels. The app can see when she
  /// last wrote and what time it is; it cannot see that she has "been feeling
  /// overwhelmed" without reading her entries, and a prompt that asserted
  /// that on no evidence would be worse than a plain question. So the state
  /// picks the set, and the day picks the line within it.
  String _reflectionPrompt() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;

    final last = _latestEntry;
    final lastWritten =
        DateTime.tryParse(last?.dateTime ?? last?.date ?? '');
    final daysSince =
        lastWritten == null ? null : now.difference(lastWritten).inDays;

    // A week of questions in each set rather than three, so the same one does
    // not come back every third day. The day picks it, so it holds for the
    // whole day and is different tomorrow.
    late final List<String> set;
    if (last == null) {
      set = const [
        'What have you been carrying that you don\u2019t need to carry alone?',
        'If today had a shape, what would it be?',
        'What is one thing you would like to say out loud?',
        'What would you write about if nobody would ever read it?',
        'What has today asked of you?',
        'What is the first thing that comes to mind, unedited?',
        'What would you like to be able to look back on?',
      ];
    } else if (daysSince != null && daysSince == 0) {
      set = const [
        'You have already written today. Is there anything left unsaid?',
        'What changed between this morning and now?',
        'What would you tell yourself an hour ago?',
        'What is still sitting with you?',
        'What did you leave out earlier?',
        'What would you add if you had another page?',
        'What are you still turning over?',
      ];
    } else if (daysSince != null && daysSince >= 7) {
      set = const [
        'It has been a while. What has taken up the most space since?',
        'What has been on your mind that you have not put into words?',
        'What would you like to remember about the last few days?',
        'What has changed since you last wrote?',
        'What did you not have the room to say?',
        'Where did the last week go?',
        'What would you want to remember about now?',
      ];
    } else if (now.hour >= 20) {
      set = const [
        'What are you taking to bed with you tonight?',
        'What went better today than you expected?',
        'What can wait until tomorrow?',
        'What are you glad is over?',
        'What was quietly good about today?',
        'What would you like to put down before sleeping?',
        'What did today ask of you?',
      ];
    } else {
      set = const [
        'What is taking up the most space in your mind right now?',
        'What would make today feel a little lighter?',
        'What do you need more of this week?',
        'What are you looking forward to, however small?',
        'What would you like today to be about?',
        'What is worth your attention today?',
        'What would you rather not think about?',
      ];
    }

    return set[dayOfYear % set.length];
  }

  /// What is actually in the studio, newest first.
  ///
  /// Real rows only: an account that has written nothing, saved nothing and
  /// done no session gets no section at all, rather than three placeholders
  /// pretending it has a history.
  List<Map<String, dynamic>> _recentItems() {
    final items = <Map<String, dynamic>>[];

    final entry = _latestEntry;
    if (entry != null) {
      items.add({
        'icon': Icons.auto_stories_rounded,
        'accent': const Color(0xFF7209B7),
        'label': entry.title.trim().isEmpty ? 'Untitled' : entry.title.trim(),
        'meta': 'Your latest journal',
        'open': () => _openStudioSection('Journal'),
      });
    }

    if (_capsules.isNotEmpty) {
      final capsule = _capsules.first;
      items.add({
        'icon': Icons.hourglass_bottom_rounded,
        'accent': const Color(0xFFD97706),
        'label': capsule['title']?.toString().trim().isNotEmpty == true
            ? capsule['title'].toString().trim()
            : 'A letter to future you',
        'meta': capsule['sealed'] == true ? 'Sealed' : 'Ready to open',
        'open': () => _openStudioSection('Time Capsules'),
      });
    }

    final done = _sessions.where(
        (s) => ((s['timesCompleted'] as num?)?.toInt() ?? 0) > 0);
    if (done.isNotEmpty) {
      final session = done.first;
      items.add({
        'icon': Icons.spa_rounded,
        'accent': const Color(0xFF0D9488),
        'label': session['title']?.toString() ?? 'Session',
        'meta': 'Last recovery session',
        'open': () => _openStudioSection('Recovery'),
      });
    }

    return items;
  }

  /// The recent rows: on the canvas, separated by hairlines rather than boxed.
  Widget _buildRecentList() {
    final items = _recentItems();

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Container(height: 1, color: const Color(0xFFF3EEE9)),
          InkWell(
            onTap: items[i]['open'] as VoidCallback,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: (items[i]['accent'] as Color)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(items[i]['icon'] as IconData,
                        size: 16, color: items[i]['accent'] as Color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i]['label'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i]['meta'] as String,
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            color: _mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: _mutedText),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// An uppercase category header. Always crimson, never the section's accent:
  /// four eyebrows in four colours is the rainbow the rules rule out.
  Widget _buildEyebrow(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
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

  /// One area of the studio, as a card.
  ///
  /// The generic action card is still used inside the sections; this one is
  /// only for the hub, where four cards sit together and each needs to be
  /// recognisable before it is read.
  Widget _buildStudioHubCard(Map<String, dynamic> section) {
    final accent = section['accent'] as Color;
    final title = section['title'] as String;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _openStudioSection(title),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // Pure white with one soft border, the same on every tile. The
            // accent used to tint the whole surface, the chip and the chevron
            // as well -- four cards, four colours, and nothing left to mean
            // "this one is different".
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _cardBorder),
          ),
          // A tile, not a row. The badge sits above the name the way it does
          // on the dashboards, which is what lets two fit across a phone
          // without the subtitle wrapping to four lines.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // The one place the accent is allowed: a circular badge.
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(section['icon'] as IconData, size: 22, color: accent),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _charcoal,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    section['sub'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: _mutedText,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens a section as its own screen.
  ///
  /// These used to swap the body in place, and everything that was not
  /// Journal, Recovery or Time Capsules fell through to the journal -- so
  /// Scrapbook and Smart Calendar rendered the journal page, and its cards
  /// (including the insights dashboard) appeared under every section.
  Future<void> _openStudioSection(String title) async {
    Future<void> push(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    switch (title) {
      case 'Journal':
        // Straight into the writing. This used to open a hub of two cards,
        // Reflection and Scrapbook, so opening the journal meant choosing
        // between two things before writing anything.
        await push(const NotesJournalScreen());
      case 'Recovery':
        await push(_StudioSectionScreen(
          title: 'Recovery',
          builder: () => _buildRecoveryTab(),
        ));
      case 'Time Capsules':
        await push(_StudioSectionScreen(
          title: 'Time Capsules',
          builder: () => _buildTimeCapsulesTab(),
          onRegister: (refresh) => _refreshOpenSection = refresh,
        ));
      case 'Bouquet':
        // No connections passed, so the builder's "Send to Partner" is
        // disabled and only the image share applies. Partner sending stays on
        // the Partner tab, where a connection actually exists.
        await push(
          ChangeNotifierProvider<BouquetState>(
            create: (_) => BouquetState(),
            child: HomeScreen(
              session: AuthSession(
                message: 'Verified',
                token: AuthStorage.getToken() ?? '',
                userId: AuthStorage.getUserId() ?? 'user',
                tokenType: 'Bearer',
                expiresIn: 3600,
                role: UserRole.woman,
              ),
              activeConnections: const [],
            ),
          ),
        );
    }
  }

  Widget _buildWorkspaceTabContent() => _buildStudioHub();

  // --- TAB 3: RECOVERY ---
  /// Guided sessions, loaded from the server.
  ///
  /// This tab used to show two fixed cards -- "Period Pain Relief Meditation •
  /// 12 min" and "Luteal Phase Anxiety Breathing • 8 min" -- both `onTap: () {}`.
  /// There was no player and no content, and both titles asserted a
  /// therapeutic effect nobody had reviewed.
  Widget _buildRecoveryTab() {
    return Column(
      key: const ValueKey('recovery_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Starting a session used to be the floating button, which was tied to
        // the tab strip. It is a card here so it survives that going away.
        _buildWorkspaceActionCard(
          title: 'Start a Session',
          sub: 'Begin a guided relaxation now',
          icon: Icons.spa_rounded,
          onTap: _startRecoveryFlow,
        ),
        const SizedBox(height: 8),
        Text(
          'GUIDED SESSIONS',
          style: GoogleFonts.manrope(height: 1.5, 
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: BlushyColors.secondaryText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Relaxation techniques you can follow along with. Not medical treatment.',
          style: GoogleFonts.manrope(height: 1.5, fontSize: 11, color: BlushyColors.secondaryText),
        ),
        const SizedBox(height: 14),
        if (_sessionsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Shimmer(
              child: Column(
                children: [
                  SkeletonListRow(showTrailing: true),
                  SkeletonListRow(showTrailing: true),
                  SkeletonListRow(showTrailing: true),
                ],
              ),
            ),
          )
        else if (_sessions.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BlushyTheme.premiumCardDecoration,
            alignment: Alignment.center,
            child: Text(
              // Honest about why: sessions only appear once a reviewer has
              // approved them, rather than being invented to fill the tab.
              'No sessions available yet. They appear here once they have been reviewed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.secondaryText),
            ),
          )
        else
          ..._sessions.map((session) {
            final steps = ((session['steps'] as List?) ?? const [])
                .map(RecoveryStep.fromJson)
                .whereType<RecoveryStep>()
                .toList();
            final minutes = (((session['totalSeconds'] as num?)?.toInt() ?? 0) / 60).ceil();
            final done = (session['timesCompleted'] as num?)?.toInt() ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: steps.isEmpty
                    ? null
                    : () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RecoverySessionPlayer(
                              sessionId: session['sessionId']?.toString() ?? '',
                              title: session['title']?.toString() ?? 'Session',
                              steps: steps,
                            ),
                          ),
                        );
                        // The count changes when a session finishes.
                        await _loadRecoverySessions();
                      },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BlushyTheme.premiumCardDecoration,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: BlushyColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.self_improvement_rounded,
                            size: 18, color: BlushyColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session['title']?.toString() ?? '',
                              style: GoogleFonts.manrope(height: 1.5, 
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              session['summary']?.toString() ?? '',
                              style: GoogleFonts.manrope(height: 1.5, 
                                  fontSize: 11, color: BlushyColors.secondaryText),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              // The duration is computed from the steps, so it
                              // cannot drift from the session itself.
                              done > 0
                                  ? '$minutes min • done $done ${done == 1 ? 'time' : 'times'}'
                                  : '$minutes min',
                              style: GoogleFonts.manrope(height: 1.5, 
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: BlushyColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.play_arrow_rounded,
                          size: 20, color: BlushyColors.secondaryText),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  /// Starts the first available session.
  ///
  /// This used to advance two phase counters that nothing rendered any more,
  /// so the button did nothing visible at all.
  Future<void> _startRecoveryFlow() async {
    if (_sessions.isEmpty) {
      await _loadRecoverySessions();
      if (!mounted) return;
      if (_sessions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sessions available yet.')),
        );
        return;
      }
    }

    final session = _sessions.first;
    final steps = ((session['steps'] as List?) ?? const [])
        .map(RecoveryStep.fromJson)
        .whereType<RecoveryStep>()
        .toList();
    if (steps.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecoverySessionPlayer(
          sessionId: session['sessionId']?.toString() ?? '',
          title: session['title']?.toString() ?? 'Session',
          steps: steps,
        ),
      ),
    );
    await _loadRecoverySessions();
  }

  // --- TAB 5: TIME CAPSULES ---
  Widget _buildTimeCapsulesTab() {
    return Column(
      key: const ValueKey('time_capsules_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWorkspaceActionCard(
          title: 'Create New Capsule',
          sub: 'Seal letters, voice recordings, or photos for the future.',
          icon: Icons.hourglass_top_rounded,
          onTap: _showCreateCapsuleDialog,
        ),
        const SizedBox(height: 24),
        Text(
          'ACTIVE SEALED CAPSULES',
          style: GoogleFonts.manrope(height: 1.5, 
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: BlushyColors.secondaryText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        if (_capsulesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Shimmer(
              child: Column(
                children: [
                  SkeletonListRow(),
                  SkeletonListRow(),
                ],
              ),
            ),
          )
        else if (_capsules.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BlushyTheme.premiumCardDecoration,
            alignment: Alignment.center,
            child: Text(
              'Nothing sealed yet. Write something for a day you choose, and it stays closed until then.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.secondaryText),
            ),
          )
        else
          Column(
            children: _capsules.map((cap) {
              final sealed = cap['sealed'] == true;
              final deliverAt = DateTime.tryParse(cap['deliverAt']?.toString() ?? '');
              final opened = cap['openedAt'] != null;

              return GestureDetector(
                onTap: () => _openCapsule(cap),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BlushyTheme.premiumCardDecoration,
                  child: Row(
                    children: [
                      Icon(
                        sealed ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                        color: sealed ? BlushyColors.secondaryText : BlushyColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cap['title']?.toString() ?? '',
                              style: GoogleFonts.manrope(height: 1.5, 
                                  fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              // Says what is actually true of this capsule
                              // rather than a stored label that could drift.
                              sealed
                                  ? (deliverAt == null
                                      ? 'Sealed'
                                      : 'Opens ${deliverAt.day}/${deliverAt.month}/${deliverAt.year}')
                                  : (opened ? 'Opened • tap to read again' : 'Ready • tap to open'),
                              style: GoogleFonts.manrope(height: 1.5, 
                                  fontSize: 10, color: BlushyColors.secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  /// Seals a capsule on the account.
  ///
  /// The old dialog collected a recipient and a duration but no text, so it
  /// sealed a "Letter to Future Me" with no letter in it. It also only wrote
  /// to device storage, so nothing was ever delivered.
  void _showCreateCapsuleDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String window = 'Six months';
    bool saving = false;
    String? error;

    const windows = <String, int>{
      'One month': 30,
      'Six months': 182,
      'One year': 365,
      'Five years': 1826,
    };

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setModalState) {
          Future<void> seal() async {
            final title = titleController.text.trim();
            final body = bodyController.text.trim();

            if (title.isEmpty) {
              setModalState(() => error = 'Give it a name.');
              return;
            }
            if (body.isEmpty) {
              setModalState(() => error = 'Write something to seal.');
              return;
            }

            setModalState(() {
              saving = true;
              error = null;
            });

            final deliverAt = DateTime.now().add(Duration(days: windows[window] ?? 182));
            final created = await CapsulesApi.create(
              title: title,
              body: body,
              deliverAt: deliverAt,
            );

            if (!dialogContext.mounted) return;

            if (created.data == null) {
              setModalState(() {
                saving = false;
                error = created.errorMessage ?? 'Could not seal that.';
              });
              return;
            }

            Navigator.of(dialogContext).pop();
            await _loadCapsules();
    _refreshOpenSection?.call();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Sealed until ${deliverAt.day}/${deliverAt.month}/${deliverAt.year}.',
                ),
              ),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(
              AppLocalizations.of(context).msNewTimeCapsule,
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Name it'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyController,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 5000,
                    decoration: const InputDecoration(
                      labelText: 'What do you want to say?',
                      alignLabelWithHint: true,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: window,
                    decoration: const InputDecoration(labelText: 'Open it in'),
                    items: windows.keys
                        .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                        .toList(),
                    onChanged: (val) => setModalState(() => window = val ?? 'Six months'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: GoogleFonts.manrope(height: 1.5, fontSize: 12, color: BlushyColors.primary),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Once sealed it stays closed until that date, on any device you sign in to.',
                    style: GoogleFonts.manrope(height: 1.5, 
                      fontSize: 11,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: saving ? null : seal,
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Seal'),
              ),
            ],
          );
        },
      ),
    );
  }




  Widget _buildWorkspaceActionCard({
    required String title,
    required String sub,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: BlushyColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BlushyColors.border),

        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: BlushyColors.primary,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: BlushyColors.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: BlushyColors.primary, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.manrope(height: 1.5, fontSize: 13, fontWeight: FontWeight.w700, color: BlushyColors.text),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sub,
                              style: GoogleFonts.manrope(height: 1.5, fontSize: 11, color: BlushyColors.secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJournalEditor() {
    Color paperColor = BlushyColors.background;
    if (_editorTheme == 'Gratitude') paperColor = BlushyColors.background;
    if (_editorTheme == 'Pink Self-Love') paperColor = Color.lerp(BlushyColors.background, BlushyColors.secondary, 0.18)!;
    if (_editorTheme == 'Travel') paperColor = BlushyColors.taupe;

    return Scaffold(
      backgroundColor: paperColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: BlushyColors.dark),
          onPressed: () => setState(() => _isEditorOpen = false),
        ),
        title: Text(
          _activeJournalTemplate,
          style: GoogleFonts.manrope(height: 1.5, 
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: BlushyColors.text,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final text = _editorController.text.trim();
              if (text.isNotEmpty) {
                try {
                  UserStateStore.write('mstudio_reflections', {
                    'text': text,
                    'template': _activeJournalTemplate,
                    'timestamp': DateTime.now().toIso8601String(),
                  });
                } catch (_) {}
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Journal keepsake saved!')),
              );
              setState(() => _isEditorOpen = false);
            },
            child: Text(
              AppLocalizations.of(context).msSave,
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: BlushyColors.primary),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isDecorated) ...[
                    if (_editorTheme == 'Travel') _buildTravelDecorations(),
                    if (_editorTheme == 'Gratitude') _buildGratitudeDecorations(),
                    if (_editorTheme == 'Pink Self-Love') _buildSelfLoveDecorations(),
                  ],
                  TextField(
                    controller: _editorController,
                    maxLines: null,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: BlushyColors.text,
                      height: 1.6,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Start writing or speak your thoughts...',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Editor Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: BlushyColors.border)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isDecorated = true;
                      _editorTheme = _activeJournalTemplate == 'Gratitude' ? 'Gratitude' : 'Travel';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: BlushyColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 6),
                        Text(
                          'AI Decorate',
                          style: GoogleFonts.manrope(height: 1.5, fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.text_fields_rounded, color: BlushyColors.disabled),
                const SizedBox(width: 16),
                const Icon(Icons.photo_rounded, color: BlushyColors.disabled),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelDecorations() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BlushyColors.clay,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('️ Paris Stamp', style: GoogleFonts.manrope(height: 1.5, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BlushyColors.success.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(' Beach Sticker', style: GoogleFonts.manrope(height: 1.5, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildGratitudeDecorations() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BlushyColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BlushyColors.secondary),
            ),
            child: Text(
              ' Floral Divider',
              style: GoogleFonts.manrope(height: 1.5, fontSize: 10, fontWeight: FontWeight.w700, color: BlushyColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelfLoveDecorations() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color.lerp(BlushyColors.background, BlushyColors.secondary, 0.18)!,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(' Self Love Sticker', style: GoogleFonts.manrope(height: 1.5, fontSize: 10, fontWeight: FontWeight.w700, color: BlushyColors.primary)),
          ),
        ],
      ),
    );
  }
}

/// A section of the studio, shown as its own screen.
class _StudioSectionScreen extends StatefulWidget {
  const _StudioSectionScreen({
    required this.title,
    required this.builder,
    this.onRegister,
  });

  final String title;
  final Widget Function() builder;

  /// Handed a callback that redraws this screen, and null when it closes.
  final void Function(VoidCallback?)? onRegister;

  @override
  State<_StudioSectionScreen> createState() => _StudioSectionScreenState();
}

class _StudioSectionScreenState extends State<_StudioSectionScreen> {
  @override
  void initState() {
    super.initState();
    widget.onRegister?.call(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.onRegister?.call(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: BlushyColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: BlushyColors.text),
        title: Text(
          widget.title,
          style: GoogleFonts.manrope(height: 1.5, 
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: BlushyColors.text,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: BlushyTheme.getPagePadding(context),
          vertical: 16,
        ),
        child: widget.builder(),
      ),
    );
  }
}

/// The Journal section: two ways in, Reflection and Scrapbook.
///
/// Lets someone pick a template, and returns the one they chose.
///
/// Writing and recording entries.
///
/// The journal on its own screen, optionally opening straight into something.
///
/// Each value opens the journal straight into one thing.
///
/// The bar every studio screen wears.
AppBar _studioAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: BlushyColors.background,
    elevation: 0,
    iconTheme: const IconThemeData(color: BlushyColors.text),
    title: Text(
      title,
      style: GoogleFonts.manrope(height: 1.5, 
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: BlushyColors.text,
      ),
    ),
  );
}

/// What was written, and when.
///
/// Reads the saved entries and splits them on the marker the journal writes
/// when it creates a scrapbook page, so each section lists only its own.
class _JournalHistoryScreen extends StatefulWidget {
  const _JournalHistoryScreen({required this.scrapbooks});

  /// True for the scrapbook list, false for reflections.
  final bool scrapbooks;

  @override
  State<_JournalHistoryScreen> createState() => _JournalHistoryScreenState();
}

class _JournalHistoryScreenState extends State<_JournalHistoryScreen> {
  late final Future<List<LocalJournalEntry>> _entries =
      JournalStorage().loadEntries('default_user');

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// The date an entry carries, or null when it is unreadable.
  DateTime? _dateOf(LocalJournalEntry entry) =>
      DateTime.tryParse(entry.dateTime ?? entry.date);

  bool _isScrapbook(LocalJournalEntry entry) {
    final raw = entry.rawJson;
    if (raw == null || raw.isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      return decoded['templateName'] == scrapbookTemplateName;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.scrapbooks ? 'Scrapbook history' : 'Reflection history';

    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: _studioAppBar(context, label),
      body: SafeArea(
        child: FutureBuilder<List<LocalJournalEntry>>(
          future: _entries,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SkeletonList(
                count: 4,
                itemBuilder: _historySkeletonRow,
              );
            }

            final all = snapshot.data ?? const <LocalJournalEntry>[];
            final mine = all.where((e) => _isScrapbook(e) == widget.scrapbooks).toList()
              ..sort((a, b) {
                final da = _dateOf(a);
                final db = _dateOf(b);
                if (da == null || db == null) return 0;
                return db.compareTo(da);
              });

            if (mine.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    widget.scrapbooks
                        ? 'No scrapbook pages yet.'
                        : 'No reflections yet.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(height: 1.5, 
                      fontSize: 13,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: BlushyTheme.getPagePadding(context),
                vertical: 16,
              ),
              itemCount: mine.length,
              itemBuilder: (context, index) {
                final entry = mine[index];
                final date = _dateOf(entry);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BlushyColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: BlushyColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title.trim().isEmpty
                                  ? 'Untitled'
                                  : entry.title.trim(),
                              style: GoogleFonts.manrope(height: 1.5, 
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: BlushyColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              date == null
                                  // Shown rather than invented: an entry with an
                                  // unreadable date still belongs in the list.
                                  ? 'Date unknown'
                                  : '${date.day} ${_months[date.month - 1]} ${date.year}',
                              style: GoogleFonts.manrope(height: 1.5, 
                                fontSize: 11,
                                color: BlushyColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

Widget _historySkeletonRow(BuildContext context, int index) =>
    const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: SkeletonListRow(),
    );

