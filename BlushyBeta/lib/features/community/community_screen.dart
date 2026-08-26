import 'package:flutter/material.dart';
import '../../shared/coming_soon_screen.dart';

class BlushyCommunityScreen extends StatelessWidget {
  const BlushyCommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Community',
      icon: Icons.people_outline_rounded,
    );
  }
}
