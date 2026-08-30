import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/features/journal/repository/journal_repository.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:blushy_life_app/services/journal_quick_entry.dart';

import 'helpers/isolated_storage.dart';

/// A voice reflection used to be saved with `BlushyOSState.addJournal`, which
/// appends to a list whose only reader lives in `lib/presentation/` -- code
/// nothing imports any more. The entry was written to disk and then displayed
/// nowhere, which is indistinguishable from a save that failed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedStorage();

  group('JournalQuickEntry', () {
    setUpAll(() {
      // These cover local persistence. The account push is fire and forget, so
      // leaving it on made the outcome depend on whether a dev server was
      // listening on this machine.
      JournalQuickEntry.syncToAccount = false;
    });

    tearDownAll(() {
      JournalQuickEntry.syncToAccount = true;
    });

    setUp(() {
      // The journal key is private, so BlushyStorage refuses to write it
      // without a session. That is the behaviour under test below.
      AuthStorage.saveSession(token: 'test-token', userId: 'journal_test_user');
    });

    tearDown(AuthStorage.clearSession);

    test('a reflection lands in the store the journal screen reads', () async {
      final saved = await JournalQuickEntry.save(
        text: 'I felt steadier today than I expected to.',
        title: 'Voice Reflection',
      );
      expect(saved, isTrue);

      // 'default_user' is the suffix the journal screen itself uses; reading
      // any other key is what "saved but invisible" looked like.
      final entries = await JournalRepository().getAllEntries('default_user');
      expect(entries, hasLength(1));
      expect(entries.first.title, 'Voice Reflection');
      expect(entries.first.body, contains('steadier'));
    });

    test('the entry carries the rawJson the loader requires', () async {
      await JournalQuickEntry.save(text: 'A quiet evening.', title: 'Voice Reflection');

      final entry = (await JournalRepository().getAllEntries('default_user')).first;
      // The journal screen skips any entry whose rawJson is missing or empty,
      // so a reflection without it would still never appear.
      expect(entry.rawJson, isNotNull);
      expect(entry.rawJson, isNotEmpty);
      expect(entry.rawJson, contains('"type":"text"'));
      expect(entry.rawJson, contains('A quiet evening.'));
    });

    test('a reflection is not reported as saved when it was not written', () async {
      // Without a session the private write is skipped silently. Reporting
      // success there is what made a lost reflection look like a saved one.
      AuthStorage.clearSession();

      final saved = await JournalQuickEntry.save(
        text: 'This should not be claimed as saved.',
        title: 'Voice Reflection',
      );
      expect(saved, isFalse);
    });

    test('an empty reflection is refused rather than stored blank', () async {
      final saved = await JournalQuickEntry.save(text: '   ', title: 'Voice Reflection');
      expect(saved, isFalse);
      expect(await JournalRepository().getAllEntries('default_user'), isEmpty);
    });

    test('two reflections saved in the same millisecond are both kept', () async {
      // Ids were built from the millisecond alone, so two quick saves collided
      // and the second was treated as an edit of the first.
      final now = DateTime.now();
      await JournalQuickEntry.save(text: 'First.', title: 'Voice Reflection', when: now);
      await JournalQuickEntry.save(text: 'Second.', title: 'Voice Reflection', when: now);

      final entries = await JournalRepository().getAllEntries('default_user');
      expect(entries, hasLength(2), reason: 'neither reflection may overwrite the other');
    });

    test('two reflections on the same day are both kept', () async {
      await JournalQuickEntry.save(text: 'Morning thought.', title: 'Voice Reflection');
      await JournalQuickEntry.save(text: 'Evening thought.', title: 'Voice Reflection');

      final entries = await JournalRepository().getAllEntries('default_user');
      expect(entries, hasLength(2));
      final bodies = entries.map((e) => e.body).toList();
      expect(bodies, containsAll(<String>['Morning thought.', 'Evening thought.']));
    });
  });
}
