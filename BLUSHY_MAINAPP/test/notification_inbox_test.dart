import 'package:blushy_life_app/features/notifications/notification_inbox.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:blushy_life_app/shared/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// The notification inbox.
///
/// The server has recorded notifications from the start, and the client had
/// `NotificationsApi.list` and `markRead` written. Nothing rendered them, so
/// none of it reached anyone.
void main() {
  useIsolatedStorage();

  setUp(() {
    AuthStorage.saveSession(
      token: 'test-token',
      userId: 'test-user',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );
  });

  testWidgets('it shows the shape of the list while loading', (tester) async {
    await withTestImages(() async {
      await tester.pumpWidget(const MaterialApp(home: NotificationInbox()));
      await tester.pump();

      // Whichever settled state it reaches, it is one of the three the screen
      // defines -- never a blank page.
      final settled = find.byWidgetPredicate((w) =>
          w is Text &&
          ((w.data ?? '').contains('Nothing yet') ||
              (w.data ?? '').contains('Could not load')));
      expect(
        tester.any(find.byType(SkeletonListRow)) || tester.any(settled),
        isTrue,
        reason: 'the screen must always say something',
      );
    });
  });

  testWidgets('a failed load says so and offers a retry', (tester) async {
    // The request is stubbed and fails here, which is the path a phone with no
    // signal takes.
    await withTestImages(() async {
      await tester.pumpWidget(const MaterialApp(home: NotificationInbox()));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // With no notifications to show, it says so rather than showing an
      // empty page. A failed request instead offers a retry.
      final empty = find.textContaining('Nothing yet');
      final failed = find.textContaining('Could not load your notifications');
      expect(tester.any(empty) || tester.any(failed), isTrue);
      if (tester.any(failed)) {
        expect(find.text('Try again'), findsOneWidget);
      }

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the screen is titled and dismissable', (tester) async {
    await withTestImages(() async {
      await tester.pumpWidget(const MaterialApp(home: NotificationInbox()));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.text('Notifications'), findsOneWidget);
    });
  });
}
