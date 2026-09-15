import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blushy_life_app/core/stage_config.dart';
import 'package:blushy_life_app/features/partner/partner_stage.dart';
import 'package:blushy_life_app/features/partner/presentation/partner_stage_today.dart';

/// Partner Home, per life stage.
///
/// Two things are pinned here, and they are the two things that were wrong.
///
/// **The vocabulary.** The server normalises every stage to snake_case and the
/// client's `StageConfig` switches on camelCase. Nothing translated between
/// them, and on top of that the screen read the stage off `partnerUser`, which
/// has no such field -- so it was null on every account and fell back to
/// "everydayWellness". A partner of someone in her third trimester was shown
/// an ordinary week.
///
/// **The values.** Stage cards are the place where a plausible-looking number
/// is easiest to invent and hardest to notice. Every figure on this screen has
/// to come from the permission-filtered payload, and where the payload is
/// silent the card has to say so rather than fill in.

/// Builds the view over a payload shaped exactly like `permittedContext`.
PartnerStageToday _today(
  PartnerStage stage, [
  Map<String, dynamic> permitted = const {},
]) =>
    PartnerStageToday(stage: stage, permitted: permitted, partnerName: 'Maya');

void main() {
  group('one stage vocabulary', () {
    test('every key the server can send resolves', () {
      const fromServer = {
        'first_period': PartnerStage.firstPeriod,
        'cycle_tracking': PartnerStage.cycleTracking,
        'hormonal_health': PartnerStage.hormonalHealth,
        'ttc': PartnerStage.ttc,
        'pregnancy': PartnerStage.pregnancy,
        'postpartum': PartnerStage.postpartum,
        'perimenopause': PartnerStage.perimenopause,
        'menopause': PartnerStage.menopause,
        'everyday_wellness': PartnerStage.everydayWellness,
      };
      fromServer.forEach((key, expected) {
        expect(PartnerStage.from(key), expected, reason: key);
      });
    });

    test('and every spelling the client ever wrote', () {
      // These are the ones that silently matched nothing.
      expect(PartnerStage.from('tryingToConceive'), PartnerStage.ttc);
      expect(PartnerStage.from('firstPeriodNotStarted'), PartnerStage.firstPeriod);
      expect(PartnerStage.from('firstPeriodStarted'), PartnerStage.firstPeriod);
      expect(PartnerStage.from('livingWithMyCycle'), PartnerStage.cycleTracking);
      expect(PartnerStage.from('reproductiveYears'), PartnerStage.cycleTracking);
      expect(PartnerStage.from('hormonalHealth'), PartnerStage.hormonalHealth);
      expect(PartnerStage.from('everydayWellness'), PartnerStage.everydayWellness);
    });

    test('an unrecognised value is unknown, never a default stage', () {
      // "everydayWellness" was the old fallback, and it is a claim about her.
      for (final raw in [null, '', '   ', 'banana', 42, {'a': 1}]) {
        expect(PartnerStage.from(raw), PartnerStage.unknown, reason: '$raw');
      }
      expect(PartnerStage.unknown.isKnown, isFalse);
    });

    test('resolve prefers the permission-filtered value', () {
      expect(
        PartnerStage.resolve(
          permittedContext: {'lifeStage': 'pregnancy'},
          sharedData: {'lifeStage': 'cycle_tracking'},
        ),
        PartnerStage.pregnancy,
      );
    });

    test('and falls back to the shared-data payload, not to partnerUser', () {
      // `partnerUser.lifeStage` is the path that never existed. A payload that
      // only has it must resolve to unknown, not to a guess.
      expect(
        PartnerStage.resolve(sharedData: {'lifeStage': 'postpartum'}),
        PartnerStage.postpartum,
      );
      expect(
        PartnerStage.resolve(sharedData: {
          'partnerUser': {'lifeStage': 'pregnancy'},
        }),
        PartnerStage.unknown,
      );
    });

    test('every stage still resolves a StageConfig of its own', () {
      // configKey exists so the older stage config keeps working. If one of
      // these fell through to the default, its copy would be somebody else's.
      final seen = <String>{};
      for (final stage in PartnerStage.values) {
        if (!stage.isKnown) continue;
        final config = StageConfig.forStage(stage.configKey);
        expect(config.displayName, isNotEmpty, reason: stage.name);
        seen.add(config.displayName);
      }
      expect(seen.length, greaterThanOrEqualTo(8),
          reason: 'stages sharing one config means one of them fell through');
    });
  });

  group('values are hers, or absent', () {
    test('with nothing shared, no badge shows a number', () {
      for (final stage in PartnerStage.values) {
        for (final badge in _today(stage).badges) {
          expect(
            RegExp(r'\d').hasMatch(badge.value),
            isFalse,
            reason: '${stage.name} badge "${badge.label}" invented '
                '"${badge.value}"',
          );
          expect(badge.value, isNotEmpty);
        }
      }
    });

    test('an unshared signal says which kind of nothing it is', () {
      final badges = _today(PartnerStage.cycleTracking).badges;
      final values = badges.map((b) => b.value).toList();
      // "Private" is her decision; "Not logged" is simply no entry today.
      // They are different facts and the screen does not blur them.
      expect(values, contains('Private'));
      expect(values.any((v) => v == 'Not logged' || v == 'Paused'), isTrue);
    });

    test('pregnancy reports the week and trimester she actually shared', () {
      final due = DateTime.now().add(const Duration(days: 112));
      final today = _today(PartnerStage.pregnancy, {
        'pregnancyWeek': {
          'week': 24,
          'trimester': 2,
          'dueDate': due.toIso8601String(),
        },
      });

      expect(today.pregnancyWeek, 24);
      expect(today.trimester, 2);
      expect(today.daysToDue, closeTo(112, 1));
      expect(today.cardHeadline, contains('Week 24'));
      expect(today.greetingFacts, contains('Week 24'));
    });

    test('a due date already past does not become a negative countdown', () {
      final today = _today(PartnerStage.pregnancy, {
        'pregnancyWeek': {
          'week': 41,
          'dueDate':
              DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        },
      });
      expect(today.daysToDue, isNull);
      expect(
        today.badges.firstWhere((b) => b.label == 'DUE').value,
        'Not shared',
      );
    });

    test('no fertile window shared reads as unknown, not as "not today"', () {
      // false here would tell him something about her body that nobody said.
      expect(_today(PartnerStage.ttc).inFertileWindow, isNull);
      expect(
        _today(PartnerStage.ttc).badges.first.value,
        'Not shared',
      );

      final open = _today(PartnerStage.ttc, {
        'fertileWindow': {
          'start': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'end': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        },
      });
      expect(open.inFertileWindow, isTrue);
      expect(open.badges.first.value, 'Open now');
    });

    test('the live note is null when she logged nothing', () {
      expect(_today(PartnerStage.postpartum).liveNote, isNull);

      final logged = _today(PartnerStage.postpartum, {
        'mood': {'value': 'tired'},
        'sleep': {'durationHours': 2.5},
      });
      // Her word, lower-cased because it sits mid-sentence; the badge keeps
      // the capital.
      expect(logged.liveNote, contains('tired'));
      expect(
        _today(PartnerStage.postpartum, {'mood': {'value': 'tired'}}).mood,
        'Tired',
      );
      expect(logged.liveNote, contains('2.5 hrs'));
      expect(logged.liveNote, startsWith('Maya'));
    });

    test('energy is reported on the scale it was logged on', () {
      // The payload says `scale: '1_5'`. Rendering a 4 as "8/10" would be a
      // number nobody entered.
      expect(
        _today(PartnerStage.cycleTracking, {
          'energyLevel': {'value': 4, 'scale': '1_5'},
        }).energy,
        'High',
      );
      expect(_today(PartnerStage.cycleTracking).energy, isNull);
    });

    test('an old appointment is not offered as the next one', () {
      final today = _today(PartnerStage.pregnancy, {
        'appointments': [
          {
            'title': 'Scan',
            'date': DateTime.now()
                .subtract(const Duration(days: 30))
                .toIso8601String(),
          },
        ],
      });
      expect(today.nextAppointment, isNull);
    });
  });

  group('the stage leads only where it says more', () {
    test('it does for the stages with their own shape', () {
      for (final stage in [
        PartnerStage.firstPeriod,
        PartnerStage.hormonalHealth,
        PartnerStage.ttc,
        PartnerStage.pregnancy,
        PartnerStage.postpartum,
        PartnerStage.perimenopause,
        PartnerStage.menopause,
      ]) {
        expect(_today(stage).stageLeads, isTrue, reason: stage.name);
      }
    });

    test('and does not where the cycle phase is the more specific thing', () {
      for (final stage in [
        PartnerStage.cycleTracking,
        PartnerStage.everydayWellness,
        PartnerStage.unknown,
      ]) {
        expect(_today(stage).stageLeads, isFalse, reason: stage.name);
      }
    });

    test('every stage has its own card wording', () {
      final headlines = <String>{};
      final bodies = <String>{};
      for (final stage in PartnerStage.values) {
        final today = _today(stage);
        expect(today.cardEyebrow, isNotEmpty, reason: stage.name);
        headlines.add(today.cardHeadline);
        bodies.add(today.cardBody);
      }
      // Ten stages, and menopause deliberately shares neither with anyone.
      expect(bodies.length, greaterThanOrEqualTo(9));
      expect(headlines.length, greaterThanOrEqualTo(9));
    });

    test('the card body never states something about her', () {
      // It explains the stage. The claims about her live in the pills below
      // it, which are built from real values only.
      for (final stage in PartnerStage.values) {
        final body = _today(stage).cardBody;
        for (final claim in ['Maya is', 'She logged', 'Her hormones are']) {
          expect(body.contains(claim), isFalse,
              reason: '${stage.name}: "$claim"');
        }
      }
    });
  });

  group('the read-only tracker', () {
    testWidgets('draws nothing when she has shared no dial', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PartnerCycleTracker(today: _today(PartnerStage.cycleTracking)),
        ),
      ));
      expect(find.text('Read only'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('says so plainly when it does', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PartnerCycleTracker(
            today: _today(PartnerStage.pregnancy, {
              'pregnancyWeek': {'week': 24, 'trimester': 2},
            }),
          ),
        ),
      ));
      expect(find.text('Read only'), findsOneWidget);
      expect(find.text('Week 24 of 40'), findsOneWidget);
      expect(find.textContaining('Only Maya can log'), findsOneWidget);
    });

    test('it hands the ring no way to write to her cycle', () {
      // Read-only is enforced by what is passed, not by hiding a button:
      // CycleRingCard draws its log-period and set-up controls only when it is
      // given those callbacks.
      final source = File(
        'lib/features/partner/presentation/partner_stage_today.dart',
      ).readAsStringSync();
      final start = source.indexOf('return CycleRingCard(');
      expect(start, greaterThan(-1));
      final ring = source.substring(start, source.indexOf(');', start));
      for (final callback in ['onCalendar: null', 'onSetUp: null', 'onInsights: null']) {
        expect(ring, contains(callback), reason: callback);
      }
    });

    test('no countdown without a length of hers to compute it from', () {
      // `(length ?? 28) - day` would have printed a 28-day assumption as her
      // number. Without her next-period window there is simply no line.
      final noWindow = _today(PartnerStage.cycleTracking, {
        'cyclePhase': {'phase': 'Luteal phase', 'cycleDay': 20},
      });
      expect(noWindow.cycleLength, isNull);

      final withWindow = _today(PartnerStage.cycleTracking, {
        'cyclePhase': {'phase': 'Luteal phase', 'cycleDay': 20},
        'nextPeriodWindow': {
          'earliest': DateTime.now().add(const Duration(days: 8)).toIso8601String(),
        },
      });
      expect(withWindow.cycleLength, closeTo(28, 1));
    });

    test('a nonsensical window is refused rather than drawn', () {
      final absurd = _today(PartnerStage.cycleTracking, {
        'cyclePhase': {'cycleDay': 20},
        'nextPeriodWindow': {
          'earliest':
              DateTime.now().add(const Duration(days: 400)).toIso8601String(),
        },
      });
      expect(absurd.cycleLength, isNull);
    });
  });

  group('his ring is her ring', () {
    test('her mood is shown in the word she tapped', () {
      // The check-in stores a token, not the label: `checkin_event_mapper`
      // maps "Happy" to `good` on the way in. Showing the token verbatim told
      // her partner she felt "good" when she had pressed "Happy" -- near
      // enough to look right, wrong enough to be her word replaced by ours.
      const tapped = {
        'good': 'Happy',
        'okay': 'Okay',
        'calm': 'Calm',
        'low': 'Low',
        'irritable': 'Irritable',
      };
      tapped.forEach((stored, shown) {
        final today = _today(PartnerStage.cycleTracking, {
          'mood': {'value': stored},
        });
        expect(today.mood, shown, reason: stored);
      });
    });

    test('an older or unknown token is shown, not dropped', () {
      // Rows written before the current vocabulary still exist, and a token
      // nobody mapped is better shown than silently turned into "Private".
      expect(
        _today(PartnerStage.cycleTracking, {'mood': {'value': 'great'}}).mood,
        'Happy',
      );
      expect(
        _today(PartnerStage.cycleTracking, {'mood': {'value': 'irritated'}}).mood,
        'Irritable',
      );
      expect(
        _today(PartnerStage.cycleTracking, {'mood': {'value': 'wistful'}}).mood,
        'Wistful',
      );
      expect(_today(PartnerStage.cycleTracking).mood, isNull);
    });

    test('the ring is drawn to her cycle, not to 28 and 5', () {
      final today = _today(PartnerStage.cycleTracking, {
        'cyclePhase': {
          'phase': 'Follicular Phase',
          'cycleDay': 16,
          'cycleLengthDays': 30,
          'periodLengthDays': 6,
        },
      });

      expect(today.cycleDay, 16);
      expect(today.cycleLength, 30);
      expect(today.periodLength, 6);
    });

    test('a length outside the plausible range is refused, not drawn', () {
      final today = _today(PartnerStage.cycleTracking, {
        'cyclePhase': {'cycleDay': 5, 'cycleLengthDays': 400, 'periodLengthDays': 99},
      });
      expect(today.cycleLength, isNull);
      expect(today.periodLength, isNull);
    });

    test('her shared length outranks the one inferred from the window', () {
      final today = _today(PartnerStage.cycleTracking, {
        'cyclePhase': {'cycleDay': 20, 'cycleLengthDays': 31},
        'nextPeriodWindow': {
          'earliest': DateTime.now().add(const Duration(days: 8)).toIso8601String(),
        },
      });
      // The window would imply 28. Hers is 31, and hers wins.
      expect(today.cycleLength, 31);
    });
  });

  group('the partner screens keep themselves current', () {
    // They each fetched once in initState and never again, so what was on
    // screen was "as of whenever this opened" with nothing saying so. A mood
    // she logged, a permission she changed, a cycle day that rolled over at
    // midnight -- none of it appeared until the app was killed and reopened.

    String _read(String path) => File(path).readAsStringSync();

    test('the mechanism lives in one place', () {
      // Four near-identical timers, each with its own chance of outliving its
      // State, is how this becomes a crash later.
      final mixin = _read('lib/features/partner/presentation/live_refresh.dart');

      expect(mixin, contains('didChangeAppLifecycleState'));
      expect(mixin, contains('AppLifecycleState.resumed'));
      expect(mixin, contains('Timer.periodic'));
      expect(mixin, contains('_liveTimer?.cancel()'));
      expect(mixin, contains('removeObserver(this)'));
      // A slow request on a cold instance must not stack up behind itself.
      expect(mixin, contains('_refreshInFlight'));
    });

    test('and every partner screen that fetches uses it', () {
      for (final path in [
        'lib/features/partner/presentation/partner_home.dart',
        'lib/features/partner/presentation/partner_sia.dart',
      ]) {
        final source = _read(path);
        expect(source, contains('LiveRefresh'), reason: path);
        expect(source, contains('startLiveRefresh()'), reason: path);
        expect(source, contains('stopLiveRefresh()'), reason: path);
        expect(source, contains('Future<void> refreshNow()'), reason: path);
      }
    });

    test('home also takes the push the server already sends', () {
      // PartnerScreen has listened to this socket since it was written. Home
      // never did -- so the one screen built entirely out of what she shares
      // was the last to hear that she had changed it.
      final source = _read('lib/features/partner/presentation/partner_home.dart');

      expect(source, contains('PartnerWebSocketService'));
      expect(source, contains("'permissions-updated'"));
      expect(source, contains('_wsSubscription?.cancel()'));
      expect(source, contains('RefreshIndicator'));
    });
  });

  test('saving permissions sends only what the caller may change', () {
    // Production, twice inside two minutes:
    //   PATCH /partner/connections/.../permissions refused with 403:
    //   "Only he can change this setting."
    //
    // The modal sent all eight keys. Three belong to a side of the
    // connection, and the server refuses the *whole* patch if any changed key
    // is not the caller's to set -- so her stored values for his two switches
    // differing from the seeded ones threw out every cycle, mood and sleep
    // change she had just made, behind a 403 she never saw. It reads exactly
    // like a toggle that will not stick.
    final source = File(
      'lib/features/partner/partner_screen.dart',
    ).readAsStringSync();

    expect(source, contains('changeableBy(perms)'));
    expect(source, contains("const his = {'allowAiSuggestionsMan', 'allowDecoderMan'}"));
    expect(source, contains("const hers = {'allowAiSuggestionsWoman'}"));

    // And the seeded defaults are closed, not open: an unknown privacy
    // setting shown as "sharing" is a claim about her that nobody made.
    final seed = source.substring(
      source.indexOf('Map<String, dynamic> perms = {'),
      source.indexOf('};', source.indexOf('Map<String, dynamic> perms = {')),
    );
    expect(seed.contains('true'), isFalse, reason: seed);
  });

  test('nothing here reads a field the payload does not carry', () {
    // The brief asked for a puberty kit count, a baby size analogy, kick
    // counts, a PMDD flare countdown, ovulation-test status, hot-flash counts
    // and feeding logs. None of them exists anywhere in the app, so none of
    // them can be read -- and inventing them is exactly the failure this whole
    // screen was rewritten to stop.
    final source = File(
      'lib/features/partner/presentation/partner_stage_today.dart',
    ).readAsStringSync();

    for (final absent in [
      'pubertyKit',
      'babySize',
      'kickCount',
      'pmddFlare',
      'hotFlashCount',
      'nightSweatIntensity',
      'feedingLog',
      'bbt',
      'opk',
      'inflammationScore',
    ]) {
      expect(
        source.contains("'$absent'"),
        isFalse,
        reason: '$absent is not a field the server sends',
      );
    }
  });
}
