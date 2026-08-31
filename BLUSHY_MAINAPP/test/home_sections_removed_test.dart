import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Discover is gone, and community lives on its own page.
///
/// Two things carried the Discover name and only one was obvious. The unused
/// `discover_section_widget.dart` was easy to find and delete, but the section
/// people actually saw was a `_buildLivingDiscover()` method buried in a
/// 13,000-line dashboard file, rendering a heading that read "DISCOVER". The
/// same file carried six community blocks.
///
/// Asserted against the source because these are layout calls with no seam to
/// test through: a widget test would have to build a whole stage dashboard,
/// which needs a signed-in user, a life stage and a backend.
void main() {
  const dashboard =
      'lib/features/home/presentation/stages/everyday_wellness_dashboard.dart';

  test('home dashboards render no Discover section', () {
    final source = File(dashboard).readAsStringSync();

    expect(
      RegExp(r'_build[A-Za-z]*Discover\w*\(').allMatches(source).map((m) => m[0]).toList(),
      isEmpty,
      reason: 'Discover was removed from the home page; do not reintroduce it here',
    );
    expect(
      source.contains('"DISCOVER"'),
      isFalse,
      reason: 'the DISCOVER heading is what users reported seeing',
    );
  });

  test('home dashboards render no community section', () {
    final source = File(dashboard).readAsStringSync();

    expect(
      RegExp(r'_build[A-Za-z]*Community\w*\(').allMatches(source).map((m) => m[0]).toList(),
      isEmpty,
      reason: 'community belongs on the community page, not on home',
    );
  });

  test('the community page itself is untouched and still routed', () {
    // Removing it from home must not remove it from the app.
    expect(File('lib/features/community/community_screen.dart').existsSync(), isTrue);

    final shell = File('lib/features/home/blushy_shell.dart').readAsStringSync();
    expect(
      shell.contains('BlushyCommunityScreen'),
      isTrue,
      reason: 'the community tab must still be reachable from the bottom navigation',
    );
  });
}
