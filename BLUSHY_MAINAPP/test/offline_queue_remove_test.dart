import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:blushy_life_app/services/offline_event_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/isolated_storage.dart';

/// A pick taken back before its event ever reached the server.
///
/// The event is still in the offline queue, waiting for a connection, and
/// sending it later would put back what she just removed. `removeWhere`
/// drops it there. It is matched by type and day, because a metric can
/// queue several idempotency keys in one day -- each option has its own --
/// and all of them are what she took back.
void main() {
  useIsolatedStorage();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthStorage.saveSession(
      token: 't',
      userId: 'u-queue',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );
  });

  test('drops the queued events of that type from that day, and no others',
      () async {
    final queue = OfflineEventQueue.instance;
    await queue.clear();
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    await queue.enqueue(
      eventType: 'energy_logged',
      payload: const {'level': 0, 'reportedAs': 'Low'},
      clientEventId: 'energy-today-low',
      timestamp: today,
    );
    await queue.enqueue(
      eventType: 'energy_logged',
      payload: const {'level': 2, 'reportedAs': 'High'},
      clientEventId: 'energy-today-high',
      timestamp: today,
    );
    await queue.enqueue(
      eventType: 'energy_logged',
      payload: const {'level': 1, 'reportedAs': 'Medium'},
      clientEventId: 'energy-yesterday',
      timestamp: yesterday,
    );
    await queue.enqueue(
      eventType: 'pain_logged',
      payload: const {'severity': 2, 'reportedAs': 'Severe'},
      clientEventId: 'pain-today',
      timestamp: today,
    );
    expect(queue.pendingCount.value, 4);

    final dropped = await queue.removeWhere(
      eventType: 'energy_logged',
      day: today,
    );

    expect(dropped, 2, reason: 'both of today\'s energy keys go');
    expect(queue.pendingCount.value, 2,
        reason: 'yesterday\'s energy and today\'s pain stay');
  });

  test('a delete made offline waits in the queue', () async {
    final queue = OfflineEventQueue.instance;
    await queue.clear();
    final now = DateTime.now();

    await queue.enqueueDelete(eventType: 'flow_logged', day: now, before: now);
    expect(await queue.pendingDeletes(), 1);

    // Taking the same thing back again the same day is still one delete.
    await queue.enqueueDelete(eventType: 'flow_logged', day: now, before: now);
    expect(await queue.pendingDeletes(), 1);

    // A different type is its own.
    await queue.enqueueDelete(eventType: 'pain_logged', day: now, before: now);
    expect(await queue.pendingDeletes(), 2);
  });

  test('a log made after the delete is not swept up by it', () async {
    // removeWhere clears the logs that came before a take-back. A log queued
    // after it is a new decision, and the delete must leave it alone -- in
    // the queue now, and on the server later, which is what `before` is for.
    final queue = OfflineEventQueue.instance;
    await queue.clear();
    final now = DateTime.now();

    await queue.enqueueDelete(eventType: 'flow_logged', day: now, before: now);
    await queue.enqueue(
      eventType: 'flow_logged',
      payload: const {'level': 1, 'reportedAs': 'Medium'},
      clientEventId: 'flow-after',
      timestamp: now.add(const Duration(minutes: 1)),
    );

    final dropped = await queue.removeWhere(eventType: 'pain_logged', day: now);
    expect(dropped, 0, reason: 'nothing of that type is queued');
    expect(await queue.pendingDeletes(), 1, reason: 'removeWhere never drops a delete');
    expect(queue.pendingCount.value, 2, reason: 'the later log is still there');
  });

  test('with no connection, a flush keeps the delete and the logs behind it',
      () async {
    // The test binding has no network: the replay cannot reach the server,
    // so the delete stays and nothing after it is sent out of order.
    final queue = OfflineEventQueue.instance;
    await queue.clear();
    final now = DateTime.now();

    await queue.enqueueDelete(eventType: 'flow_logged', day: now, before: now);
    await queue.enqueue(
      eventType: 'flow_logged',
      payload: const {'level': 1, 'reportedAs': 'Medium'},
      clientEventId: 'flow-after',
      timestamp: now.add(const Duration(minutes: 1)),
    );

    final result = await queue.flush();
    expect(result.deleted, 0);
    expect(result.accepted, 0);
    expect(await queue.pendingDeletes(), 1);
    expect(queue.pendingCount.value, 2);
  });

  test('nothing to drop is not an error', () async {
    final queue = OfflineEventQueue.instance;
    await queue.clear();
    final dropped = await queue.removeWhere(
      eventType: 'flow_logged',
      day: DateTime.now(),
    );
    expect(dropped, 0);
  });
}
