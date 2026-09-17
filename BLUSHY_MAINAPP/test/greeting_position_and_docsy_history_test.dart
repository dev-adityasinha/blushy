import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Three reports, all about something being where it should not be.
///
/// The greeting leads the page in every stage that lays itself out literally.
/// Menopause and perimenopause take their order from the server, and the
/// logging row is added *before* that loop on purpose -- an order that omits a
/// logging key would otherwise leave those stages with no way into the sheet.
/// The greeting was inside the loop, so it arrived after the notice and the
/// symptom sheet: she was greeted a third of the way down the page.
///
/// The greeting also carried a stock line -- "you don't have to do it alone",
/// "Understanding your body. Protecting your health." -- that said the same
/// thing to everyone every day.
///
/// And Docsy forgot. `getChatHistory()` caught every failure and returned an
/// empty list, so an expired session or a cold start (Render's free instance
/// takes up to ~27s to wake) was indistinguishable from a new conversation.
/// The screen then greeted her as if nothing had been said, and there was no
/// local copy to fall back on: `recent_sia_chats.json` was written and never
/// read back.
void main() {
  const stageDir = 'lib/features/home/presentation/stages/';

  String read(String p) => File(p).readAsStringSync();

  String stripComments(String source) => source
      .split(String.fromCharCode(10))
      .where((line) => !line.trimLeft().startsWith('//'))
      .join(String.fromCharCode(10));

  group('the greeting leads the page', () {
    test('in the two server-ordered stages it is rendered before logging', () {
      for (final f in ['menopause_dashboard.dart', 'perimenopause_dashboard.dart']) {
        final code = stripComments(read(stageDir + f));
        final greeting = code.indexOf('_buildEditorialGreeting(userName)');
        final logging = code.indexOf('LogSymptomsSection(stageKey:');
        expect(greeting, greaterThan(-1), reason: '$f: greeting not rendered directly');
        expect(logging, greaterThan(-1), reason: f);
        expect(greeting, lessThan(logging),
            reason: '$f still greets her below the symptom sheet');
      }
    });

    test('and is not rendered a second time from the server order', () {
      // It is emitted explicitly now, so the loop has to skip its key or the
      // greeting appears twice.
      final meno = stripComments(read('${stageDir}menopause_dashboard.dart'));
      expect(meno, contains("if (secKey == 'editorial_greeting') continue;"));

      final peri = stripComments(read('${stageDir}perimenopause_dashboard.dart'));
      expect(peri, contains("if (section != 'editorial_greeting')"));
    });

    test('every other stage already had it first, and still does', () {
      const literal = {
        'first_period_not_started_dashboard.dart': '_buildEditorialGreeting(context)',
        'first_period_started_dashboard.dart': '_buildEditorialGreeting(context)',
        'hormonal_health_dashboard.dart': '_buildEditorialGreeting(context)',
        'living_with_my_cycle_dashboard.dart': '_buildEditorialGreeting(context)',
        'pregnancy_dashboard.dart': '_buildEditorialGreeting(pc)',
        'postpartum_dashboard.dart': '_buildEditorialGreeting(pc)',
        'trying_to_conceive_dashboard.dart': '_buildEditorialGreeting(context)',
      };
      literal.forEach((file, call) {
        final code = stripComments(read(stageDir + file));
        final greeting = code.indexOf('children: [$call');
        final alt = code.indexOf(call);
        expect(alt, greaterThan(-1), reason: file);
        final logging = code.indexOf('LogSymptomsSection(stageKey:');
        if (logging > -1) {
          // The call site in the page body, not the method definition.
          final bodyCall = code.lastIndexOf(call, logging);
          expect(bodyCall, greaterThan(-1), reason: '$file: greeting is below logging');
        }
        expect(greeting, anyOf(greaterThan(-1), lessThan(0)));
      });
    });
  });

  group('the stock greeting paragraph is gone', () {
    test('no dashboard still says it', () {
      for (final f in Directory(stageDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_dashboard.dart'))) {
        final code = stripComments(f.readAsStringSync());
        expect(code.contains('have to do it alone'), isFalse, reason: f.path);
        expect(code.contains('Understanding your body. Protecting your health'),
            isFalse, reason: f.path);
      }
    });

    test('and the shared hero only shows a subtitle it was given', () {
      final hero = stripComments(read('lib/features/home/widgets/home_hero.dart'));
      expect(hero.contains('have to do it alone'), isFalse,
          reason: 'the stock line was the fallback for every caller');
      expect(hero, contains('if (subtitle != null && subtitle!.trim().isNotEmpty)'));
    });
  });

  group('Docsy remembers', () {
    late final String service;
    late final String screen;

    setUpAll(() {
      service = read('lib/services/api_sia_service.dart');
      screen = read('lib/features/sia/sia_screen.dart');
    });

    test('a failed fetch is not reported as an empty conversation', () {
      expect(service, contains('Future<List<Map<String, String>>?> getChatHistory()'));

      final start = service.indexOf('Future<List<Map<String, String>>?> getChatHistory()');
      final body = service.substring(start, service.indexOf('clearChatHistory', start));
      expect(body, contains('return null;'),
          reason: 'the failure path still claims there is no history');
    });

    test('the screen falls back to the last conversation it saw', () {
      // The fallback became a merge: the device copy is used when the fetch
      // fails, and folded in alongside the server's rows when it succeeds.
      expect(screen, contains('final cached = _cachedConversation();'));
      expect(screen, contains('final restored = history == null'));
      expect(screen, contains('? cached'));
      expect(screen, contains('List<Map<String, String>> _cachedConversation()'));
      expect(screen, contains("BlushyStorage.read('recent_sia_chats.json')"),
          reason: 'the cache was written and never read back');
    });

    test('and the cache is written after the reply, not only the question', () {
      final add = screen.indexOf('_messages.add(siaEntry);');
      expect(add, greaterThan(-1));
      expect(screen.substring(add, add + 200), contains('_cacheConversation();'),
          reason: 'a cache written before the answer loses the answer');
    });

    test('a restored message is not appended twice', () {
      // Two maps with equal contents are not `==` in Dart, so the old
      // `history.contains(m)` never matched.
      expect(screen.contains('!history.contains(m)'), isFalse);
      expect(screen, contains('bool _sameMessage('));
    });
  });
}
