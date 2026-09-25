import 'package:flutter/material.dart';
import '../../partner/presentation/partner_sia.dart';
import '../../../theme/colors.dart';
import '../../../shared/header.dart';
import '../../../core/theme.dart' hide BlushyColors;
import '../../partner/presentation/partner_home.dart';
import '../../partner/presentation/partner_learn.dart';
import '../../partner/partner_screen.dart';
import '../../../services/api_partner_service.dart';
import '../../../services/api_blushy_service.dart';
import '../../../models/blushy_models.dart';

class PartnerShell extends StatefulWidget {
  const PartnerShell({super.key});

  @override
  State<PartnerShell> createState() => _PartnerShellState();
}

class _PartnerShellState extends State<PartnerShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  /// Whether the romantic couple surface (the "Partner" tab: love notes, date
  /// planner, couple games, flirty nudges) is hidden for this companion.
  ///
  /// It is hidden only when the connection is *explicitly* a non-romantic
  /// relationship type (family / friend / co-parent). A legacy or not-yet-typed
  /// connection has no category and keeps the tab, so existing romantic partners
  /// are never regressed while a mother or a friend never sees couple features.
  bool _hideCoupleTab = false;

  final ApiPartnerService _partnerService = ApiPartnerService();

  /// Fades the incoming tab in. Over the IndexedStack rather than swapping it,
  /// so each tab keeps its State.
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    _resolveCapabilities();
  }

  /// Reads the companion's active connection and its relationship-type
  /// capabilities from the server, then hides the couple tab for a non-romantic
  /// companion. Fails open (tab shown) on any error, since the couple surface's
  /// own data is still permission-gated server-side.
  Future<void> _resolveCapabilities() async {
    try {
      final connections = await _partnerService.getConnections();
      final active = connections.firstWhere(
        (c) => c['status'] == 'active',
        orElse: () => <String, dynamic>{},
      );
      if (active.isEmpty) return;
      final connId = (active['connectionId'] ?? active['_id'] ?? '').toString();
      if (connId.isEmpty) return;

      final result = await PartnerApi.home(connId);
      if (!mounted || !result.isReady) return;
      final PartnerHomeModel? model = result.data;
      if (model == null) return;

      // Hide only when we positively know the relationship is non-romantic.
      final hide = model.relationshipCategory != null && !model.allowsCoupleFeatures;
      if (hide != _hideCoupleTab) {
        setState(() {
          _hideCoupleTab = hide;
          if (_currentIndex >= _labels.length) _currentIndex = 0;
        });
      }
    } catch (_) {
      // Fail open: keep the current tab set.
    }
  }

  @override
  void dispose() {
    _tabFade.dispose();
    super.dispose();
  }

  /// Destination names, in tab order. The couple ("Partner") destination drops
  /// out for a non-romantic companion.
  ///
  /// Still English: this bar was never localised, and there is no `navLearn`
  /// string to reach for. The header reads from the same list so the two cannot
  /// disagree.
  List<String> get _labels => <String>[
        'Home',
        // Docsy: the thing that explains what she is going through.
        'Docsy',
        'Learn',
        if (!_hideCoupleTab) 'Partner',
      ];

  List<Widget> get _screens => <Widget>[
        const PartnerHomeScreen(),
        const PartnerSiaScreen(),
        const PartnerLearnScreen(),
        if (!_hideCoupleTab) const BlushyPartnerScreen(),
      ];

  List<BottomNavigationBarItem> get _navItems => <BottomNavigationBarItem>[
        // The partner nav bar was never localised (see _labels); labels English.
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home_filled),
          label: 'Home', // i18n-ignore
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.auto_awesome_outlined),
          activeIcon: Icon(Icons.auto_awesome_rounded),
          label: 'Docsy', // i18n-ignore
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.auto_stories_outlined),
          activeIcon: Icon(Icons.auto_stories_rounded),
          label: 'Learn', // i18n-ignore
        ),
        if (!_hideCoupleTab)
          const BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border_rounded),
            activeIcon: Icon(Icons.favorite_rounded),
            label: 'Partner', // i18n-ignore
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final labels = _labels;
    final screens = _screens;
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: BlushyHeader(
        title: safeIndex == 0 ? null : labels[safeIndex],
      ),
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _tabFade, curve: Curves.easeOut),
        child: IndexedStack(
          index: safeIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: BlushyColors.border.withValues(alpha: 0.5), width: 1),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: BlushyTheme.getPagePadding(context),
            vertical: 4.0,
          ),
          child: BottomNavigationBar(
            currentIndex: safeIndex,
            onTap: (index) {
              if (safeIndex != index &&
                  !(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
                _tabFade.forward(from: 0);
              }
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: BlushyColors.primary,
            unselectedItemColor: BlushyColors.secondaryText,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
            elevation: 0,
            items: _navItems,
          ),
        ),
      ),
    );
  }
}
