/// Canonical Cycle Calculation Model & Offline Fallback Display Parser
///
/// RESTRICTION: The backend `periodPredictionService.js` is the Single Source of Truth (SSOT).
/// This client-side helper is retained strictly for emergency offline presentation.
/// The offline fallback must NEVER create confirmed records, send predictions to Sia as
/// authoritative, or override freshly received backend predictions.
class CycleCalculation {
  final int cycleLength;
  final int periodDuration;
  final DateTime? lastPeriodStart;
  final int currentCycleDay; // 0 or null-equivalent means "not logged"
  final String currentPhase; // 'Not Logged' when no data
  final int? daysUntilNextPeriod;
  final DateTime? nextPeriodStart;
  final DateTime? fertileWindowStart;
  final DateTime? fertileWindowEnd;
  final DateTime? ovulationDay;
  final bool isOverdue;
  final int daysOverdue;
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
    this.isOverdue = false,
    this.daysOverdue = 0,
    required this.hasData,
  });

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String get formattedNextPeriodDate {
    if (isOverdue) return 'Overdue / Awaiting Period';
    if (nextPeriodStart == null) return 'Not Logged';
    return '${_months[nextPeriodStart!.month - 1]} ${nextPeriodStart!.day}';
  }

  String get formattedFertileWindow {
    if (isOverdue || fertileWindowStart == null || fertileWindowEnd == null) return 'Not Logged';
    return '${_months[fertileWindowStart!.month - 1]} ${fertileWindowStart!.day} - ${_months[fertileWindowEnd!.month - 1]} ${fertileWindowEnd!.day}';
  }

  /// Returns today's date in local calendar time for offline presentation
  static DateTime _todayLocal() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static CycleCalculation compute({
    DateTime? lastPeriodStart,
    int? cycleLength,
    int? periodDuration,
  }) {
    final today = _todayLocal();

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
        daysUntilNextPeriod: null,
        nextPeriodStart: null,
        fertileWindowStart: null,
        fertileWindowEnd: null,
        ovulationDay: null,
        isOverdue: false,
        daysOverdue: 0,
        hasData: false,
      );
    }

    // ─── REAL CALCULATION (strictly anchored to confirmed lastPeriodStart) ───
    final startDateOnly = DateTime(lastPeriodStart.year, lastPeriodStart.month, lastPeriodStart.day);
    final daysElapsed = today.difference(startDateOnly).inDays;
    final safeElapsed = daysElapsed < 0 ? 0 : daysElapsed;

    // Option A (Day 1 Standard convention: Day 1 on start date)
    final currentCycleDay = safeElapsed + 1;
    final isOverdue = currentCycleDay > length;
    final daysOverdue = isOverdue ? currentCycleDay - length : 0;

    final nextPeriodStart = startDateOnly.add(Duration(days: length));
    final daysUntilNextPeriod = isOverdue ? null : nextPeriodStart.difference(today).inDays;

    final ovulationDay = nextPeriodStart.subtract(const Duration(days: 14));
    final fertileWindowStart = ovulationDay.subtract(const Duration(days: 5));
    final fertileWindowEnd = ovulationDay.add(const Duration(days: 1));

    String phase;
    if (isOverdue) {
      phase = 'Late / Overdue Cycle (+$daysOverdue days)';
    } else if (currentCycleDay <= duration) {
      phase = 'Menstrual Phase';
    } else if (today.isAfter(fertileWindowStart.subtract(const Duration(days: 1))) &&
               today.isBefore(fertileWindowEnd.add(const Duration(days: 1)))) {
      final isOvulation = today.year == ovulationDay.year &&
                          today.month == ovulationDay.month &&
                          today.day == ovulationDay.day;
      phase = isOvulation ? 'Estimated Ovulation Day' : 'Approximate Fertile Window';
    } else if (currentCycleDay > duration && today.isBefore(fertileWindowStart)) {
      phase = 'Follicular Phase';
    } else {
      phase = 'Luteal Phase';
    }

    return CycleCalculation(
      cycleLength: length,
      periodDuration: duration,
      lastPeriodStart: startDateOnly,
      currentCycleDay: currentCycleDay,
      currentPhase: phase,
      daysUntilNextPeriod: daysUntilNextPeriod,
      nextPeriodStart: isOverdue ? null : nextPeriodStart,
      fertileWindowStart: isOverdue ? null : fertileWindowStart,
      fertileWindowEnd: isOverdue ? null : fertileWindowEnd,
      ovulationDay: isOverdue ? null : ovulationDay,
      isOverdue: isOverdue,
      daysOverdue: daysOverdue,
      hasData: true,
    );
  }
}
