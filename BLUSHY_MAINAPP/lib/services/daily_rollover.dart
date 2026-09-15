import 'package:flutter/foundation.dart';

import '../core/storage.dart';
import 'offline_event_queue.dart';

/// Ends the day at midnight, and makes sure it reached the server.
///
/// `daily_checkin.json` carried a `date` and nothing ever read it to decide
/// whether the file was still today's. So the check-in kept showing yesterday's
/// answers as today's, the follow-up cards were generated from yesterday's
/// symptoms, and "Not logged" never came back — she appeared to have already
/// checked in every morning.
///
/// A check-in is filled in across a day rather than in one sitting, so the
/// close-out has to happen on its own rather than when a screen is opened:
/// answers are posted as they are given, and this is the sweep that catches
/// whatever the network refused at the time.
///
/// Nothing is deleted by rolling over. Every answer was already posted as an
/// event, and anything that could not be sent is in [OfflineEventQueue], which
/// survives a restart. The day's file is display state; the events are the
/// record.
class DailyRollover {
  const DailyRollover._();

  static const String _key = 'daily_checkin.json';

  /// Whether [storedIso] belongs to an earlier calendar day than [now].
  ///
  /// Compared in local time, deliberately. The person's day ends at their
  /// midnight, not UTC's, and a UTC comparison rolls the day over mid-evening
  /// for anyone east of Greenwich — which is most of this app's users.
  ///
  /// An unparseable or missing date is treated as stale: the file predates the
  /// stamp, so it cannot be today's.
  static bool isNewDay(String? storedIso, DateTime now) {
    if (storedIso == null || storedIso.trim().isEmpty) return true;
    final stored = DateTime.tryParse(storedIso);
    if (stored == null) return true;
    final local = stored.toLocal();
    return local.year != now.year ||
        local.month != now.month ||
        local.day != now.day;
  }

  /// How long until the next local midnight.
  ///
  /// Built from calendar components rather than by adding 24 hours, so the
  /// clocks going forward or back does not leave the rollover an hour out --
  /// `DateTime(y, m, d + 1)` is the next local midnight whatever happened to
  /// the offset in between, and it rolls month and year ends over on its own.
  ///
  /// A small buffer past the hour, because a timer that fires a few
  /// milliseconds early would still see yesterday's date and do nothing, then
  /// not run again until tomorrow.
  static Duration untilNextMidnight(DateTime now) {
    final nextMidnight = DateTime(now.year, now.month, now.day + 1)
        .add(const Duration(seconds: 5));
    final gap = nextMidnight.difference(now);
    // Never zero or negative: a timer scheduled for the past fires in a loop.
    return gap.isNegative || gap == Duration.zero
        ? const Duration(minutes: 1)
        : gap;
  }

  /// What survives into the new day.
  ///
  /// The cycle fields are not answers to "how are you today": they describe
  /// where she is in a cycle that does not restart at midnight, and the
  /// dashboard reads them to render before the network answers. Dropping them
  /// would blank the cycle card every morning.
  static const Set<String> carriedOver = {
    'lastPeriodStart',
    'cycleLength',
    'periodLength',
  };

  /// Rolls the day over if it needs it, and returns whether it did.
  ///
  /// The flush comes first: the queue may be holding answers from the day
  /// being closed, and they are worth more than the ordering is.
  static Future<bool> runIfNeeded({DateTime? now}) async {
    final today = now ?? DateTime.now();

    Map<String, dynamic> checkin;
    try {
      checkin = Map<String, dynamic>.from(BlushyStorage.read(_key));
    } catch (_) {
      // Nothing readable is nothing to roll over.
      return false;
    }

    if (checkin.isEmpty) return false;
    if (!isNewDay(checkin['date']?.toString(), today)) return false;

    // Whatever the network refused yesterday goes now.
    try {
      await OfflineEventQueue.instance.load();
      await OfflineEventQueue.instance.flush();
    } catch (error) {
      // A failed flush must not block the rollover: the queue keeps the items
      // and tries again. Leaving yesterday on screen would be the worse of
      // the two failures.
      debugPrint('DailyRollover: could not flush before rollover: $error');
    }

    final fresh = <String, dynamic>{
      for (final key in carriedOver)
        if (checkin[key] != null) key: checkin[key],
    };

    try {
      BlushyStorage.write(_key, fresh);
    } catch (error) {
      debugPrint('DailyRollover: could not write the new day: $error');
      return false;
    }

    return true;
  }
}
