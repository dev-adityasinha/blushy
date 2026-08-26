import sys

with open('/Users/yashasnaidu/Blushy/blushy/lib/screens/dashboard_screen.dart', 'a') as f:
    f.write('''

// ============== REACT UI COMPONENTS ==============

class _ReactHeroGreeting extends StatelessWidget {
  const _ReactHeroGreeting({
    required this.userName,
    required this.userCode,
    required this.isMan,
  });

  final String userName;
  final String userCode;
  final bool isMan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good morning, $userName 🌸',
          style: TextStyle(
            fontSize: 14,
            color: (isMan ? AppTheme.menForeground : AppTheme.womenForeground).withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'User code: $userCode',
          style: TextStyle(
            fontSize: 12,
            color: (isMan ? AppTheme.menForeground : AppTheme.womenForeground).withOpacity(0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isMan ? 'Stay in sync with her today ✨' : "You're glowing today ✨",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ReactCycleWheelCard extends StatelessWidget {
  const _ReactCycleWheelCard({
    required this.cycleStartDate,
    required this.prediction,
    required this.isMan,
  });

  final DateTime? cycleStartDate;
  final _CyclePrediction? prediction;
  final bool isMan;

  @override
  Widget build(BuildContext context) {
    final int cycleDay = prediction?.currentCycleDay ?? 14;
    final int nextPeriodDays = prediction?.nextPeriodStart.difference(DateTime.now()).inDays ?? 14;
    final String phase = _getCyclePhase(cycleDay);
    final double progress = cycleDay / 28.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: SoftGradients.cardShadow(isMan),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isMan ? "Her cycle wheel" : "Cycle wheel",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 170,
                    height: 170,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      strokeWidth: 14,
                      backgroundColor: isMan ? AppTheme.menMuted : AppTheme.womenMuted,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isMan ? AppTheme.menPrimary : AppTheme.womenPrimary,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$cycleDay',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: isMan ? AppTheme.menPrimary : AppTheme.womenPrimary,
                        ),
                      ),
                      Text(
                        isMan ? "Her cycle day" : "Day of cycle",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phase,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isMan ? AppTheme.menPrimary : AppTheme.womenPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isMan ? "Her next period in " : "Next period in ",
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Text(
            '${nextPeriodDays > 0 ? nextPeriodDays : 0} days',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getCyclePhase(int cycleDay) {
    if (cycleDay <= 5) return "Period phase";
    if (cycleDay <= 13) return "Follicular phase";
    if (cycleDay <= 16) return "Ovulation phase";
    if (cycleDay <= 28) return "Luteal phase";
    return "Cycle phase";
  }
}

class _ReactMoodLoggerCard extends StatefulWidget {
  const _ReactMoodLoggerCard({
    required this.entry,
    required this.onSave,
    required this.isMan,
  });

  final DailyMoodEntry? entry;
  final Future<void> Function({
    required String mood,
    required String energyLevel,
    required String stressLevel,
    required String notes,
  }) onSave;
  final bool isMan;

  @override
  State<_ReactMoodLoggerCard> createState() => _ReactMoodLoggerCardState();
}

class _ReactMoodLoggerCardState extends State<_ReactMoodLoggerCard> {
  String? _selectedMood;
  
  final List<Map<String, String>> _moods = [
    {"emoji": "😊", "label": "Happy", "response": "Your happy energy is beautiful today. Keep riding it."},
    {"emoji": "😌", "label": "Calm", "response": "Steady and calm is powerful. Protect this pace."},
    {"emoji": "😢", "label": "Sad", "response": "Soft day noted. Be extra gentle with yourself."},
    {"emoji": "😣", "label": "Cramps", "response": "We hear you. Warmth, hydration, and slow movement can help."},
    {"emoji": "😴", "label": "Tired", "response": "Low battery day. Prioritize rest and easy meals."},
    {"emoji": "🥰", "label": "Loved", "response": "Heart-full day. Hold onto this feeling."},
  ];

  @override
  void initState() {
    super.initState();
    // Try to map existing entry to one of these labels
    if (widget.entry != null && widget.entry!.mood.isNotEmpty) {
      final m = widget.entry!.mood.toLowerCase();
      if (m == 'great') _selectedMood = 'Happy';
      else if (m == 'okay') _selectedMood = 'Calm';
      else if (m == 'low') _selectedMood = 'Sad';
      else _selectedMood = 'Calm';
    }
  }

  void _handleMoodSelect(String label) {
    setState(() {
      _selectedMood = label;
    });
    // Map to backend values
    String backendMood = 'okay';
    if (label == 'Happy' || label == 'Loved') backendMood = 'great';
    else if (label == 'Sad' || label == 'Cramps') backendMood = 'low';
    else if (label == 'Tired') backendMood = 'low';
    
    widget.onSave(
      mood: backendMood,
      energyLevel: 'medium',
      stressLevel: 'medium',
      notes: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeMood = _selectedMood != null ? _moods.firstWhere((m) => m['label'] == _selectedMood, orElse: () => _moods[0]) : null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: SoftGradients.cardShadow(widget.isMan),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "How are you feeling? 💗",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            "Tap a mood - we'll remember.${activeMood != null ? " Today: ${activeMood['emoji']} ${activeMood['label']}" : ""}",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: _moods.map((m) {
              final isSelected = _selectedMood == m['label'];
              return GestureDetector(
                onTap: () => _handleMoodSelect(m['label']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 80,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? (widget.isMan ? AppTheme.menPrimary : AppTheme.womenPrimary).withOpacity(0.15)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected 
                        ? Border.all(color: (widget.isMan ? AppTheme.menPrimary : AppTheme.womenPrimary).withOpacity(0.4), width: 2)
                        : null,
                    boxShadow: isSelected ? SoftGradients.softShadow(widget.isMan) : SoftGradients.cardShadow(widget.isMan),
                  ),
                  child: Column(
                    children: [
                      Text(m['emoji']!, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(
                        m['label']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected 
                              ? (widget.isMan ? AppTheme.menPrimary : AppTheme.womenPrimary)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (activeMood != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (widget.isMan ? AppTheme.menPrimary : AppTheme.womenPrimary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: (widget.isMan ? AppTheme.menPrimary : AppTheme.womenPrimary).withOpacity(0.2)),
              ),
              child: Text(
                activeMood['response']!,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            "Today's care tips",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TipCard(icon: '💧', text: 'Drink 2L water', isMan: widget.isMan),
                const SizedBox(width: 12),
                _TipCard(icon: '🧘‍♀️', text: '10 min stretching', isMan: widget.isMan),
                const SizedBox(width: 12),
                _TipCard(icon: '🌙', text: 'Sleep before 11pm', isMan: widget.isMan),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.icon, required this.text, required this.isMan});
  final String icon;
  final String text;
  final bool isMan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: SoftGradients.cardShadow(isMan),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ReactStatCardsGrid extends StatelessWidget {
  const _ReactStatCardsGrid({required this.prediction, required this.isMan});
  final _CyclePrediction? prediction;
  final bool isMan;

  @override
  Widget build(BuildContext context) {
    final nextPeriodDays = prediction?.nextPeriodStart.difference(DateTime.now()).inDays ?? 14;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _StatCard(icon: Icons.water_drop, label: "Period in", value: "${nextPeriodDays > 0 ? nextPeriodDays : 0}d", gradient: SoftGradients.cardPink),
        _StatCard(icon: Icons.bedtime, label: "Sleep avg", value: "7.5h", gradient: SoftGradients.cardLavender),
        _StatCard(icon: Icons.monitor_heart, label: "Energy", value: "High", gradient: SoftGradients.cardPeach),
        _StatCard(icon: Icons.emoji_emotions, label: "Mood streak", value: "5 days", gradient: SoftGradients.cardPink),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.gradient});
  final IconData icon;
  final String label;
  final String value;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.black54, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _ReactAiGreetingCard extends StatelessWidget {
  const _ReactAiGreetingCard({required this.onTap, required this.isMan});
  final VoidCallback onTap;
  final bool isMan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: SoftGradients.cardShadow(isMan),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: isMan ? AppTheme.menPrimary : AppTheme.womenPrimary, size: 16),
                    const SizedBox(width: 8),
                    const Text("Daily AI greeting", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isMan 
                    ? '"Hey support, her energy might be low today. A simple check-in goes a long way 💗"'
                    : '"Hey love, your body is in its ovulation phase — energy will be naturally high. Honor it gently 💗"',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.favorite),
            label: const Text("Chat with Blushy"),
            style: ElevatedButton.styleFrom(
              backgroundColor: isMan ? AppTheme.menPrimary : AppTheme.womenPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactQuickLinksRow extends StatelessWidget {
  const _ReactQuickLinksRow({
    required this.onOpenCalendar,
    required this.onLogSleep,
    required this.onNutrition,
    required this.isMan,
  });
  final VoidCallback onOpenCalendar;
  final VoidCallback onLogSleep;
  final VoidCallback onNutrition;
  final bool isMan;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 500 ? 3 : 1;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3,
          children: [
            _QuickLink(icon: Icons.calendar_today, label: "Open calendar", onTap: onOpenCalendar, isMan: isMan),
            _QuickLink(icon: Icons.bedtime, label: "Log sleep", onTap: onLogSleep, isMan: isMan),
            _QuickLink(icon: Icons.trending_up, label: "Today's nutrition", onTap: onNutrition, isMan: isMan),
          ],
        );
      }
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({required this.icon, required this.label, required this.onTap, required this.isMan});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isMan;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: SoftGradients.cardShadow(isMan),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: isMan ? SoftGradients.primaryMen : SoftGradients.primaryWomen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
''')

