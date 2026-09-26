import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/features/partner/companion_guidance.dart';
import 'package:blushy_life_app/features/partner/companion_widget_data.dart';

void main() {
  group('companion guidance', () {
    test('resolves known phases (case/alias tolerant) and null otherwise', () {
      expect(guidanceForPhase('luteal')?.phaseKey, 'luteal');
      expect(guidanceForPhase('Menstrual')?.phaseKey, 'menstrual');
      expect(guidanceForPhase('ovulatory')?.phaseKey, 'ovulation');
      expect(guidanceForPhase('follicular')?.phaseKey, 'follicular');
      expect(guidanceForPhase('pms')?.phaseKey, 'luteal');
      expect(guidanceForPhase(''), isNull);
      expect(guidanceForPhase(null), isNull);
    });

    test('every phase has a non-empty golden rule', () {
      for (final p in ['menstrual', 'follicular', 'ovulation', 'luteal']) {
        expect(guidanceForPhase(p)!.goldenRule.isNotEmpty, isTrue);
      }
    });
  });

  group('companion widget data', () {
    test('builds title/vibe/goldenRule and the store keys', () {
      final d = buildCompanionWidgetData(partnerName: 'Nithya', phase: 'luteal');
      expect(d, isNotNull);
      expect(d!.title, contains('Nithya'));
      expect(d.vibe.isNotEmpty, isTrue);
      expect(d.goldenRule.isNotEmpty, isTrue);
      final store = d.toStore();
      expect(store.containsKey('companion_widget_title'), isTrue);
      expect(store.containsKey('companion_widget_vibe'), isTrue);
      expect(store.containsKey('companion_widget_golden_rule'), isTrue);
    });

    test('is null when no phase is shared (widget shows its own empty state)', () {
      expect(buildCompanionWidgetData(partnerName: 'X', phase: null), isNull);
      expect(buildCompanionWidgetData(partnerName: 'X', phase: ''), isNull);
    });

    test('falls back to a neutral name when the name is blank', () {
      final d = buildCompanionWidgetData(partnerName: '  ', phase: 'menstrual');
      expect(d!.title, contains('She'));
    });
  });
}
