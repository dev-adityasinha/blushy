import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/main.dart';
import 'package:flutter/material.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

void main() {
  // Each test process gets its own storage directory.
  useIsolatedStorage();

  testWidgets('Blushy OS Bootstrap Smoke Test', (WidgetTester tester) async {
    // The dashboard contains NetworkImages. The test binding answers all HTTP
    // with 400, which made this fail depending on whether the image error
    // surfaced before pumpAndSettle returned.
    await withTestImages(() async {
      await tester.pumpWidget(const BlushyApp());
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });

    // Verify that the Blushy MaterialApp initializes cleanly
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
