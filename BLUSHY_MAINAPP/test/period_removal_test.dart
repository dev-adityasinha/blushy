import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A logged period has to be removable.
///
/// `CycleApi.deletePeriod` existed, and so did `DELETE /cycle/periods/:id`
/// behind it, and no screen in the app called either. So a mis-tapped start
/// was permanent.
///
/// It compounds, because the cycle is anchored to the *latest* start: logging
/// the real earlier date again does not undo it. A new start only replaces
/// existing ones inside one cycle length of itself -- `minCycleLengthDays`,
/// 18 days -- so two starts 19 days apart both survive and the wrong, later
/// one keeps winning.
///
/// Seen in production: a start logged for 15 Sep by mistake, the real 27 Aug
/// logged again to correct it, and the account stayed on Day 1 because both
/// rows were kept. The partner screen showed Day 1 too, correctly, which made
/// it look like the partner view was stale when it was the only honest thing
/// on screen.
void main() {
  late final String dashboard;

  setUpAll(() {
    dashboard = File(
      'lib/features/home/presentation/stages/everyday_wellness_dashboard.dart',
    ).readAsStringSync();
  });

  test('the sheet can remove a logged start', () {
    expect(dashboard, contains('CycleApi.deletePeriod('));
    expect(dashboard, contains('Remove this period'));
  });

  test('it is only offered for a date that actually has one on file', () {
    // Offering it where there is nothing to remove invites a tap that can only
    // fail, on a control whose whole job is deletion.
    expect(dashboard, contains('_loggedEntryFor(loggedStarts, selectedStart) != null'));
  });

  test('and it asks first, naming the date', () {
    final start = dashboard.indexOf('Future<void> _confirmRemovePeriod(');
    expect(start, greaterThan(-1));
    final body = dashboard.substring(start, start + 2600);

    expect(body, contains('showDialog<bool>'));
    expect(body, contains('Remove this period?'));
    expect(body, contains('Keep it'));
    // The date being removed appears in the question, not "this one".
    expect(body, contains(r'starting $label'));
    // Nothing is deleted on a dismissed dialog.
    expect(body, contains('if (confirmed != true'));
  });

  test('the screen re-reads the cycle afterwards', () {
    // Without this the ring keeps drawing the cycle that was just deleted.
    final start = dashboard.indexOf('Future<void> _confirmRemovePeriod(');
    final body = dashboard.substring(start, start + 2600);
    expect(body, contains('_loadCycleFromServer()'));
  });

  test('a failure says so rather than looking like it worked', () {
    final start = dashboard.indexOf('Future<void> _confirmRemovePeriod(');
    final body = dashboard.substring(start, start + 2600);
    expect(body, contains('could not be removed'));
  });
}
