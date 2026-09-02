import 'package:flutter/material.dart';
import '../../shared/skeleton.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../services/api_blushy_service.dart';
import 'recovery_session_player.dart';
import '../../core/theme.dart' hide BlushyColors;
import '../../core/storage.dart';
import '../journal/journal_screen.dart';

import '../../l10n/app_localizations.dart';
import '../journal/calendar/memory_map.dart';
import '../journal/insights/achievement_garden.dart';
import '../journal/vault/year_in_review.dart';
import '../journal/vault/memory_vault.dart';
import '../../services/journal_storage.dart';
import '../journal/insights/journal_dashboard.dart';
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
  static const List<Map<String, dynamic>> _sections = [
    {
      'title': 'Journal',
      'sub': 'Write, record and look back',
      'icon': Icons.auto_stories_rounded,
      'tint': Color(0xFFFDF2F2),
    },
    {
      'title': 'Recovery',
      'sub': 'Guided sessions for how you feel now',
      'icon': Icons.spa_rounded,
      'tint': Color(0xFFF3FAF6),
    },
    {
      'title': 'Time Capsules',
      'sub': 'Letters that unseal later',
      'icon': Icons.hourglass_empty_rounded,
      'tint': Color(0xFFFFF9F2),
    },
    {
      'title': 'Bouquet',
      'sub': 'Arrange one and share it as an image',
      'icon': Icons.local_florist_rounded,
      'tint': Color(0xFFFDF2F2),
    },
    {
      'title': 'Smart Calendar & Map',
      'sub': 'Mood grid and the places behind it',
      'icon': Icons.calendar_month_rounded,
      'tint': Color(0xFFF3FAF6),
    },
    {
      'title': 'Smart AI Search',
      'sub': 'Search across everything you have written',
      'icon': Icons.search_rounded,
      'tint': Color(0xFFF3EEFA),
    },
    {
      'title': 'Memory Vault',
      'sub': 'Starred memories and collections',
      'icon': Icons.military_tech_rounded,
      'tint': Color(0xFFFFF9F2),
    },
    {
      'title': 'Reflective Content Garden',
      'sub': 'Grows with how much you reflect',
      'icon': Icons.eco_rounded,
      'tint': Color(0xFFF3FAF6),
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
          _buildWorkspaceActionCard(
            title: section['title'] as String,
            sub: section['sub'] as String,
            icon: section['icon'] as IconData,
            onTap: () => _openStudioSection(section['title'] as String),
          ),
      ],
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
        await push(const _JournalSectionScreen());
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
      case 'Smart Calendar & Map':
        await push(const MemoryMapWidget());
      case 'Smart AI Search':
        await push(const _JournalActionScreen(action: _JournalAction.search));
      case 'Reflective Content Garden':
        final entries = await JournalStorage().loadEntries('default_user');
        if (!mounted) return;
        await push(AchievementGardenWidget.fromEntries(entries));
      case 'Memory Vault':
        // The vault reads saved entries, which live in JournalStorage rather
        // than in the journal screen's own list.
        final entries = await JournalStorage().loadEntries('default_user');
        if (!mounted) return;
        await push(MemoryVaultWidget(entries: entries, onEntryTap: (e) {}));
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
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: BlushyColors.secondaryText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Relaxation techniques you can follow along with. Not medical treatment.',
          style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
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
              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
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
                              style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              session['summary']?.toString() ?? '',
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: BlushyColors.secondaryText),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              // The duration is computed from the steps, so it
                              // cannot drift from the session itself.
                              done > 0
                                  ? '$minutes min • done $done ${done == 1 ? 'time' : 'times'}'
                                  : '$minutes min',
                              style: GoogleFonts.poppins(
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
          style: GoogleFonts.poppins(
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
              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
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
                              style: GoogleFonts.poppins(
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
                              style: GoogleFonts.poppins(
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
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
                      style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.primary),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Once sealed it stays closed until that date, on any device you sign in to.',
                    style: GoogleFonts.poppins(
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BlushyColors.border),
          boxShadow: [
            BoxShadow(
              color: BlushyColors.text.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
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
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: BlushyColors.text),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sub,
                              style: GoogleFonts.poppins(fontSize: 11, color: BlushyColors.secondaryText),
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
    if (_editorTheme == 'Gratitude') paperColor = const Color(0xFFFFFDF9);
    if (_editorTheme == 'Pink Self-Love') paperColor = const Color(0xFFFFF0F2);
    if (_editorTheme == 'Travel') paperColor = const Color(0xFFF5EFE6);

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
          style: GoogleFonts.poppins(
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
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: BlushyColors.primary),
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
                    style: GoogleFonts.poppins(
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
                      color: const Color(0xFF6F42F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 6),
                        Text(
                          'AI Decorate',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
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
              color: const Color(0xFFE8DCC4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('️ Paris Stamp', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD3E4CD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(' Beach Sticker', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700)),
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
              color: const Color(0xFFFEFBE7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BlushyColors.secondary),
            ),
            child: Text(
              ' Floral Divider',
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: BlushyColors.warning),
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
              color: const Color(0xFFFFF0F2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(' Self Love Sticker', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: BlushyColors.primary)),
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
          style: GoogleFonts.poppins(
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
/// It used to be a flat list of six cards over an embedded journal, mixing
/// creating an entry with looking back at a year of them.
class _JournalSectionScreen extends StatelessWidget {
  const _JournalSectionScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: _studioAppBar(context, 'Journal'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: BlushyTheme.getPagePadding(context),
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _studioCard(
                title: 'Reflection',
                sub: 'Write, record and search what you have written',
                icon: Icons.edit_note_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _ReflectionSectionScreen(),
                  ),
                ),
              ),
              _studioCard(
                title: 'Scrapbook',
                sub: 'Build a page, or look back at the year',
                icon: Icons.auto_stories_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _ScrapbookSectionScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets someone pick a template, and returns the one they chose.
///
/// The journal has its own picker, but that one creates the entry itself.
/// This returns the name so the caller can open it on a screen of its own.
Future<String?> _pickTemplate(BuildContext context, String heading) {
  final templates = journalTemplatesForUser(context);

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: BlushyColors.text,
                ),
              ),
              const SizedBox(height: 12),
              for (final template in templates)
                ListTile(
                  leading: const Icon(Icons.star_outline_rounded,
                      color: BlushyColors.primary),
                  title: Text(
                    template,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(template),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Opens the picker, then the chosen template on its own screen.
Future<void> _createFromTemplate(BuildContext context, String heading) async {
  final template = await _pickTemplate(context, heading);
  if (template == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _JournalActionScreen(
        action: _JournalAction.writeTemplate,
        templateName: template,
      ),
    ),
  );
}

/// Writing and recording entries.
///
/// The journal used to be embedded here in a 650px box, which is why the brown
/// diary appeared at the bottom of this page and again when coming back from
/// an entry. Each option opens the journal on its own screen instead.
class _ReflectionSectionScreen extends StatelessWidget {
  const _ReflectionSectionScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: _studioAppBar(context, 'Reflection'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: BlushyTheme.getPagePadding(context),
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _studioCard(
                title: 'Create Reflection',
                sub: 'Choose a template, then write',
                icon: Icons.edit_note_rounded,
                onTap: () => _createFromTemplate(context, 'Start a reflection'),
              ),
              _studioCard(
                title: 'Record & Transcribe',
                sub: 'Speak and let Docsy write it down',
                icon: Icons.mic_none_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _JournalActionScreen(
                      action: _JournalAction.record,
                    ),
                  ),
                ),
              ),
              _studioCard(
                title: 'History',
                sub: 'Every reflection, by the date it was written',
                icon: Icons.history_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _JournalHistoryScreen(scrapbooks: false),
                  ),
                ),
              ),
              _studioCard(
                title: 'Journal Insights Dashboard',
                sub: 'Writing statistics, word count and active hours',
                icon: Icons.analytics_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const JournalDashboardWidget(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Building a scrapbook page, and looking back at a year of them.
class _ScrapbookSectionScreen extends StatelessWidget {
  const _ScrapbookSectionScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: _studioAppBar(context, 'Scrapbook'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: BlushyTheme.getPagePadding(context),
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _studioCard(
                title: 'Create Scrapbook',
                sub: 'A blank page, with stickers, tape and photo frames',
                icon: Icons.add_photo_alternate_rounded,
                // A blank canvas rather than a prompt sheet: the prompts are
                // what make Reflection a thing to answer.
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _JournalActionScreen(
                      action: _JournalAction.scrapbook,
                    ),
                  ),
                ),
              ),
              _studioCard(
                title: 'History',
                sub: 'Every scrapbook page, by the date it was made',
                icon: Icons.history_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _JournalHistoryScreen(scrapbooks: true),
                  ),
                ),
              ),
              _studioCard(
                title: 'Year in Review Scrapbook',
                sub: 'A guided multi-page recap of the year',
                icon: Icons.history_edu_rounded,
                onTap: () async {
                  final entries =
                      await JournalStorage().loadEntries('default_user');
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => YearInReviewScrapbook(
                        entries: entries,
                        year: DateTime.now().year,
                        onClose: () => Navigator.of(context).pop(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The journal on its own screen, optionally opening straight into something.
///
/// Each value opens the journal straight into one thing.
///
/// There is deliberately no "just show the journal" value: that landed on the
/// decorative cover screen, whose only action was to reveal the same journal
/// Reflection opens, and whose cover and desk choices were never saved.
enum _JournalAction { scrapbook, writeTemplate, record, search }

class _JournalActionScreen extends StatefulWidget {
  const _JournalActionScreen({required this.action, this.templateName});

  final _JournalAction action;

  /// The template to start on, when the action is [_JournalAction.writeTemplate].
  final String? templateName;

  @override
  State<_JournalActionScreen> createState() => _JournalActionScreenState();
}

class _JournalActionScreenState extends State<_JournalActionScreen> {
  final GlobalKey<BlushyJournalScreenState> _journalKey =
      GlobalKey<BlushyJournalScreenState>();

  @override
  void initState() {
    super.initState();
    // The journal has no state to act on until it has been laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final journal = _journalKey.currentState;
      if (journal == null) return;

      switch (widget.action) {
        case _JournalAction.scrapbook:
          journal.openScrapbookCanvas();
        case _JournalAction.writeTemplate:
          final template = widget.templateName;
          if (template == null) {
            journal.openWriteReflection();
          } else {
            journal.openTemplate(template);
          }
        case _JournalAction.record:
          journal.openRecordAndTranscribe();
        case _JournalAction.search:
          journal.openSmartSearch();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlushyJournalScreen(key: _journalKey);
  }
}

/// The bar every studio screen wears.
AppBar _studioAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: BlushyColors.background,
    elevation: 0,
    iconTheme: const IconThemeData(color: BlushyColors.text),
    title: Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: BlushyColors.text,
      ),
    ),
  );
}

/// One option inside a studio section.
Widget _studioCard({
  required String title,
  required String sub,
  required IconData icon,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFFDF2F2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: BlushyColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: BlushyColors.text)),
                const SizedBox(height: 3),
                Text(sub,
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: BlushyColors.secondaryText)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: BlushyColors.secondaryText),
        ],
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
                    style: GoogleFonts.poppins(
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
                              style: GoogleFonts.poppins(
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
                              style: GoogleFonts.poppins(
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

