import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Today's Logged Signals shows what was just saved on the sheet.
///
/// The rows read an in-memory field before storage (`_livingPain ??
/// savedPain`). The inline check-in path sets both; the symptoms sheet's
/// save used to set only storage, so a field restored at startup from an
/// earlier check-in masked the new value for the rest of the session -- the
/// row said "Mild" while storage and the server said "Severe". On a fresh
/// session the fields were null and it happened to work, which is what made
/// it look intermittent.
void main() {
  final dashboard = File(
    'lib/features/home/presentation/stages/everyday_wellness_dashboard.dart',
  ).readAsStringSync();

  String methodBody(String signature) {
    final start = dashboard.indexOf(signature);
    expect(start, greaterThan(-1), reason: signature);
    // '\n  }' rather than '\n  }\n': the file is CRLF.
    return dashboard.substring(start, dashboard.indexOf('\n  }', start));
  }

  test('the sheet save sets every field the rows read first', () {
    final body = methodBody('void _persistCheckinSymptoms(Set<String> incoming) {');

    for (final field in const [
      '_selectedFeeling',
      '_selectedEnergy',
      '_livingSleep',
      '_livingStress',
      '_livingWater',
      '_livingExercise',
      '_livingFlow',
      '_livingPain',
    ]) {
      expect(body.contains('$field = '), isTrue,
          reason: '$field masks storage on the row; the save must set it');
    }
    expect(body.contains('setState('), isTrue,
        reason: 'the rows are built from these fields, so they must rebuild');
  });

  test('the sheet and the inline path set the same fields', () {
    // Two writers of the same state must agree on what the state is. The
    // inline path is the reference; the sheet mirrors it.
    final inline = RegExp(r"if \(selections\['(\w+)'\] != null\)")
        .allMatches(dashboard)
        .map((m) => m.group(1))
        .toSet();
    // The sheet sets a field when the metric was saved or cleared -- both
    // go through `touched(...)`.
    final sheet = RegExp(r"if \(touched\('(\w+)'\)\)")
        .allMatches(dashboard)
        .map((m) => m.group(1))
        .toSet();
    expect(sheet, equals(inline), reason: 'inline: $inline, sheet: $sheet');
  });

  test('a cleared pick takes its logged event with it', () {
    // Clearing the stored value alone left the health event behind, so the
    // sparkline and Docsy's context kept today's point. The save now drops
    // a queued copy and deletes a sent one.
    final save = methodBody('void _persistCheckinSymptoms(Set<String> incoming) {');
    expect(save.contains('_deleteLoggedEvents('), isTrue,
        reason: 'cleared metrics must have their events removed');
    expect(save.contains('CheckinEventMapper.map(metric, category.options.first)'),
        isTrue,
        reason: 'the event type comes from the mapper, not a second table');

    final remove = methodBody('Future<void> _deleteLoggedEvents(Set<String> eventTypes) async {');
    expect(remove.contains('OfflineEventQueue.instance.removeWhere('), isTrue,
        reason: 'an event that never left the device is dropped from the queue');
    expect(remove.contains('EventsApi.list('), isTrue);
    expect(remove.contains('EventsApi.delete(event.eventId)'), isTrue,
        reason: 'an event that reached the server is deleted there');
    expect(remove.contains('from: startOfDay'), isTrue,
        reason: 'only today\'s events -- never an earlier day\'s');
    // And with no connection the removal is not dropped: it waits in the
    // queue and runs on the next flush.
    expect(remove.contains('OfflineEventQueue.instance.enqueueDelete('), isTrue,
        reason: 'a delete that cannot run now is queued for later');
  });

  test('a cleared pick is cleared on the server too, and the save is dated', () {
    // The server merges answers by key: a key not sent keeps its old value,
    // and on the next start the device -- having none -- takes the server's,
    // so the cleared pick came back. Empty is what the client reads as
    // nothing to apply; the date is what lets it compare copies at all.
    final save = methodBody('void _persistCheckinSymptoms(Set<String> incoming) {');
    expect(save.contains("for (final metric in cleared) 'daily_\$metric': ''"), isTrue,
        reason: 'every cleared metric is sent as empty');
    expect(save.contains("'daily_logged_at': checkin['date']"), isTrue,
        reason: 'the server copy carries the save time');
  });

  test('a follow-up card is answered by its id, not by its metric', () {
    // The cards write the same metrics the sheet does, so "the metric has a
    // value" meant "the sheet was used", and every card vanished.
    final answer = methodBody('void _answerFollowUp(CheckinFollowUp card, String value) {');
    expect(answer.contains("checkin['answered_followups']"), isTrue);
    expect(answer.contains('card.id'), isTrue);
    expect(dashboard.contains('.where((card) => !_followUpAnswered(card))'), isTrue,
        reason: 'the deck filters on the id list');
    expect(dashboard.contains('.where((card) => _answerFor(card) == null)'), isFalse,
        reason: 'and no longer on the metric having a value');
  });

  test('the sheet reopens with the stored per-metric picks selected', () {
    // It used to pre-select only the flat symptom list, so an earlier energy
    // or pain pick was neither visible nor changeable from the sheet.
    final body = methodBody('Set<String> get _loggedSymptoms {');
    expect(body.contains('category.multiSelect'), isTrue,
        reason: 'single-answer metrics contribute their stored pick');
    expect(body.contains('category.options.contains(pick)'), isTrue,
        reason: 'only a pick the sheet can show is pre-selected');
    expect(body.contains("checkin['symptom']"), isTrue,
        reason: 'the flat list is still included');
  });
}
