import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blushy_life_app/features/partner/partner_stage.dart';
import 'package:blushy_life_app/features/partner/presentation/partner_stage_today.dart';

/// Does the tracker actually appear, for a connected partner, in every stage?
///
/// Asked directly, and it is not a question source-reading can answer: the
/// card decides for itself whether it has anything to draw, and the answer
/// differs per stage. So these render it, with the payload each stage would
/// really arrive with, and look at what comes out.
///
/// The rule it is checking: a dial is drawn from something she shared, or it
/// is not drawn at all. There is no stage where the partner sees a ring built
/// out of defaults.

PartnerStageToday _today(
  PartnerStage stage,
  Map<String, dynamic> permitted,
) =>
    PartnerStageToday(stage: stage, permitted: permitted, partnerName: 'Maya');

/// What the permission-filtered payload carries for someone mid-cycle, as the
/// server now sends it.
Map<String, dynamic> _cyclePayload({int day = 16}) => {
      'cyclePhase': {
        'phase': 'Ovulation Phase',
        'cycleDay': day,
        'cycleLengthDays': 28,
        'periodLengthDays': 5,
      },
    };

Future<void> _render(WidgetTester tester, PartnerStageToday today) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: PartnerCycleTracker(today: today)),
    ),
  ));
}

void main() {
  group('the tracker appears wherever there is something to draw', () {
    testWidgets('living with her cycle: the ring, on her numbers', (tester) async {
      await _render(tester, _today(PartnerStage.cycleTracking, _cyclePayload()));

      expect(find.text('Read only'), findsOneWidget);
      expect(find.text('HER CYCLE'), findsOneWidget);
      // The same ring her own home draws, showing the same day.
      expect(find.textContaining('Day 16', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('Ovulation'), findsWidgets);
      expect(find.textContaining('Only Maya can log'), findsOneWidget);
    });

    testWidgets('hormonal health: the cycle still drives it', (tester) async {
      await _render(tester, _today(PartnerStage.hormonalHealth, _cyclePayload(day: 22)));
      expect(find.text('HER CYCLE'), findsOneWidget);
      expect(find.textContaining('Day 22', findRichText: true),
          findsOneWidget);
    });

    testWidgets('trying to conceive: the same ring', (tester) async {
      await _render(tester, _today(PartnerStage.ttc, _cyclePayload(day: 12)));
      expect(find.text('HER CYCLE'), findsOneWidget);
      expect(find.textContaining('Day 12', findRichText: true),
          findsOneWidget);
    });

    testWidgets('first period: the ring once there is a cycle', (tester) async {
      await _render(tester, _today(PartnerStage.firstPeriod, _cyclePayload(day: 3)));
      expect(find.text('HER CYCLE'), findsOneWidget);
      expect(find.textContaining('Day 3', findRichText: true),
          findsOneWidget);
    });

    testWidgets('pregnancy: a straight track, not a ring', (tester) async {
      // A pregnancy does not come back to where it started, and drawing it as
      // a circle would say it did.
      await _render(
        tester,
        _today(PartnerStage.pregnancy, {
          'pregnancyWeek': {
            'week': 24,
            'trimester': 2,
            'dueDate': DateTime.now().add(const Duration(days: 112)).toIso8601String(),
          },
        }),
      );

      expect(find.text('PREGNANCY PROGRESS'), findsOneWidget);
      expect(find.text('Week 24 of 40'), findsOneWidget);
      expect(find.textContaining('days to her due date'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('postpartum: weeks since birth, and recovery keeps going',
        (tester) async {
      await _render(
        tester,
        _today(PartnerStage.postpartum, {
          'postpartumMilestone': {'weeksSinceBirth': 2, 'title': 'Two weeks'},
        }),
      );

      expect(find.text('RECOVERY PROGRESS'), findsOneWidget);
      expect(find.text('Week 3 after birth'), findsOneWidget);
      // Six weeks is the check, not the finish line, and the card says so.
      expect(find.textContaining('Recovery keeps going'), findsOneWidget);
    });
  });

  group('and stays away where there is nothing honest to draw', () {
    testWidgets('perimenopause has no dial', (tester) async {
      // "Seven months without a period" is not a figure this payload carries,
      // and a dial is a poor place to start guessing.
      await _render(
        tester,
        _today(PartnerStage.perimenopause, {
          'mood': {'value': 'low'},
          'sleep': {'durationHours': 5},
        }),
      );
      expect(find.text('Read only'), findsNothing);
    });

    testWidgets('menopause has no dial either', (tester) async {
      await _render(tester, _today(PartnerStage.menopause, {'mood': {'value': 'calm'}}));
      expect(find.text('Read only'), findsNothing);
    });

    testWidgets('a cycle stage with nothing shared draws nothing', (tester) async {
      await _render(tester, _today(PartnerStage.cycleTracking, const {}));
      expect(find.text('Read only'), findsNothing);
      expect(find.text('HER CYCLE'), findsNothing);
    });

    testWidgets('an unknown stage draws nothing', (tester) async {
      await _render(tester, _today(PartnerStage.unknown, const {}));
      expect(find.text('Read only'), findsNothing);
    });
  });

  group('the numbers on it are hers', () {
    testWidgets('no countdown when she has not shared when it is due',
        (tester) async {
      // `(length ?? 28) - day` would print a 28-day assumption as her number.
      await _render(
        tester,
        _today(PartnerStage.cycleTracking, {
          'cyclePhase': {'phase': 'Luteal Phase', 'cycleDay': 20},
        }),
      );

      expect(find.textContaining('Next cycle begins in', findRichText: true),
          findsNothing);
      expect(find.textContaining('no countdown here'), findsOneWidget);
    });

    testWidgets('and a countdown once she has', (tester) async {
      await _render(
        tester,
        _today(PartnerStage.cycleTracking, {
          'cyclePhase': {
            'phase': 'Luteal Phase',
            'cycleDay': 20,
            'cycleLengthDays': 28,
            'periodLengthDays': 5,
          },
        }),
      );

      expect(find.textContaining('Next cycle begins in', findRichText: true),
          findsOneWidget);
    });
  });
}
