import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/core/metric_gating.dart';
import 'package:blushy_life_app/core/tracker_log.dart';

/// What a tracker records has to still be there tomorrow.
void main() {
  test('the writer and the reader derive the same key', () {
    // The bug: the writer stored {metric, value, date} under 'peri_log' and
    // the reader looked for peri_log['hot_flashes']. One function now serves
    // both, so they cannot drift.
    expect(trackerLogKey('peri_log', 'HOT FLASHES'), 'log_peri_hot_flashes');
    expect(trackerLogKey('peri', 'HOT FLASHES'), 'log_peri_hot_flashes',
        reason: 'the category is the same with or without the _log suffix');
  });

  test('punctuation and spacing collapse predictably', () {
    expect(trackerLogKey('ttc_log', 'OVULATION TEST (LH)'),
        'log_ttc_ovulation_test_lh');
    expect(trackerLogKey('menopause_log', 'BONE & JOINT COMFORT'),
        'log_menopause_bone_joint_comfort');
    expect(trackerLogKey('hormone_log', 'FACIAL & BODY HAIR'),
        'log_hormone_facial_body_hair');
  });

  test('the value is a bare string', () {
    // The endpoint stores a non-string answer as JSON.stringify(value), so a
    // map came back a String and every loader's `is Map` check failed. Flat
    // string values are what it can actually round-trip.
    expect(trackerLogKey('daily_checkin', 'STRESS LEVEL'),
        'log_daily_checkin_stress_level');
  });

  test('logged values cannot switch their own card back on', () {
    // A tracker writes its own label into the same answers map the gating
    // reads. Without this exclusion, logging "HOT FLASHES" once would hold
    // that card open regardless of what she asked to track.
    expect(isNonQuestionAnswerKey(trackerLogKey('peri', 'HOT FLASHES')), isTrue);
    expect(isNonQuestionAnswerKey('hormone_log'), isTrue,
        reason: 'the old shape is still in stored data');
    expect(isNonQuestionAnswerKey('ttc_tracking_method'), isFalse,
        reason: 'a real answer must still count');
  });
}
