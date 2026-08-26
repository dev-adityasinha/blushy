import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/state.dart';

class JourneyScreen extends StatelessWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Header
          Text(
            'Your Journey',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 34,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The evolving ledger of your cycle, biometrics, and physical reflections.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),

          // Cycle Wheel / Visual Timeline representation
          Text(
            'Cycle Intelligence Timeline',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: BlushyColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: BlushyColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CURRENT PHASE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: BlushyColors.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'Day ${state.cycleDay} of 28',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: BlushyColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  state.cyclePhase,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Elegant Linear Timeline representation
                Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: BlushyColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: state.cycleDay / 28.0,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: BlushyColors.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Menstrual', style: TextStyle(fontSize: 10, color: BlushyColors.textLight)),
                    Text('Follicular', style: TextStyle(fontSize: 10, color: BlushyColors.textLight)),
                    Text('Ovulatory', style: TextStyle(fontSize: 10, color: BlushyColors.textLight)),
                    Text('Luteal', style: TextStyle(fontSize: 10, color: BlushyColors.textDark, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: BlushyColors.border, height: 32),
                Text(
                  state.cycleInsight,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Biometrics Ledger
          Text(
            'Biometrics & Ledger Summary',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  context,
                  'Sleep',
                  '${state.sleepHours}h',
                  state.sleepQuality,
                  BlushyColors.secondary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  context,
                  'Committed Tasks',
                  '${state.completedTasksCount}',
                  state.completedTasksCount > 0 ? 'Active' : 'Unfinished',
                  BlushyColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Timeline Log of Journal Entries & Completed Actions
          Text(
            'Recent Logs',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          if (state.journals.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30),
              alignment: Alignment.center,
              child: const Text(
                'No journals logged yet. Speak to Sia or write on the Today screen.',
                style: TextStyle(color: BlushyColors.textLight, fontSize: 13),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.journals.length,
              itemBuilder: (context, index) {
                final journal = state.journals[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: BlushyColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: BlushyColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: BlushyColors.background,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                journal.mood,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: BlushyColors.textMuted,
                                ),
                              ),
                            ),
                            Text(
                              '${journal.timestamp.hour}:${journal.timestamp.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: BlushyColors.textLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '"${journal.content}"',
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: BlushyColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, String status, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BlushyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: BlushyColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 28,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: BlushyColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
