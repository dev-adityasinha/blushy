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
class OfflineEventQueue {
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
  Future<OfflineFlushResult> flush() async {
    if (_flushing) return const OfflineFlushResult(skipped: true);

    final items = await _read();
    if (items.isEmpty) return const OfflineFlushResult(accepted: 0, rejected: 0);

    _flushing = true;
    try {
      var accepted = 0;
      var rejected = 0;
      final remaining = <Map<String, dynamic>>[];

      for (var start = 0; start < items.length; start += 100) {
        final batch = items.sublist(start, start + 100 > items.length ? items.length : start + 100);
        final result = await EventsApi.sync(batch);

        if (!result.isReady || result.data == null) {
          // Could not reach the server: keep this batch and stop trying.
          remaining.addAll(items.sublist(start));
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
      return OfflineFlushResult(accepted: accepted, rejected: rejected);
    } finally {
      _flushing = false;
    }
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
  final bool skipped;

  const OfflineFlushResult({this.accepted = 0, this.rejected = 0, this.skipped = false});

  bool get didAnything => accepted > 0 || rejected > 0;
}
