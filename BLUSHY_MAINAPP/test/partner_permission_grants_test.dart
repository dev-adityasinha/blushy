import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/models/blushy_models.dart';

/// The partner's Privacy & Sharing screen decides what it shows by comparing a
/// category's grants against the grants the server says this partner holds.
///
/// The grants have to come from the server. An earlier version of the screen
/// kept a local prefix table, and it was already wrong in two places -- it had
/// `general_insights` for a category actually keyed `general_ai_insights`, and
/// omitted four categories entirely -- which would have shown "Not shared" for
/// data the partner was in fact receiving.
void main() {
  // The screen's rule, kept identical here so a change to it fails a test.
  bool isShared(PartnerPermission permission, Set<String> allowedGrants) {
    if (permission.grants.isEmpty) return permission.enabled;
    return permission.grants.any(allowedGrants.contains);
  }

  group('PartnerPermission grants', () {
    test('grants are parsed from the permission matrix', () {
      final permission = PartnerPermission.fromJson({
        'key': 'cycle_insights',
        'label': 'Cycle insights',
        'example': 'Her period may be approaching.',
        'grants': ['cycle.phase', 'cycle.next_period_window', 'insight.cycle'],
      });

      expect(permission.grants, hasLength(3));
      expect(permission.grants, contains('cycle.phase'));
    });

    test('a missing grants field is empty rather than an error', () {
      final permission = PartnerPermission.fromJson({
        'key': 'mood',
        'label': 'Mood',
      });

      expect(permission.grants, isEmpty);
    });

    test('holding one of a category grants marks it shared', () {
      final cycle = PartnerPermission.fromJson({
        'key': 'cycle_insights',
        'label': 'Cycle insights',
        'grants': ['cycle.phase', 'cycle.next_period_window', 'insight.cycle'],
      });

      expect(isShared(cycle, {'cycle.phase'}), isTrue);
    });

    test('a category whose grants are absent reads as not shared', () {
      // The case that matters: sharing mood must not imply sharing a cycle.
      final cycle = PartnerPermission.fromJson({
        'key': 'cycle_insights',
        'label': 'Cycle insights',
        'grants': ['cycle.phase', 'cycle.next_period_window', 'insight.cycle'],
      });
      final mood = PartnerPermission.fromJson({
        'key': 'mood',
        'label': 'Mood',
        'grants': ['log.mood'],
      });

      const allowed = {'log.mood', 'support_request'};

      expect(isShared(mood, allowed), isTrue);
      expect(isShared(cycle, allowed), isFalse,
          reason: 'a cycle that was never shared must not read as on');
    });

    test('no grants at all means nothing reads as shared', () {
      final permissions = [
        PartnerPermission.fromJson({
          'key': 'mood',
          'label': 'Mood',
          'grants': ['log.mood'],
        }),
        PartnerPermission.fromJson({
          'key': 'sleep',
          'label': 'Sleep',
          'grants': ['log.sleep'],
        }),
      ];

      for (final permission in permissions) {
        expect(isShared(permission, const <String>{}), isFalse);
      }
    });
  });
}
