import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../shared/bottom_navigation.dart';
import '../../shared/header.dart';
import '../../shared/product_tour.dart';
import '../../l10n/app_localizations.dart';
import '../m_studio/m_studio_screen.dart';
import '../sia/sia_screen.dart';
import '../partner/partner_screen.dart';
import '../../core/state.dart';
import 'dart:async';

import '../../services/daily_rollover.dart';
import '../../services/offline_event_queue.dart';
import '../../services/sia_dashboard_service.dart';
import 'home_screen.dart';

/// Asks the shell to show one of its five tabs.
///
/// The dashboard used to `Navigator.push` a second BlushyMStudioScreen, which
/// stacks another copy on top with no bottom bar and no way back to the tabs
/// except the system back gesture. Switching the tab is what those buttons
/// always meant.
class BlushyShellTabs {
  const BlushyShellTabs._();

  /// The tab the shell should show. Indices match BlushyBottomNavigation.
  static final ValueNotifier<int?> requested = ValueNotifier<int?>(null);

  static const int home = 0;
  static const int docsy = 1;
  static const int mStudio = 2;
  static const int partner = 3;

  static void open(int index) => requested.value = index;
}

class BlushyOSShell extends StatefulWidget {
  const BlushyOSShell({super.key});

  @override
  State<BlushyOSShell> createState() => _BlushyOSShellState();
}

class _BlushyOSShellState extends State<BlushyOSShell>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // Order matches BlushyBottomNavigation, with Docsy in the raised slot.
  final List<Widget> _screens = [
    const BlushyHomeScreen(),
    const BlushySiaScreen(),
    const BlushyMStudioScreen(),
    const BlushyPartnerScreen(),
  ];

  /// One anchor per destination, for the first-run tour.
  final List<GlobalKey> _navKeys = List.generate(4, (_) => GlobalKey());

  /// Header anchors for the tour: the language selector and the account button.
  final GlobalKey _tourLanguageKey = GlobalKey();
  final GlobalKey _tourProfileKey = GlobalKey();

  bool _showTour = false;

  /// Fades the incoming tab in, so switching is a transition rather than a
  /// substitution. Starts at 1 so the first frame is already opaque.
  ///
  /// Deliberately an opacity animation over the existing IndexedStack rather
  /// than an AnimatedSwitcher: a switcher builds a new subtree per index and
  /// would throw away every tab's State, which is exactly the check-in bug
  /// `checkin_tab_switch_test` exists to prevent.
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    BlushyShellTabs.requested.addListener(_onTabRequested);

    // After the first frame: the tour measures the tabs, and they have no
    // position until they have been laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || TourPreferences.hasSeenTour()) return;
      setState(() => _showTour = true);
    });

    _scheduleMidnightRollover();
  }

  /// Ends the day while she is still looking at it.
  ///
  /// App start and resume cover the two common ways a day turns over, but
  /// neither fires when the app is left open and untouched across midnight --
  /// and the check-in would then keep showing yesterday until she touched
  /// something.
  ///
  /// One shot rather than periodic, rescheduled each time it fires: a periodic
  /// timer drifts against the clock, and a pending periodic timer is what
  /// makes widget tests fail on teardown. Cancelled in [dispose], so it cannot
  /// outlive the tree that owns it.
  void _scheduleMidnightRollover() {
    _midnightTimer?.cancel();
    _midnightTimer = Timer(
      DailyRollover.untilNextMidnight(DateTime.now()),
      () async {
        if (!mounted) return;
        final rolled = await DailyRollover.runIfNeeded();
        if (!mounted) return;
        // The next one, whether or not this one had anything to do: the app
        // may sit open for days.
        _scheduleMidnightRollover();
        if (!rolled) return;
        // The check-in is rendered from the day's file, so it has to be told.
        setState(() {});
        SiaDashboardService().syncAllDashboardsFromBackend(
          state: BlushyOSProvider.of(context),
        );
      },
    );
  }

  /// The stops of the tour, in the order they appear: the four tabs, then the
  /// header's language and account controls.
  List<TourStep> _tourSteps(AppLocalizations t, String? partnerLabel) {
    return [
      TourStep(
        targetKey: _navKeys[0],
        title: t.navHome,
        body: t.tourHomeBody,
      ),
      TourStep(
        targetKey: _navKeys[BlushyBottomNavigation.siaIndex],
        title: t.navSia,
        body: t.tourSiaBody,
      ),
      TourStep(
        targetKey: _navKeys[2],
        title: t.navStudio,
        body: t.tourStudioBody,
      ),
      TourStep(
        targetKey: _navKeys[3],
        title: partnerLabel ?? t.navPartner,
        body: t.tourPartnerBody,
      ),
      TourStep(
        targetKey: _tourLanguageKey,
        title: 'Language',
        body: 'Tap here any time to change the language Docsy and the whole '
            'app speak in.',
      ),
      TourStep(
        targetKey: _tourProfileKey,
        title: 'Your account',
        body: 'Your profile, health details and settings live here — tap to '
            'open them whenever you need.',
      ),
    ];
  }

  @override
  void dispose() {
    BlushyShellTabs.requested.removeListener(_onTabRequested);
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _tabFade.dispose();
    super.dispose();
  }

  /// Replays anything logged while offline as soon as the app comes back.
  ///
  /// The queue was only drained when the dashboard was rebuilt, so a check-in
  /// made on a train could sit unsent until that screen happened to reload.
  /// Coming back to the foreground is the moment connectivity is most likely to
  /// have returned.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _flushPendingWrites();
  }

  /// Shows a tab something elsewhere asked for, then clears the request so the
  /// same index can be asked for again later.
  void _onTabRequested() {
    final index = BlushyShellTabs.requested.value;
    if (index == null || !mounted) return;
    BlushyShellTabs.requested.value = null;
    if (index < 0 || index >= _screens.length || index == _currentIndex) return;

    setState(() => _currentIndex = index);
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _tabFade.forward(from: 0);
    }
  }

  /// Fires once at the next local midnight, then reschedules itself.
  Timer? _midnightTimer;

  Future<void> _flushPendingWrites() async {
    // Resuming the next morning is the usual way a day turns over while the
    // app is installed, so this is checked before the flush rather than
    // waiting for a screen to notice.
    await DailyRollover.runIfNeeded();
    await OfflineEventQueue.instance.load();
    final result = await OfflineEventQueue.instance.flush();
    if (!mounted || !result.didAnything) return;

    // Anything derived from those writes is now stale.
    SiaDashboardService().syncAllDashboardsFromBackend(
      state: BlushyOSProvider.of(context),
    );
  }

  /// Switches to [index], with the same cross-tab sync and fade the bottom
  /// navigation uses. Shared so the nav and the system back button move
  /// between tabs identically.
  void _selectTab(int index) {
    if (_currentIndex != index) {
      final state = BlushyOSProvider.of(context);
      SiaDashboardService().syncAllDashboardsFromBackend(state: state);
      // Someone who asked for less motion gets the switch, not the fade.
      if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
        _tabFade.forward(from: 0);
      }
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Home keeps the wordmark; every other tab names itself instead, since the
    // wordmark is identical on all five and so says nothing about where you are.
    final t = AppLocalizations.of(context);

    // The first-period stages address the fourth tab as a "Companion" (a friend
    // to talk to) rather than a "Partner". Kept in one place so the header title
    // and the bar label cannot disagree.
    final String stageNorm = (BlushyOSProvider.of(context)
                .personalContext
                .lifeStage ??
            '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]'), '');
    final String? partnerLabel =
        (stageNorm == 'firstperiodstarted' || stageNorm == 'firstperiodnotstarted')
            ? 'Companion'
            : null;

    final scaffold = Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: BlushyHeader(
        title: _currentIndex == 0
            ? null
            : BlushyBottomNavigation.labelsFor(t, partnerLabel: partnerLabel)[_currentIndex],
        languageKey: _tourLanguageKey,
        profileKey: _tourProfileKey,
      ),
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _tabFade, curve: Curves.easeOut),
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: BlushyBottomNavigation(
        itemKeys: _navKeys,
        currentIndex: _currentIndex,
        onTap: _selectTab,
        partnerLabel: partnerLabel,
      ),
    );

    // Back from any tab other than Home returns to Home rather than closing the
    // app; on Home the default pop stands (Android exits at the root). Wraps the
    // tour overlay too, so back behaves the same while it is showing.
    Widget withBack(Widget child) => PopScope(
          canPop: _currentIndex == BlushyShellTabs.home,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_currentIndex != BlushyShellTabs.home) {
              _selectTab(BlushyShellTabs.home);
            }
          },
          child: child,
        );

    if (!_showTour) return withBack(scaffold);

    // Stacked over the whole Scaffold rather than inside its body: the tabs
    // being pointed at live in `bottomNavigationBar`, which the body does not
    // cover.
    return withBack(Stack(
      children: [
        scaffold,
        ProductTour(
          steps: _tourSteps(t, partnerLabel),
          skipLabel: t.tourSkip,
          nextLabel: t.tourNext,
          doneLabel: t.tourDone,
          onFinished: () {
            if (mounted) setState(() => _showTour = false);
          },
        ),
      ],
    ));
  }
}
