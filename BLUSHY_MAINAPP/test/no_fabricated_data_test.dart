import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app must not present invented data as the user's own.
///
/// This has been a recurring shape of bug rather than a one-off. Found and
/// removed in this pass:
///
///   * `_completedLessons` was seeded with "Understanding My Body", and the
///     server load calls `addAll` rather than replacing — so the seed never
///     cleared and every new account was told it had finished a lesson it had
///     never opened.
///   * `_sharedLessons` was seeded the same way, and is never persisted at
///     all, so it claimed a lesson had been shared with someone who never
///     received it.
///   * A reading time computed from the list position: `"${3 + (index * 2)}
///     min read"`. There is no duration behind those lessons — they are title
///     strings — so item one claimed three minutes and item two claimed five,
///     for no reason.
void main() {
  const dashboard =
      'lib/features/home/presentation/stages/everyday_wellness_dashboard.dart';

  test('progress state does not start pre-populated', () {
    final source = File(dashboard).readAsStringSync();

    final seeded = RegExp(
      r'final Set<String> _(completed|shared)\w*\s*=\s*\{\s*[\x27"]',
    ).allMatches(source).map((m) => m[0]).toList();

    expect(seeded, isEmpty,
        reason: 'progress must come from the user or the server, never a literal');
  });

  test('nothing shown to the user is derived from a list index', () {
    final source = File(dashboard).readAsStringSync();

    // A value computed from position is not a fact about the thing it labels.
    final derived = RegExp(r'"\$\{[^}]*\bindex\b[^}]*\}\s*(min|day|week|hour)')
        .allMatches(source)
        .map((m) => m[0])
        .toList();

    expect(derived, isEmpty,
        reason: 'a duration or count derived from position is invented: $derived');
  });

  test('pre-made bouquets are not described as other people\'s', () {
    // The gallery is a hardcoded list. There is no public bouquet endpoint,
    // and describing it as what "people have made" made it look like real
    // user content.
    final source = File(
      'lib/features/partner/digibouquet/screens/garden_screen.dart',
    ).readAsStringSync();

    expect(source.contains('people have made'), isFalse,
        reason: 'these are pre-made designs, not other users\' bouquets');
  });
}
