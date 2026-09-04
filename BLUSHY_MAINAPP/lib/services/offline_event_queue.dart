import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_blushy_service.dart';
import 'api_contract_client.dart';
import 'auth_storage.dart';

/// Queues health-event writes made while offline and replays them (spec §25).
///
/// Every queued item carries a `clientEventId`, so replaying the same entry is
/// deduplicated server side rather than creating a second log. That is what
/// makes retrying safe: a write that actually succeeded but whose response was
/// lost will not double up when it is retried.
///
/// The queue is per-account and persisted, so a log made offline survives the
/// app being closed.
///
/// It also carries deletes. A pick taken back while offline is kept as a
/// delete of that metric's events for that day, and replayed on the next
/// flush ahead of any queued logs -- against only the events stamped before
/// the delete was made, so a pick logged again later that day is never wiped
/// by an old delete catching up.
class OfflineEventQueue {
  static const String _opDelete = 'delete';

  static bool _isDelete(Map<String, dynamic> item) => item['op'] == _opDelete;
  OfflineEventQueue._();

  static final OfflineEventQueue instance = OfflineEventQueue._();

  static const String _keyPrefix = 'blushy_offline_events_';

  /// At most one flush runs at a time, so a retry triggered while a flush is
  /// already in progress does not send the same items twice.
  bool _flushing = false;

  /// Number of writes waiting to reach the server, for a sync indicator.
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  String? get _storageKey {
    final userId = AuthStorage.getUserId();
    if (userId == null || userId.isEmpty) return null;
    return '$_keyPrefix$userId';
  }

  Future<List<Map<String, dynamic>>> _read() async {
    final key = _storageKey;
    if (key == null) return [];

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      // A corrupt queue is dropped rather than blocking every future write.
      return [];
    }
  }

  Future<void> _write(List<Map<String, dynamic>> items) async {
    final key = _storageKey;
    if (key == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items));
    pendingCount.value = items.length;
  }

  Future<void> load() async {
    pendingCount.value = (await _read()).length;
  }

  /// Records a write that could not reach the server.
  ///
  /// Replacing any existing entry with the same `clientEventId` keeps the
  /// queue idempotent locally too: tapping the same check-in twice offline
  /// leaves one item, holding the latest value.
  Future<void> enqueue({
    required String eventType,
    required Map<String, dynamic> payload,
    required String clientEventId,
    DateTime? timestamp,
    String source = 'manual',
  }) async {
    final items = await _read();
    items.removeWhere((item) => item['clientEventId'] == clientEventId);

    items.add({
      'eventType': eventType,
      'payload': payload,
      'clientEventId': clientEventId,
      'source': source,
      'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
    });

    // Bound the queue so a long offline stretch cannot grow without limit.
    // The oldest entries are dropped first.
    const maxItems = 500;
    final bounded = items.length > maxItems ? items.sublist(items.length - maxItems) : items;

    await _write(bounded);
  }

  /// Sends everything queued, in batches the sync endpoint accepts.
  ///
  /// Accepted and permanently rejected items are both removed: a payload the
  /// server refuses will never become valid, so retrying it forever would
  /// block everything behind it. Items that simply could not be delivered stay
  /// queued for the next attempt.
  /// Queues a delete of [eventType]'s events on [day] stamped up to [before].
  ///
  /// For a pick taken back with no connection: the server's copy cannot be
  /// removed now, so the removal waits here and runs on the next flush. One
  /// per type and day -- a second take-back of the same thing on the same
  /// day only moves [before] forward.
  Future<void> enqueueDelete({
    required String eventType,
    required DateTime day,
    required DateTime before,
  }) async {
    final items = await _read();
    final dayKey = _dayKey(day);
    items.removeWhere((item) =>
        _isDelete(item) &&
        item['eventType'] == eventType &&
        item['day'] == dayKey);
    items.add({
      'op': _opDelete,
      'eventType': eventType,
      'day': dayKey,
      'before': before.toUtc().toIso8601String(),
    });
    await _write(items);
  }

  static String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// How many deletes are waiting.
  Future<int> pendingDeletes() async => (await _read()).where(_isDelete).length;

  /// Drops queued events of [eventType] stamped on [day], and says how many.
  ///
  /// For a pick taken back before it ever reached the server: the event is
  /// still here, waiting for a connection, and sending it later would put
  /// back what she just removed. Matched by type and day rather than by
  /// idempotency key, because one metric can queue several keys in a day
  /// (each option has its own) and all of them are what she took back.
  Future<int> removeWhere({
    required String eventType,
    required DateTime day,
  }) async {
    final items = await _read();
    final before = items.length;
    items.removeWhere((item) {
      if (_isDelete(item)) return false;
      if (item['eventType'] != eventType) return false;
      final stamp = DateTime.tryParse(item['timestamp']?.toString() ?? '');
      if (stamp == null) return false;
      final local = stamp.toLocal();
      return local.year == day.year &&
          local.month == day.month &&
          local.day == day.day;
    });
    if (items.length != before) await _write(items);
    return before - items.length;
  }

  Future<OfflineFlushResult> flush() async {
    if (_flushing) return const OfflineFlushResult(skipped: true);

    final items = await _read();
    if (items.isEmpty) return const OfflineFlushResult(accepted: 0, rejected: 0);

    _flushing = true;
    try {
      var accepted = 0;
      var rejected = 0;
      var deleted = 0;
      final remaining = <Map<String, dynamic>>[];

      // Deletes first. They were made before any log still in the queue --
      // removeWhere cleared the logs that preceded them -- so replaying them
      // first keeps the order the actions happened in. A delete that cannot
      // reach the server stops the flush here: sending the logs past it
      // would reorder the day.
      final deletes = items.where(_isDelete).toList();
      final logs = items.where((item) => !_isDelete(item)).toList();
      for (var i = 0; i < deletes.length; i++) {
        final removed = await _replayDelete(deletes[i]);
        if (removed == null) {
          remaining
            ..addAll(deletes.sublist(i))
            ..addAll(logs);
          await _write(remaining);
          return OfflineFlushResult(deleted: deleted);
        }
        deleted += removed;
      }

      for (var start = 0; start < logs.length; start += 100) {
        final batch = logs.sublist(start, start + 100 > logs.length ? logs.length : start + 100);
        final result = await EventsApi.sync(batch);
        if (!result.isReady || result.data == null) {
          remaining.addAll(logs.sublist(start));
          break;
        }

        accepted += (result.data!['acceptedCount'] as int?) ?? 0;

        final rejectedItems = ApiParse.list(result.data!['rejected']);
        rejected += rejectedItems.length;

        if (rejectedItems.isNotEmpty && kDebugMode) {
          for (final item in rejectedItems) {
            debugPrint('[offline] dropped invalid queued event: ${item['error']}');
          }
        }
      }

      await _write(remaining);
      return OfflineFlushResult(accepted: accepted, rejected: rejected, deleted: deleted);
    } finally {
      _flushing = false;
    }
  }

  /// Runs one queued delete against the server. The number removed, or null
  /// where the server could not be asked -- in which case it stays queued.
  Future<int?> _replayDelete(Map<String, dynamic> item) async {
    final type = item['eventType']?.toString();
    final day = DateTime.tryParse(item['day']?.toString() ?? '');
    final before = DateTime.tryParse(item['before']?.toString() ?? '');
    if (type == null || day == null || before == null) {
      // Malformed: nothing sensible to replay, and keeping it would block
      // every later flush.
      return 0;
    }
    final startOfDay = DateTime(day.year, day.month, day.day);
    final listed = await EventsApi.list(
      eventTypes: [type],
      from: startOfDay,
      to: before,
      limit: 100,
    );
    if (!listed.isReady || listed.data == null) return null;
    var removed = 0;
    for (final event in listed.data!) {
      final result = await EventsApi.delete(event.eventId);
      if (!result.isReady) return null;
      removed++;
    }
    return removed;
  }

  /// Clears the queue for the current account. Used on sign-out so one
  /// person's unsent writes never replay under another account.
  Future<void> clear() async {
    final key = _storageKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    pendingCount.value = 0;
  }
}

@immutable
class OfflineFlushResult {
  final int accepted;
  final int rejected;

  /// Server events removed by replayed deletes.
  final int deleted;
  final bool skipped;

  const OfflineFlushResult({
    this.accepted = 0,
    this.rejected = 0,
    this.deleted = 0,
    this.skipped = false,
  });

  bool get didAnything => accepted > 0 || rejected > 0 || deleted > 0;
}
