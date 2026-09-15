import 'dart:io';

import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/shared/bottom_navigation.dart';
import 'package:blushy_life_app/shared/docsy_avatar.dart';
import 'package:blushy_life_app/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Docsy's face is the brand artwork, not a redrawing of it.
///
/// It used to be 360 lines of hand-written path data attempting the reference
/// from memory: no eyebrows, a lumpy hair silhouette, a wobbling contour. The
/// artwork now ships as one asset.
///
/// The asset is a single-colour alpha shape -- every pixel the brand red, the
/// drawing carried in the alpha channel, the face left transparent so it takes
/// the surface behind it. That is what lets one file serve the active tab in
/// brand red and the inactive one in grey, through `BlendMode.srcIn`.

// The bar names its tabs from the localisations, so they have to be present.
Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

Image _imageIn(WidgetTester tester) =>
    tester.widget<Image>(find.byType(Image).first);

void main() {
  test('the artwork is on disk, under a directory pubspec already ships',
      () {
    final file = File('assets/docsy_icon.png');
    expect(file.existsSync(), isTrue,
        reason: '${DocsyAvatar.assetPath} is what the widget asks for');
    expect(file.lengthSync(), greaterThan(1000),
        reason: 'a truncated file would fail silently at the errorBuilder');

    // `assets/` is declared as a directory, so the file needs no new entry --
    // but if that line ever goes, the icon disappears with it.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('    - assets/\n'), isTrue,
        reason: 'the directory entry is what puts the icon in the bundle');
  });

  testWidgets('the icon draws the asset, tinted to the colour it is given',
      (tester) async {
    await tester.pumpWidget(_host(
      const DocsyIcon(size: 40, color: BlushyColors.primary),
    ));

    final image = _imageIn(tester);
    expect((image.image as AssetImage).assetName, DocsyAvatar.assetPath);
    expect(image.color, BlushyColors.primary);
    expect(image.colorBlendMode, BlendMode.srcIn,
        reason: 'srcIn repaints the shape and keeps its edges; a plain '
            'modulate would leave the artwork its own red');
  });

  testWidgets('the inactive tab gets the same face in grey', (tester) async {
    // One asset, two states. If the tint stopped applying, the inactive tab
    // would sit there in brand red next to four grey ones.
    const grey = Color(0xFF645A60);
    await tester.pumpWidget(_host(const DocsyIcon(size: 22, color: grey)));

    expect(_imageIn(tester).color, grey);
  });

  testWidgets('the Docsy tab wears it, in the brand red when active',
      (tester) async {
    await tester.pumpWidget(_host(
      BlushyBottomNavigation(
        currentIndex: BlushyBottomNavigation.siaIndex,
        onTap: (_) {},
      ),
    ));
    await tester.pump();

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(1), reason: 'one tab is Docsy, so one face');
    expect((images.first.image as AssetImage).assetName,
        DocsyAvatar.assetPath);
    expect(images.first.color, const Color(0xFFDD0D22),
        reason: 'the active brand red, which is BlushyColors.primary');
  });

  testWidgets('a missing asset degrades to an icon rather than a red box',
      (tester) async {
    // The bundle in a widget test is not the bundle on a phone. A tab icon is
    // never the reason a screen fails to draw, so the fallback is pinned.
    await tester.pumpWidget(_host(const DocsyIcon(size: 24)));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
