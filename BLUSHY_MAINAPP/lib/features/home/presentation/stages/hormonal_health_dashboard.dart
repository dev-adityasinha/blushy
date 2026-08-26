import 'package:flutter/material.dart';
import 'everyday_wellness_dashboard.dart';

class HormonalHealthDashboard extends StatelessWidget {
  const HormonalHealthDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const EverydayWellnessDashboard(stageKey: 'hormonalHealth');
  }
}