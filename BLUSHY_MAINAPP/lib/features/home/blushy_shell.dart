import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../shared/bottom_navigation.dart';
import '../../shared/header.dart';
import '../community/community_screen.dart';
import '../m_studio/m_studio_screen.dart';
import '../sia/sia_screen.dart';
import '../partner/partner_screen.dart';
import '../../core/state.dart';
import '../../services/offline_event_queue.dart';
import '../../services/sia_dashboard_service.dart';
import 'home_screen.dart';

class BlushyOSShell extends StatefulWidget {
  const BlushyOSShell({super.key});

  @override
  State<BlushyOSShell> createState() => _BlushyOSShellState();
}

class _BlushyOSShellState extends State<BlushyOSShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  // Order matches BlushyBottomNavigation, with Dr. Docsy in the middle slot.
  final List<Widget> _screens = [
    const BlushyHomeScreen(),
    const BlushyCommunityScreen(),
    const BlushySiaScreen(),
    const BlushyMStudioScreen(),
    const BlushyPartnerScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  Future<void> _flushPendingWrites() async {
    await OfflineEventQueue.instance.load();
    final result = await OfflineEventQueue.instance.flush();
    if (!mounted || !result.didAnything) return;

    // Anything derived from those writes is now stale.
    SiaDashboardService().syncAllDashboardsFromBackend(
      state: BlushyOSProvider.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: const BlushyHeader(),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BlushyBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (_currentIndex != index) {
            final state = BlushyOSProvider.of(context);
            SiaDashboardService().syncAllDashboardsFromBackend(state: state);
          }
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
