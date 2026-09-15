import 'package:flutter/widgets.dart';

import '../core/storage.dart';

/// The language Docsy replies in.
///
/// The header's "EN" chip was `onTap: () {}` -- a control that could not be
/// changed. The backend has always accepted a `languageCode` on chat and has
/// reviewed strings for each language below, so this makes the chip real.
///
/// Now drives the whole interface as well as Docsy: [current] is what
/// `MaterialApp.locale` reads, so changing it re-renders every localised
/// string, and it rides along on each request to Docsy so replies come back in
/// the same language.
class LanguagePreference {
  const LanguagePreference._();

  static const String _key = 'sia_language.json';

  /// Only languages the server actually has strings for. Offering more would
  /// silently fall back to English and look broken.
  static const Map<String, String> supported = {
    'en': 'English',
    'hi': 'हिन्दी',
    'bn': 'বাংলা',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'mr': 'मराठी',
    'kn': 'ಕನ್ನಡ',
  };

  static const String fallback = 'en';

  /// Notifies listeners so the header chip updates the moment it changes.
  static final ValueNotifier<String> current = ValueNotifier<String>(fallback);

  static String get code => current.value;

  /// Whether the user has ever picked a language.
  ///
  /// Distinct from `code == 'en'`: someone who chose English and someone who
  /// has not chosen at all look identical in [current], and only the second
  /// should be asked. Kept in memory rather than re-read, so the picker cannot
  /// reappear mid-session if storage becomes unreadable.
  static bool hasChosen = false;

  static String labelFor(String code) => supported[code] ?? supported[fallback]!;

  /// Short label for the header chip.
  static String get shortLabel => code.toUpperCase();

  /// Picks the locale to render in.
  ///
  /// Flutter's default falls back to `supportedLocales.first`, and the
  /// generated list is alphabetical -- so an unrecognised locale landed on
  /// Bengali. English is the written source for every string, so it is the
  /// only sensible fallback. Shared with the app so a test exercises the same
  /// logic the app runs.
  static Locale resolveLocale(Locale? locale, Iterable<Locale> supported) {
    if (locale != null) {
      for (final candidate in supported) {
        if (candidate.languageCode == locale.languageCode) return candidate;
      }
    }
    return const Locale(fallback);
  }

  static void load() {
    try {
      final stored = BlushyStorage.read(_key);
      final code = stored['languageCode']?.toString();
      if (code != null && supported.containsKey(code)) {
        current.value = code;
        hasChosen = true;
      }
    } catch (_) {
      // A missing or unreadable preference is just English.
    }
  }

  static Future<void> set(String code) async {
    if (!supported.containsKey(code)) return;
    current.value = code;
    hasChosen = true;
    try {
      BlushyStorage.write(_key, {'languageCode': code});
    } catch (_) {
      // Kept for this session even if it could not be written.
    }
  }
}
