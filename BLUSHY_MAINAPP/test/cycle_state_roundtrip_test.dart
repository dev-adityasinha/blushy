import 'dart:convert';

import 'package:blushy_life_app/models/blushy_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The stored cycle has to come back as the cycle that was stored.
///
/// `_lastKnownCycle` lived only in memory, so it was null on every launch and
/// the card opened on a placeholder while the request went out -- for someone
/// who has logged periods for months. It is now written to storage after each
/// successful fetch and read back before the first build.
///
/// That only helps if the round trip is faithful. `toJson` deliberately emits
/// the nested server shape (`currentCycle`, `prediction`, `predictionRange`,
/// `dataSufficiency`) so the existing `fromJson` restores it; a field added to
/// one and forgotten in the other would come back null, and the card would
/// quietly show less than it did before.
void main() {
  const full = CycleState(
    lifeStage: 'livingWithMyCycle',
    cycleTrackingAvailable: true,
    hasData: true,
    trackingState: 'tracking',
    currentCycleDay: 4,
    phase: 'Menstrual',
    cycleStartDate: '2026-08-30',
    isCurrentPeriod: true,
    isOverdue: false,
    daysOverdue: 0,
    nextPeriodStartDate: '2026-09-27',
    predictionEarliest: '2026-09-25',
    predictionLatest: '2026-09-29',
    daysUntilNextPeriod: 25,
    estimatedOvulationDate: '2026-09-13',
    fertileWindowStart: '2026-09-08',
    fertileWindowEnd: '2026-09-14',
    confidenceLevel: 'medium',
    sufficiencyLabel: 'Getting there',
    sufficiencyMessage: 'A few more cycles will sharpen this.',
    calculationVersion: 'v2',
    disclaimer: 'Estimates, not medical advice.',
    lateNotice: null,
    restrictedReason: null,
    restrictedMessage: null,
  );

  test('every field survives a trip through storage', () {
    // Through a real encode/decode, since that is what storage does to it --
    // an object that only round-trips in memory can still fail as JSON.
    final restored = CycleState.fromJson(jsonDecode(jsonEncode(full.toJson())));

    expect(restored.lifeStage, full.lifeStage);
    expect(restored.cycleTrackingAvailable, full.cycleTrackingAvailable);
    expect(restored.hasData, full.hasData);
    expect(restored.trackingState, full.trackingState);
    expect(restored.currentCycleDay, full.currentCycleDay);
    expect(restored.phase, full.phase);
    expect(restored.cycleStartDate, full.cycleStartDate);
    expect(restored.isCurrentPeriod, full.isCurrentPeriod);
    expect(restored.isOverdue, full.isOverdue);
    expect(restored.daysOverdue, full.daysOverdue);
    expect(restored.nextPeriodStartDate, full.nextPeriodStartDate);
    expect(restored.predictionEarliest, full.predictionEarliest);
    expect(restored.predictionLatest, full.predictionLatest);
    expect(restored.daysUntilNextPeriod, full.daysUntilNextPeriod);
    expect(restored.estimatedOvulationDate, full.estimatedOvulationDate);
    expect(restored.fertileWindowStart, full.fertileWindowStart);
    expect(restored.fertileWindowEnd, full.fertileWindowEnd);
    expect(restored.confidenceLevel, full.confidenceLevel);
    expect(restored.sufficiencyLabel, full.sufficiencyLabel);
    expect(restored.sufficiencyMessage, full.sufficiencyMessage);
    expect(restored.calculationVersion, full.calculationVersion);
    expect(restored.disclaimer, full.disclaimer);
  });

  test('a restricted stage keeps the reason it was restricted for', () {
    // Menopause and pregnancy come back with tracking switched off and a
    // message explaining why. Those two read from top-level `reason` and
    // `message`, which is easy to miss when mirroring the shape.
    const restricted = CycleState(
      cycleTrackingAvailable: false,
      hasData: false,
      restrictedReason: 'stage_excluded',
      restrictedMessage: 'Your current stage does not use cycle tracking.',
    );

    final restored =
        CycleState.fromJson(jsonDecode(jsonEncode(restricted.toJson())));

    expect(restored.cycleTrackingAvailable, isFalse);
    expect(restored.restrictedReason, 'stage_excluded');
    expect(restored.restrictedMessage,
        'Your current stage does not use cycle tracking.');
  });

  test('an empty cache does not resurrect a cycle', () {
    // What the restore reads on a first launch.
    final restored = CycleState.fromJson(<String, dynamic>{});

    expect(restored.currentCycleDay, isNull);
    expect(restored.hasData, isFalse);
    expect(restored.cycleStartDate, isNull);
  });
}
