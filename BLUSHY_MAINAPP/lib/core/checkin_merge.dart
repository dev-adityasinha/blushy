/// Whether a stored answer from the server may replace what is on the device.
///
/// The home page keeps today's check-in in three places, and they do not agree:
///
///  * `daily_checkin.json` on the device, written by every selector as she taps;
///  * today's events on the server, timestamped and filtered to today;
///  * the `daily_*` onboarding answers — a **partial mirror**, written by only
///    some selectors, never cleared, and carrying no per-metric date.
///
/// Measured on a real device, the mirror held values from days earlier while
/// the other two agreed with what she had actually picked. Applying it
/// unconditionally is what made her selections change on switching tabs: mood
/// Happy became Cramps, energy High became Medium, sleep 6-8h became <6h and
/// water 3L became 1L, because a tab change triggers the sync that reads it.
///
/// So the mirror is a fallback. It fills in a metric the device knows nothing
/// about — a fresh install, or an answer given on another device — and
/// otherwise defers to the device.
library;

/// Whether the server's value for one metric should be applied.
bool shouldApplyRemoteCheckin({
  required String? remoteValue,
  required String? deviceValue,
  DateTime? deviceAt,
  DateTime? remoteAt,
  bool editedThisSession = false,
}) {
  // Nothing to apply.
  final remote = remoteValue?.trim() ?? '';
  if (remote.isEmpty) return false;

  // A tap she made a moment ago always wins; the sync that carries this can
  // have left before it arrived.
  if (editedThisSession) return false;

  // The device has no answer for this metric, so there is nothing to lose.
  final device = deviceValue?.trim() ?? '';
  if (device.isEmpty) return true;

  // Both sides have one. Only a demonstrably newer server copy may replace it —
  // and an undated server copy is not demonstrably anything.
  if (remoteAt == null) return false;
  if (deviceAt == null) return true;
  return remoteAt.isAfter(deviceAt);
}
