/// Where a tracker's value is stored so it is still there tomorrow.
///
/// The home page trackers wrote `{metric: 'HOT FLASHES', value: 'Mild', date:
/// ...}` into `answers['peri_log']`, and the loader read
/// `answers['peri_log']['hot_flashes']`. The two shapes never agreed, so no
/// tracker ever restored what it had recorded.
///
/// It could not have worked in any case: the endpoint stores a non-string
/// answer as `JSON.stringify(value)`, so the map arrived back as a *string* and
/// the `is Map` check that guarded every loader was false every time. The value
/// was written, mangled, and dropped.
///
/// Each metric now gets its own flat, string-valued key, which is what the
/// endpoint can actually store, and one shared function derives it for both the
/// writer and the reader so they cannot drift apart again.
library;

/// Prefix marking a key as a record of something she logged, not an answer to
/// a question. The gating skips these: a tracker writes its own label into the
/// answers, so without this a card that recorded a value would hold itself open
/// afterwards regardless of what she asked to track.
const String kTrackerLogPrefix = 'log_';

/// The storage key for one tracker metric.
///
/// Derived from the label shown above the control, so the writer and the reader
/// cannot disagree — `trackerLogKey('peri', 'HOT FLASHES')` is
/// `log_peri_hot_flashes` on both sides.
String trackerLogKey(String category, String label) {
  String slug(String raw) => raw
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  final c = slug(category).replaceAll(RegExp(r'_log$'), '');
  return '$kTrackerLogPrefix${c}_${slug(label)}';
}
