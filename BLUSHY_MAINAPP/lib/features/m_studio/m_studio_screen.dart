import 'package:flutter/material.dart';
import '../../shared/skeleton.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../shared/blushy_surface.dart';
import '../../theme/scale.dart';
import '../../services/api_blushy_service.dart';
import 'recovery_session_player.dart';
import '../../core/theme.dart' hide BlushyColors;
import '../../core/storage.dart';
import '../journal/journal_screen.dart';
import '../journal/notes/notes_journal_screen.dart';

import '../../l10n/app_localizations.dart';
import '../../services/journal_storage.dart';
import 'dart:convert';
import '../partner/digibouquet/state/bouquet_state.dart';
import '../partner/digibouquet/screens/home_screen.dart' show HomeScreen;
import '../partner/digibouquet/models/auth_models.dart';
import '../../services/auth_storage.dart';
import 'package:provider/provider.dart';


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
  static const List<Map<String, dynamic>> _sections = [
    {
      'title': 'Journal',
      // The kind of thing this is, not a second title. Four cards that all
      // start with a bold noun are hard to tell apart at a glance; the chip is
      // what separates writing from resting from saving.
      'kind': 'WRITE & REFLECT',
      'sub': 'Write, record and look back on your thoughts and feelings.',
      'icon': Icons.auto_stories_rounded,
      'accent': BlushyColors.primary,
    },
    {
      'title': 'Recovery',
      'kind': 'HEAL & RECHARGE',
      'sub': 'Guided sessions to help you feel better, anytime.',
      'icon': Icons.spa_rounded,
      'accent': BlushyColors.secondary,
    },
    {
      'title': 'Time Capsules',
      'kind': 'SAVE FOR LATER',
      'sub': 'Write letters to your future self and unseal them later.',
      'icon': Icons.hourglass_bottom_rounded,
      'accent': BlushyColors.accent,
    },
    {
      'title': 'Bouquet',
      'kind': 'CREATE & SHARE',
      'sub': 'Arrange a bouquet that reflects how you feel and share it as '
          'an image.',
      'icon': Icons.local_florist_rounded,
      'accent': BlushyColors.primary,
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

  /// Guided sessions from the server. Empty until a reviewer approves them.
  List<Map<String, dynamic>> _sessions = [];
  bool _sessionsLoading = false;

  Future<void> _loadRecoverySessions() async {
    if (mounted) setState(() => _sessionsLoading = true);

    final result = await RecoveryApi.sessions();
    if (!mounted) return;

    setState(() {
      _sessionsLoading = false;
      _sessions = result.data ?? const [];
    });
  }

  Future<void> _loadCapsules() async {
    if (mounted) setState(() => _capsulesLoading = true);

    final result = await CapsulesApi.list();
    if (!mounted) return;

    setState(() {
      _capsulesLoading = false;
      // No seeded placeholders. An empty list is what a new account has.
      _capsules = result.data ?? const [];
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
    _loadCapsules();
    _loadRecoverySessions();
  }

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditorOpen) {
      return _buildJournalEditor();
    }

    return Scaffold(
      backgroundColor: BlushyColors.background, // Handcrafted cream paper background
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
  Widget _buildStudioHub() {
    return Column(
      key: const ValueKey('studio_hub'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in _sections)
          Padding(
            padding: const EdgeInsets.only(bottom: BlushySpace.betweenCards),
            child: _buildStudioHubCard(section),
          ),
      ],
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

    return BlushySurface(
      padding: const EdgeInsets.fromLTRB(
          BlushySpace.lg, BlushySpace.lg, BlushySpace.md, BlushySpace.lg),
      accent: accent,
      onTap: () => _openStudioSection(title),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(section['icon'] as IconData, size: 26, color: accent),
          ),
          const SizedBox(width: BlushySpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: BlushySpace.sm, vertical: BlushySpace.xs),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    section['kind'] as String,
                    style: BlushyType.micro(
                      color: accent,
                      weight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: BlushySpace.md),
                Text(title, style: BlushyType.title()),
                const SizedBox(height: BlushySpace.sm),
                Text(section['sub'] as String, style: BlushyType.body()),
              ],
            ),
          ),
          const SizedBox(width: BlushySpace.sm),
          Container(
            width: BlushySpace.control,
            height: BlushySpace.control,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chevron_right_rounded, size: BlushySpace.iconChevron, color: accent),
          ),
        ],
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
                  BlushyStorage.write('mstudio_reflections.json', {
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

