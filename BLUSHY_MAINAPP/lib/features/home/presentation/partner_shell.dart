import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../shared/header.dart';
import '../../../core/theme.dart' hide BlushyColors;
import '../../partner/presentation/partner_home.dart';
import '../../partner/presentation/partner_community.dart';
import '../../partner/presentation/partner_learn.dart';
import '../../partner/partner_screen.dart';

class PartnerShell extends StatefulWidget {
  const PartnerShell({super.key});

  @override
  State<PartnerShell> createState() => _PartnerShellState();
}

class _PartnerShellState extends State<PartnerShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  /// Fades the incoming tab in. Over the IndexedStack rather than swapping it,
  /// so each tab keeps its State.
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  @override
  void dispose() {
    _tabFade.dispose();
    super.dispose();
  }

  /// The four destination names, in tab order.
  ///
  /// Still English: this bar was never localised, and there is no `navLearn`
  /// string to reach for. The header reads from the same list so the two
  /// cannot disagree, and translating them is one edit here.
  static const List<String> _labels = <String>[
    'Home',
    'Community',
    'Learn',
    'Partner',
  ];

  final List<Widget> _screens = [
    const PartnerHomeScreen(),
    const PartnerCommunityScreen(),
    const PartnerLearnScreen(),
    const BlushyPartnerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: BlushyHeader(
        title: _currentIndex == 0 ? null : _labels[_currentIndex],
      ),
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _tabFade, curve: Curves.easeOut),
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
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
          currentIndex: _currentIndex,
          onTap: (index) {
            if (_currentIndex != index &&
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
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home_filled),
              label: _labels[0],
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.people_outline_rounded),
              activeIcon: const Icon(Icons.people_rounded),
              label: _labels[1],
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.auto_stories_outlined),
              activeIcon: const Icon(Icons.auto_stories_rounded),
              label: _labels[2],
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.favorite_border_rounded),
              activeIcon: const Icon(Icons.favorite_rounded),
              label: _labels[3],
            ),
          ],
        ),
       ),
      ),
    );
  }
}
