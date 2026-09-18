import '../../../../models/blushy_models.dart';
import '../../../../services/api_contract_client.dart';

/// Turns the cycle read into the map the everyday-wellness "Today's Cycle" card
/// renders. Extracted from the 17,800-line dashboard so this state machine can
/// be tested on its own.
///
/// It carries a documented bug fix: a refresh must not blank a card that
/// already has an answer. The loading branch hands back the last known cycle
/// instead of "Not Logged", so a cold backend no longer flashes "nothing
/// logged" over a period that is sitting in the database the whole time.
class EverydayCycleCard {
  const EverydayCycleCard._();

  /// [formatDayMonth] is injected so the card's date formatting stays identical
  /// to the screen's own helper.
  static Map<String, dynamic> resolve({
    required ApiResult<CycleState> cycleResult,
    CycleState? lastKnown,
    required String Function(String?) formatDayMonth,
  }) {
    Map<String, dynamic> unavailable(
      String state,
      String dayText,
      String subtitle,
    ) => {
      'state': state,
      'isLogged': false,
      'cycleDay': null,
      'cycleDayText': dayText,
      'subtitle': subtitle,
      'ovulationText': 'Not available',
      'fertileWindow': 'Not available',
      'expectedPeriod': 'Not available',
      'recTestDay': 'Not available',
      'phaseName': 'Not Logged',
    };

    final cycle = cycleResult.data ?? lastKnown;

    // Branches that do not use cycle language at all (menopause, pregnancy).
    if (cycle != null && !cycle.cycleTrackingAvailable) {
      return unavailable(
        'restricted',
        'Cycle tracking paused',
        cycle.restrictedMessage ??
            'Your current stage does not use cycle tracking.',
      );
    }

    switch (cycleResult.state) {
      case ApiState.loading:
        // A refresh must not blank a card that already has an answer;
        // lastKnown is kept for exactly this.
        if (cycle == null) {
          return unavailable('loading', 'Loading…', 'Fetching your cycle.');
        }
        break;

      case ApiState.empty:
        // No period data at all. Never show a simulated cycle day here.
        return unavailable(
          'empty',
          'Not Logged',
          'No period logged yet. Tap to set your last period start date.',
        );

      case ApiState.offline:
      case ApiState.error:
        if (cycle == null) {
          return unavailable(
            cycleResult.state == ApiState.offline ? 'offline' : 'error',
            'Cycle Day unavailable',
            cycleResult.state == ApiState.offline
                ? 'You are offline. Your cycle will refresh when you reconnect.'
                : 'Could not load your cycle. Pull to refresh.',
          );
        }
        break;

      default:
        break;
    }

    if (cycle == null || cycle.currentCycleDay == null) {
      return unavailable(
        'empty',
        'Not Logged',
        'No period logged yet. Tap to set your last period start date.',
      );
    }

    final int cycleDay = cycle.currentCycleDay!;
    final bool predictionsAvailable = cycle.hasPrediction;

    // Predictions are withheld until there is enough history to give them
    // honestly; the card shows the reason instead of a fabricated date.
    const notEnough = 'Not enough data yet';

    final bool hasOvulation = cycle.estimatedOvulationDate != null;
    final String ovulationText = hasOvulation
        ? formatDayMonth(cycle.estimatedOvulationDate)
        : notEnough;
    final String expectedPeriod = predictionsAvailable
        ? formatDayMonth(cycle.nextPeriodStartDate)
        : notEnough;
    final String fertileWindow =
        (cycle.fertileWindowStart != null && cycle.fertileWindowEnd != null)
        ? '${formatDayMonth(cycle.fertileWindowStart)} - ${formatDayMonth(cycle.fertileWindowEnd)}'
        : notEnough;

    final nextPeriod = cycle.nextPeriodStartDate == null
        ? null
        : DateTime.tryParse(cycle.nextPeriodStartDate!);
    final String recTestDay = nextPeriod == null
        ? notEnough
        : formatDayMonth(
            nextPeriod.add(const Duration(days: 3)).toIso8601String(),
          );

    // A late period is surfaced as late, not folded into a new cycle.
    final String subtitle;
    if (cycle.isOverdue) {
      subtitle =
          cycle.lateNotice ??
          'Your period is ${cycle.daysOverdue ?? 0} day(s) later than your logged pattern suggests.';
    } else if (hasOvulation) {
      subtitle = 'Expected Ovulation: $ovulationText';
    } else {
      subtitle =
          cycle.sufficiencyMessage ??
          'Keep logging to build your cycle picture.';
    }

    return {
      'state': cycleResult.state == ApiState.insufficientData
          ? 'insufficient_data'
          : 'ready',
      'isLogged': true,
      'cycleDay': cycleDay,
      'cycleDayText': cycle.isOverdue
          ? 'Day $cycleDay · ${cycle.daysOverdue ?? 0} days late'
          : 'Cycle Day $cycleDay',
      'subtitle': subtitle,
      'ovulationText': ovulationText,
      'fertileWindow': fertileWindow,
      'expectedPeriod': expectedPeriod,
      'recTestDay': recTestDay,
      'phaseName': cycle.phase ?? 'Not Logged',
      // Provenance, so the card can show which calculation produced the number.
      'calculationVersion': cycle.calculationVersion,
      'confidenceLevel': cycle.confidenceLevel,
      'isOverdue': cycle.isOverdue,
      'disclaimer': cycle.disclaimer,
    };
  }
}
