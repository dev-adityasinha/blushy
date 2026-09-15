import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/services/language_preference.dart';

import 'helpers/isolated_storage.dart';

/// The header's "EN" chip was `onTap: () {}` -- a control that could not be
/// changed. The backend has accepted a `languageCode` and carried reviewed
/// strings for these languages all along.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedStorage();

  group('LanguagePreference', () {
    setUp(() async {
      await LanguagePreference.set('en');
    });

    test('defaults to English', () {
      expect(LanguagePreference.code, 'en');
      expect(LanguagePreference.shortLabel, 'EN');
    });

    test('only offers languages the server actually has strings for', () {
      // Offering more would silently fall back to English and look broken.
      expect(
        LanguagePreference.supported.keys.toSet(),
        {'en', 'hi', 'bn', 'ta', 'te', 'mr', 'kn'},
      );
    });

    test('setting a language changes what is sent and shown', () async {
      await LanguagePreference.set('ta');

      expect(LanguagePreference.code, 'ta');
      expect(LanguagePreference.shortLabel, 'TA');
      expect(LanguagePreference.labelFor('ta'), 'தமிழ்');
    });

    test('an unsupported language is ignored rather than stored', () async {
      await LanguagePreference.set('hi');
      await LanguagePreference.set('zz');

      expect(LanguagePreference.code, 'hi', reason: 'an unknown code must not take effect');
    });

    test('the choice survives a reload', () async {
      await LanguagePreference.set('bn');

      // Simulate a fresh launch reading the stored value back.
      LanguagePreference.current.value = 'en';
      LanguagePreference.load();

      expect(LanguagePreference.code, 'bn');
    });

    test('listeners are notified so the header updates immediately', () async {
      final seen = <String>[];
      void listener() => seen.add(LanguagePreference.code);
      LanguagePreference.current.addListener(listener);

      await LanguagePreference.set('mr');
      LanguagePreference.current.removeListener(listener);

      expect(seen, contains('mr'));
    });
  });
}
