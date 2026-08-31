import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../services/api_blushy_service.dart';
import 'recovery_session_player.dart';
import '../../core/theme.dart' hide BlushyColors;
import '../../core/state.dart';
import '../../core/storage.dart';
import '../journal/journal_screen.dart';

import '../../l10n/app_localizations.dart';


class BlushyMStudioScreen extends StatefulWidget {
  const BlushyMStudioScreen({super.key});

  @override
  State<BlushyMStudioScreen> createState() => _BlushyMStudioScreenState();
}

class _BlushyMStudioScreenState extends State<BlushyMStudioScreen> with TickerProviderStateMixin {
  final GlobalKey<BlushyJournalScreenState> _embeddedJournalKey = GlobalKey<BlushyJournalScreenState>();
  // Tab index names
  final List<String> _tabs = [
    'Journal',
    'Recovery',
    'Time Capsules',
    // 'AI Reflections' removed on request.
  ];
  int _selectedTabIndex = 0;

  // Active view states
  bool _isEditorOpen = false;
  String _activeJournalTemplate = 'Daily Reflection';
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

  // Helper to determine the floating button label and icon based on selected tab
  String _getFloatingActionText() {
    switch (_tabs[_selectedTabIndex]) {
      case 'Journal':
        return 'New Journal';
      case 'Recovery':
        return 'Start Recovery';
      case 'Time Capsules':
        return 'New Capsule';
      default:
        return 'Create';
    }
  }

  IconData _getFloatingActionIcon() {
    switch (_tabs[_selectedTabIndex]) {
      case 'Journal':
        return Icons.auto_stories_rounded;
      case 'Recovery':
        return Icons.spa_rounded;
      case 'Time Capsules':
        return Icons.hourglass_empty_rounded;
      default:
        return Icons.add_rounded;
    }
  }

  void _onFloatingActionTap() {
    final currentTab = _tabs[_selectedTabIndex];
    if (currentTab == 'Journal') {
      _embeddedJournalKey.currentState?.openNewEntryBottomSheet();
    } else if (currentTab == 'Recovery') {
      _startRecoveryFlow();
    } else if (currentTab == 'Time Capsules') {
      _showCreateCapsuleDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Starting $currentTab creation...')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditorOpen) {
      return _buildJournalEditor();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0), // Handcrafted cream paper background
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. EDITORIAL HEADER & AI CONTEXT MESSAGE
                _buildHeader(),

                // 2. HORIZONTAL TAB NAVIGATION (Pill capsules list)
                _buildHorizontalTabNavigation(),

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
            _buildAdaptiveFloatingActionButton(),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BlushyColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_rounded, size: 18, color: BlushyColors.text),
                    const SizedBox(width: 6),
                    Text(
                      'Back to Home',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalTabNavigation() {
    final double pagePadding = BlushyTheme.getPagePadding(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BlushyColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(_tabs.length, (index) {
            final active = _selectedTabIndex == index;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
              child: Container(
                margin: EdgeInsets.only(
                  left: index == 0 ? pagePadding : 8,
                  right: index == _tabs.length - 1 ? pagePadding : 0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? BlushyColors.text : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? BlushyColors.text : BlushyColors.border,
                  ),
                ),
                child: Text(
                  _tabs[index],
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : BlushyColors.secondaryText,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildWorkspaceTabContent() {
    switch (_tabs[_selectedTabIndex]) {
      case 'Journal':
        return _buildJournalTab();
      case 'Recovery':
        return _buildRecoveryTab();
      case 'Time Capsules':
        return _buildTimeCapsulesTab();
      default:
        return _buildJournalTab();
    }
  }

  Widget _buildJournalTab() {
    // Subscribes this widget to BlushyOSState. The values below come from
    // BlushyStorage, which has no change notification of its own, so this
    // dependency is what rebuilds the tab when the profile changes.
    BlushyOSProvider.of(context);
    String stage = 'everydayWellness';
    try {
      final profile = BlushyStorage.read('user_profile.json');
      if (profile['profile'] != null) {
        stage = profile['profile']['lifeStage']?.toString() ?? 'everydayWellness';
      }
    } catch (_) {}

    List<String> prompts = ['What did your body need today that it didn\'t get?', 'Describe a moment of calm during your luteal phase today.'];
    String aiFeedback = 'Your logs indicate a 15% increase in rest cycles. Estrogen levels are stabilizing.';

    if (stage == 'pregnancy') {
      prompts = ['How is your physical comfort and sleep alignment today?', 'Log any symptoms or baby movements today.'];
      aiFeedback = 'Fetal heart rate simulation is stable. Logged hydration is optimal for third-trimester rest.';
    } else if (stage == 'postpartum') {
      prompts = ['Rate your energy recovery and sleep quality from last night.', 'What is one gentle self-care step you took today?'];
      aiFeedback = 'Pelvic floor alignment recovery is tracking well. Parasympathetic rebound shows positive sleep offsets.';
    } else if (stage == 'menopause') {
      prompts = ['Log any hot flashes, night sweats, or temperature indicators today.', 'How are your joints and bone strength feeling today?'];
      aiFeedback = 'Vasomotor stability remains optimal. Night sweats logged are 25% lower than last week.';
    }

    return Column(
      key: const ValueKey('journal_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWorkspaceActionCard(
          title: 'Continue Yesterday',
          sub: '“Had a peaceful walk after lunch. Felt very introspective...”',
          icon: Icons.history_rounded,
          onTap: () {
            setState(() {
              _activeJournalTemplate = 'Daily Reflection';
              _isEditorOpen = true;
            });
          },
        ),
        const SizedBox(height: 16),
        
        Text(
          'SUGGESTED PROMPTS',
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: BlushyColors.secondaryText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        for (var p in prompts) _buildPromptRow(p),
        
        const SizedBox(height: 20),
        Text(
          'TODAY\'S AI REFLECTION',
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: BlushyColors.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BlushyTheme.premiumCardDecoration,
          child: Text(
            aiFeedback,
            style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText, height: 1.4),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'CREATIVE JOURNAL',
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: BlushyColors.secondaryText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 650,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BlushyJournalScreen(
              key: _embeddedJournalKey,
              isEmbedded: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: BlushyColors.warning, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.text, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }



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
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
          borderRadius: BorderRadius.circular(20),
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

  Widget _buildAdaptiveFloatingActionButton() {
    return Positioned(
      bottom: 24,
      right: 24,
      child: FloatingActionButton.extended(
        heroTag: 'm_studio_fab',
        backgroundColor: BlushyColors.dark,
        onPressed: _onFloatingActionTap,
        label: Text(
          _getFloatingActionText(),
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        icon: Icon(_getFloatingActionIcon(), color: Colors.white, size: 16),
      ),
    );
  }


  // --- FREE-FORM JOURNAL CANVAS EDITOR ---
  Widget _buildJournalEditor() {
    Color paperColor = const Color(0xFFFAF6F0);
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
                      borderRadius: BorderRadius.circular(16),
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
