import 'package:flutter/foundation.dart';

import '../../core/storage.dart';
import '../../services/api_auth_service.dart';
import 'checkin_event_mapper.dart';
import 'symptom_categories.dart';

/// Which symptom categories she wants to keep.
///
/// A category switched off is not offered on the sheet, and nothing in it is
/// sent to the server -- so it takes no part in patterns, the care plan, the
/// doctor summary, the partner view or Docsy's context.
///
/// What this does *not* do is reach back for readings already sent. Anything
/// logged before the switch was turned off is still on the server, and the
/// sheet says so rather than implying an erasure that did not happen. Deleting
/// history is a different action with different consequences -- insights built
/// on those events would have to be invalidated -- and it belongs behind an
/// explicit "delete my data" control, not a display toggle.
class SymptomCategoryPreference {
  const SymptomCategoryPreference._();

  static const String _key = 'symptom_categories.json';

  /// Notifies the sheet and the check-in the moment a switch moves.
  static final ValueNotifier<Set<String>> disabled =
      ValueNotifier<Set<String>>(<String>{});

  static bool isEnabled(String category) => !disabled.value.contains(category);

  /// The categories [stage] is asked for and has not switched off.
  static List<SymptomCategory> enabledFor(String? stage) =>
      SymptomCategories.forStage(stage).where((c) => isEnabled(c.id)).toList();

  /// Whether [label] belongs to a category that is still switched on.
  ///
  /// A label in no category is kept: the opt-out is not part of a category and
  /// must not be dropped by a rule about categories.
  ///
  /// Note this asks only about the switch, not about the stage. A stage change
  /// hides a category from the sheet; it does not retract consent to what was
  /// already collected, and treating it as a retraction would silently drop
  /// entries someone made while the category was theirs to log.
  static bool allows(String key) {
    // Qualified or bare: a qualified key names its group; a bare word is
    // read as the first group that owns it, as it always was.
    final category = SymptomKey.category(key);
    return category == null || isEnabled(category.id);
  }

  /// [selected] with anything from a switched-off category removed.
  static Set<String> filter(Iterable<String> selected) =>
      selected.where(allows).toSet();

  /// What Docsy must not be told about, derived from the switches.
  ///
  /// Switching a category off stops it being collected, but readings taken
  /// before that are still on the server -- so without this they keep shaping
  /// what Docsy says about her. Sending the exclusion rather than deleting the
  /// rows keeps the promise the sheet actually makes.
  ///
  /// Derived here, from the one registry that knows which options belong to
  /// which category, and sent to the server. Working it out again on the
  /// server would be a second copy of that mapping, and the two would drift.
  ///
  /// Two lists because they answer different questions:
  ///
  ///  * a whole event type can go only when every category producing it is
  ///    switched off -- `sexual_activity_logged` has one producer, so
  ///    switching off Sex removes the type outright;
  ///  * `symptom_logged` has six producers, so switching off Digestion must
  ///    name its words rather than drop every symptom she has ever logged.
  static Map<String, List<String>> exclusionsForSync() {
    final producersByType = <String, Set<String>>{};
    final excludedByType = <String, Set<String>>{};
    final excludedSymptoms = <String>{};

    for (final category in SymptomCategories.all) {
      if (category.isNumeric) {
        // A reading has no options to walk; its metric names its event type.
        final type = category.numericId == 'bbt' ? 'bbt_logged' : 'weight_logged';
        producersByType.putIfAbsent(type, () => <String>{}).add(category.id);
        if (!isEnabled(category.id)) {
          excludedByType.putIfAbsent(type, () => <String>{}).add(category.id);
        }
        continue;
      }

      for (final option in category.options) {
        final event =
            CheckinEventMapper.map(category.metricFor(option), option);
        if (event == null) continue;

        producersByType
            .putIfAbsent(event.eventType, () => <String>{})
            .add(category.id);

        if (isEnabled(category.id)) continue;

        excludedByType
            .putIfAbsent(event.eventType, () => <String>{})
            .add(category.id);

        if (event.eventType == 'symptom_logged') {
          final name = event.payload['symptom']?.toString().toLowerCase();
          if (name != null && name.isNotEmpty) excludedSymptoms.add(name);
        }
      }
    }

    // Only a type nothing enabled still produces.
    final excludedTypes = <String>[
      for (final entry in excludedByType.entries)
        if (producersByType[entry.key]!.length == entry.value.length) entry.key,
    ];

    return {
      'symptom_consent_excluded_event_types': excludedTypes..sort(),
      'symptom_consent_excluded_symptoms': excludedSymptoms.toList()..sort(),
    };
  }

  static void load() {
    // The per-group switch was removed from the sheet. A preference that can
    // no longer be reached must not keep hiding groups, so anything stored
    // is cleared here and the empty exclusion list is synced -- Docsy's
    // context consent then matches what the sheet shows.
    try {
      final stored = BlushyStorage.read(_key)['disabled'];
      if ((stored is List && stored.isNotEmpty) || disabled.value.isNotEmpty) {
        disabled.value = <String>{};
        BlushyStorage.write(_key, {'disabled': const <String>[]});
        ApiAuthService()
            .saveOnboardingAnswers(exclusionsForSync())
            .catchError((_) => <String, dynamic>{});
      }
    } catch (_) {
      // An unreadable preference collects everything, which is the state the
      // app shipped in. It never silently switches a category off.
    }
  }

  static void setEnabled(String category, bool enabled) {
    final next = {...disabled.value};
    if (enabled) {
      next.remove(category);
    } else {
      next.add(category);
    }
    disabled.value = next;
    try {
      BlushyStorage.write(_key, {'disabled': next.toList()});
    } catch (_) {
      // Held for this session even if it could not be written.
    }

    // Withdrawing consent should take effect now, not at her next save.
    ApiAuthService()
        .saveOnboardingAnswers(exclusionsForSync())
        .catchError((_) => <String, dynamic>{});
  }
}
