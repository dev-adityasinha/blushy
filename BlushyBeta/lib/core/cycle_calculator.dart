class CycleCalculation {
  final int cycleLength;
  final int periodDuration;
  final DateTime? lastPeriodStart;
  final int currentCycleDay; // 0 means "not logged"
  final String currentPhase; // 'Not Logged' when no data
  final int daysUntilNextPeriod;
  final DateTime? nextPeriodStart;
  final DateTime? fertileWindowStart;
  final DateTime? fertileWindowEnd;
  final DateTime? ovulationDay;
  final bool hasData; // true only when a real lastPeriodStart was provided

  CycleCalculation({
    required this.cycleLength,
    required this.periodDuration,
    required this.lastPeriodStart,
    required this.currentCycleDay,
    required this.currentPhase,
    required this.daysUntilNextPeriod,
    required this.nextPeriodStart,
    required this.fertileWindowStart,
    required this.fertileWindowEnd,
    required this.ovulationDay,
    required this.hasData,
  });

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String get formattedNextPeriodDate {
    if (nextPeriodStart == null) return 'Not Logged';
    return '${_months[nextPeriodStart!.month - 1]} ${nextPeriodStart!.day}';
  }

  String get formattedFertileWindow {
    if (fertileWindowStart == null || fertileWindowEnd == null) return 'Not Logged';
    return '${_months[fertileWindowStart!.month - 1]} ${fertileWindowStart!.day} - ${_months[fertileWindowEnd!.month - 1]} ${fertileWindowEnd!.day}';
  }

  /// Returns today's date in IST (UTC+5:30) so the cycle day changes at
  /// midnight IST regardless of the device/browser timezone.
  static DateTime _todayIST() {
    final nowUtc = DateTime.now().toUtc();
    final istOffset = const Duration(hours: 5, minutes: 30);
    final nowIST = nowUtc.add(istOffset);
    return DateTime(nowIST.year, nowIST.month, nowIST.day);
  }

  static CycleCalculation compute({
    DateTime? lastPeriodStart,
    int? cycleLength,
    int? periodDuration,
  }) {
    final today = _todayIST();

    final length = (cycleLength != null && cycleLength >= 18 && cycleLength <= 60) ? cycleLength : 28;
    final duration = (periodDuration != null && periodDuration >= 1 && periodDuration <= 12) ? periodDuration : 5;

    // ─── NO PERIOD DATA: return "Not Logged" with zero values ───
    if (lastPeriodStart == null) {
      return CycleCalculation(
        cycleLength: length,
        periodDuration: duration,
        lastPeriodStart: null,
        currentCycleDay: 0,
        currentPhase: 'Not Logged',
        daysUntilNextPeriod: 0,
        nextPeriodStart: null,
        fertileWindowStart: null,
        fertileWindowEnd: null,
        ovulationDay: null,
        hasData: false,
      );
    }

    // ─── REAL CALCULATION (only when we have actual user data) ───
    final startDateOnly = DateTime(lastPeriodStart.year, lastPeriodStart.month, lastPeriodStart.day);
    final daysElapsed = today.difference(startDateOnly).inDays;
    final safeElapsed = daysElapsed < 0 ? 0 : daysElapsed;

    final currentCycleDay = (safeElapsed % length) + 1;
    final cycleIndex = safeElapsed ~/ length;
    final currentCycleStartDate = startDateOnly.add(Duration(days: cycleIndex * length));
    final nextPeriodStart = currentCycleStartDate.add(Duration(days: length));
    final daysUntilNextPeriod = nextPeriodStart.difference(today).inDays;

    final estimatedOvulationDayNum = (length / 2).round();
    final ovulationDay = currentCycleStartDate.add(Duration(days: estimatedOvulationDayNum - 1));
    final fertileWindowStart = ovulationDay.subtract(const Duration(days: 4));
    final fertileWindowEnd = ovulationDay.add(const Duration(days: 1));

    String phase;
    if (currentCycleDay <= duration) {
      phase = 'Menstrual Phase';
    } else if (currentCycleDay < estimatedOvulationDayNum - 1) {
      phase = 'Follicular Phase';
    } else if (currentCycleDay >= estimatedOvulationDayNum - 1 && currentCycleDay <= estimatedOvulationDayNum + 1) {
      phase = 'Ovulation Phase';
    } else {
      phase = 'Luteal Phase';
    }

    return CycleCalculation(
      cycleLength: length,
      periodDuration: duration,
      lastPeriodStart: currentCycleStartDate,
      currentCycleDay: currentCycleDay,
      currentPhase: phase,
      daysUntilNextPeriod: daysUntilNextPeriod,
      nextPeriodStart: nextPeriodStart,
      fertileWindowStart: fertileWindowStart,
      fertileWindowEnd: fertileWindowEnd,
      ovulationDay: ovulationDay,
      hasData: true,
    );
  }
}
