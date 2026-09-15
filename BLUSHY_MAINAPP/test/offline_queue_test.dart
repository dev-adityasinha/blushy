import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:blushy_life_app/services/offline_event_queue.dart';

/// The queue is what stops a check-in made without signal from being lost, and
/// it is now drained whenever the app returns to the foreground rather than
/// only when one screen happens to rebuild. These pin the parts that do not
/// need a server.
void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The queue is namespaced per account and stored in SharedPreferences, so
    // both a session and a prefs backing store are needed.
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('blushy_queue_');
    BlushyStorage.storageRoot = tempDir.path;
    AuthStorage.saveSession(token: 'test-token', userId: 'queue-test-user');
    await OfflineEventQueue.instance.clear();
  });

  tearDown(() async {
    await OfflineEventQueue.instance.clear();
    BlushyStorage.storageRoot = null;
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('flushing an empty queue reports that it did nothing', () async {
    await OfflineEventQueue.instance.load();
    final result = await OfflineEventQueue.instance.flush();
    expect(result.didAnything, isFalse,
        reason: 'a no-op flush must not trigger a dashboard reload');
  });

  test('re-enqueuing the same clientEventId replaces rather than duplicates', () async {
    await OfflineEventQueue.instance.load();

    await OfflineEventQueue.instance.enqueue(
      eventType: 'mood_logged',
      payload: {'mood': 'low'},
      clientEventId: 'same-id',
    );
    await OfflineEventQueue.instance.enqueue(
      eventType: 'mood_logged',
      payload: {'mood': 'good'},
      clientEventId: 'same-id',
    );

    // Two taps on one control while offline are one intent, not two events.
    expect(OfflineEventQueue.instance.pendingCount.value, 1);
  });

  test('distinct events are all kept', () async {
    await OfflineEventQueue.instance.load();

    await OfflineEventQueue.instance.enqueue(
      eventType: 'mood_logged',
      payload: {'mood': 'low'},
      clientEventId: 'a',
    );
    await OfflineEventQueue.instance.enqueue(
      eventType: 'sleep_logged',
      payload: {'durationHours': 7},
      clientEventId: 'b',
    );

    expect(OfflineEventQueue.instance.pendingCount.value, 2);
  });

  test('clearing empties the queue, so a sign-out leaves nothing behind', () async {
    await OfflineEventQueue.instance.load();
    await OfflineEventQueue.instance.enqueue(
      eventType: 'mood_logged',
      payload: {'mood': 'low'},
      clientEventId: 'x',
    );
    expect(OfflineEventQueue.instance.pendingCount.value, 1);

    await OfflineEventQueue.instance.clear();
    expect(OfflineEventQueue.instance.pendingCount.value, 0,
        reason: "one account's unsent writes must not replay under the next");
  });
}
