import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A control in "Manage My Data" must do what it says.
///
/// "Reset AI Recommendations" had a body consisting entirely of a snackbar
/// reading "Personalized recommendations reset." It reset nothing. The two
/// beside it — "Clear Symptom History" and "Restart Cycle Learning" — change
/// local state only, and no endpoint deletes anything, so the account's copy
/// returns on the next sync while the user has been told it was cleared.
///
/// This is the section where someone goes to exercise control over their own
/// data, which makes it the worst place in the app to overstate what happened.
void main() {
  final settings =
      File('lib/features/home/widgets/my_health_screen.dart').readAsStringSync();

  test('the AI reset performs an action, not just a message', () {
    final start = settings.indexOf("label: 'Reset AI Recommendations'");
    expect(start, greaterThan(-1), reason: 'the control moved');
    final body = settings.substring(start, start + 900);

    expect(body.contains('markDashboardDirty'), isTrue,
        reason: 'it must actually clear the cached suggestions');
  });

  test('nothing claims to have deleted data that is still on the account', () {
    // No endpoint deletes logs, so any wording promising it is false.
    for (final claim in [
      "Text('Symptom logs cleared.')",
      "Text('Personalized recommendations reset.')",
      "Text('Cycle learning model reset.')",
    ]) {
      expect(settings.contains(claim), isFalse,
          reason: 'this overstates what happened: $claim');
    }
  });

  test('there is still no server-side delete to wire up', () async {
    // If one is added, these controls should be rewired to it and this test
    // will fail as the reminder.
    final routes = Directory('backend/src/routes').listSync().whereType<File>();
    final hasDelete = routes.any((f) {
      final s = f.readAsStringSync();
      return RegExp(r"router\.(delete|post)\('[^']*(logs|symptoms)[^']*'").hasMatch(s);
    });

    expect(hasDelete, isFalse,
        reason: 'a delete endpoint now exists — wire these controls to it and '
            'restore the stronger wording');
  });
}
