import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/state.dart';
import 'today.dart';
import 'journey.dart';
import 'explore.dart';
import 'sia.dart';

class BlushyOSShell extends StatelessWidget {
  const BlushyOSShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    
    final List<Widget> screens = [
      const TodayBriefingScreen(),
      const JourneyScreen(),
      const ExploreScreen(),
      const SiaCompanionScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: BlushyColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0, top: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'blushy.',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 26,
                  letterSpacing: -1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, py: 4),
                decoration: BoxDecoration(
                  color: BlushyColors.lutealSoft,
                  border: Border.all(color: BlushyColors.secondary.withOpacity(0.3), width: 1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: BlushyColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sia Online',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 10,
                        color: BlushyColors.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: state.currentViewIndex,
        children: screens,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 64,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: BlushyColors.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: BlushyColors.border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: BlushyColors.textDark.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(context, state, 0, 'Today'),
              _buildNavItem(context, state, 1, 'Journey'),
              _buildNavItem(context, state, 2, 'Explore'),
              _buildNavItem(context, state, 3, 'Sia'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, BlushyOSState state, int index, String label) {
    final isActive = state.currentViewIndex == index;
    return GestureDetector(
      onTap: () => state.setViewIndex(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? BlushyColors.primary : BlushyColors.textMuted,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 4 : 0,
            height: 4,
            decoration: const BoxDecoration(
              color: BlushyColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
