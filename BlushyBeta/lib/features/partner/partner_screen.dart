import 'package:flutter/material.dart';
import '../../shared/coming_soon_screen.dart';

class BlushyPartnerScreen extends StatelessWidget {
  const BlushyPartnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Partner',
      icon: Icons.favorite_outline_rounded,
    );
  }
}
