import 'package:blushy_life_app/features/partner/presentation/couple_experiences_sheet.dart';
import 'package:blushy_life_app/features/partner/presentation/shared_sanctuary_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SharedSanctuaryHeader renders You & Partner without duplicate PARTNER text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SharedSanctuaryHeader(
            hasConnection: true,
            partnerName: 'mithila',
            durationText: '2 weeks together',
            isPrivateSpaceActive: false,
            onInvite: () {},
            onManageConnection: () {},
            onOpenMessenger: () {},
          ),
        ),
      ),
    );

    // Should find You & mithila
    expect(find.textContaining('You &'), findsOneWidget);
    expect(find.textContaining('mithila'), findsOneWidget);

    // Should NOT find duplicate "PARTNER" eyebrow
    expect(find.text('PARTNER'), findsNothing);
    // Should find SHARING ACTIVE pill
    expect(find.text('SHARING ACTIVE'), findsOneWidget);
  });

  testWidgets('RightNowCard supports followUp event type with awaiting headline and CTAs', (tester) async {
    bool reminded = false;
    bool openedMessenger = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RightNowCard(
            type: RightNowEventType.followUp,
            partnerName: 'Mithila',
            headline: 'WAITING FOR MITHILA\'S REPLY',
            bodyText: 'You asked: “KYA HI HELLO BHEJ SS”',
            timeDisplay: '5 min ago',
            primaryCtaText: 'Remind Mithila',
            secondaryCtaText: 'Open Messenger',
            onPrimaryTap: () => reminded = true,
            onSecondaryTap: () => openedMessenger = true,
          ),
        ),
      ),
    );

    expect(find.text('WAITING FOR MITHILA\'S REPLY'), findsOneWidget);
    expect(find.text('You asked: “KYA HI HELLO BHEJ SS”'), findsOneWidget);
    expect(find.text('5 min ago'), findsOneWidget);
    expect(find.text('Remind Mithila'), findsOneWidget);
    expect(find.text('Open Messenger'), findsOneWidget);

    await tester.tap(find.text('Remind Mithila'));
    expect(reminded, isTrue);

    await tester.tap(find.text('Open Messenger'));
    expect(openedMessenger, isTrue);
  });

  testWidgets('showQuickFollowUpSheet displays screenshot reminder when lastMsg mentions ss', (tester) async {
    String? sentNudge;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showQuickFollowUpSheet(
                context,
                partnerName: 'Mithila',
                lastMsg: 'KYA HI HELLO BHEJ SS',
                onSendNudge: (txt) => sentNudge = txt,
              ),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Follow up with Mithila'), findsOneWidget);
    expect(find.textContaining('KYA HI HELLO BHEJ SS'), findsOneWidget);
    expect(find.text('Remind to send screenshot 📸'), findsOneWidget);
    expect(find.text('Playful Ping 👋'), findsOneWidget);
    expect(find.text('Gentle Thought ☕'), findsOneWidget);

    await tester.tap(find.text('Remind to send screenshot 📸'));
    await tester.pumpAndSettle();

    expect(sentNudge, contains('screenshot'));
  });

  testWidgets('showDatePlannerSheet opens and displays vibes and venue ideas', (tester) async {
    String? sentInvite;
    String? askedDocsy;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDatePlannerSheet(
                context,
                partnerName: 'Mithila',
                onSendInvite: (msg) => sentInvite = msg,
                onAskDocsy: (prompt) => askedDocsy = prompt,
              ),
              child: const Text('Plan Date'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Plan Date'));
    await tester.pumpAndSettle();

    expect(find.text('Plan a Date with Mithila'), findsOneWidget);
    expect(find.text('CHOOSE THE VIBE'), findsOneWidget);
    expect(find.text('Candlelight Dinner'), findsOneWidget);
    expect(find.text('Ask Docsy for Seat & Venue Ideas ✨'), findsOneWidget);

    // Send date invite
    await tester.tap(find.text('Send Date Invite to Mithila'));
    await tester.pumpAndSettle();
    expect(sentInvite, contains('DATE INVITATION'));

    // Reopen sheet and test Ask Docsy
    await tester.tap(find.text('Plan Date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask Docsy for Seat & Venue Ideas ✨'));
    await tester.pumpAndSettle();
    expect(askedDocsy, contains('seat booking'));
  });

  testWidgets('showCoupleGamesSheet allows shuffling questions and sending to chat', (tester) async {
    String? sentGame;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showCoupleGamesSheet(
                context,
                partnerName: 'Mithila',
                onSendGameQuestion: (msg) => sentGame = msg,
              ),
              child: const Text('Play Games'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Play Games'));
    await tester.pumpAndSettle();

    expect(find.text('Play Games with Mithila'), findsOneWidget);
    expect(find.text('Would You Rather?'), findsWidgets);
    expect(find.text('Shuffle Question'), findsOneWidget);

    await tester.tap(find.text('Send Question to Mithila in Chat'));
    await tester.pumpAndSettle();

    expect(sentGame, contains('COUPLE GAME'));
  });
}
