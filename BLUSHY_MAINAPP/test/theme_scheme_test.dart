import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blushy_life_app/main.dart';
import 'package:blushy_life_app/theme/colors.dart';

/// The app's colours, as Material resolves them.
///
/// Nothing here is about how a screen is painted by hand. It is about what
/// every widget that asks the theme for a colour gets back -- dialogs,
/// switches, sliders, the text cursor, snackbars. The app ran for a long time
/// with no scheme at all, which meant `useMaterial3: true` quietly handed all
/// of them Material's own baseline palette instead of Blushy's.
void main() {
  group('colour scheme', () {
    test('is not Material\'s baseline purple', () {
      // 0xFF6750A4 is the M3 default primary. If this ever comes back, the
      // scheme has been dropped from the theme again.
      expect(blushyColorScheme.primary, isNot(const Color(0xFF6750A4)));
      expect(blushyColorScheme.primary, BlushyColors.primary);
    });

    test('resolves surfaces and text to the palette', () {
      expect(blushyColorScheme.surface, BlushyColors.surface);
      expect(blushyColorScheme.onSurface, BlushyColors.text);
      expect(blushyColorScheme.onSurfaceVariant, BlushyColors.secondaryText);
      expect(blushyColorScheme.outline, BlushyColors.border);
    });

    test('white stays legible on the primary', () {
      // Guards the copyWith above: a seeded scheme picks its own onPrimary,
      // and pinning primary without it would be how you get red on red.
      final contrast = _contrastRatio(
        blushyColorScheme.onPrimary,
        blushyColorScheme.primary,
      );
      expect(contrast, greaterThan(4.5));
    });
  });

  group('dialogs', () {
    // Deliberately no dialogTheme here. A dialog with nothing set takes its
    // background from ColorScheme.surfaceContainerHigh, which is exactly how
    // it ended up lavender: with no scheme on the theme, that role came from
    // Material's baseline instead of the palette. Drop `colorScheme` from the
    // ThemeData below and this test goes red.
    testWidgets('open on the palette surface, not the Material baseline',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: blushyColorScheme,
          ),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(title: Text('Hello')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final dialog = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(dialog.color, BlushyColors.surface);
    });

    test('the baseline this replaces really is a different colour', () {
      // Guards the test above from passing for the wrong reason: if Material's
      // own surfaceContainerHigh ever happened to equal the palette's white,
      // dropping the scheme would no longer be detectable.
      final baseline = ThemeData(useMaterial3: true).colorScheme;
      expect(baseline.surfaceContainerHigh, isNot(BlushyColors.surface));
      expect(baseline.primary, const Color(0xFF6750A4));
    });
  });
}

/// WCAG relative-luminance contrast between two opaque colours.
double _contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

double _luminance(Color c) => c.computeLuminance();
