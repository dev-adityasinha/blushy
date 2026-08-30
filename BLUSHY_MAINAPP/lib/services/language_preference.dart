import 'package:flutter/widgets.dart';

import '../core/storage.dart';

/// The language Sia replies in.
///
/// The header's "EN" chip was `onTap: () {}` -- a control that could not be
/// changed. The backend has always accepted a `languageCode` on chat and has
/// reviewed strings for each language below, so this makes the chip real.
///
/// Deliberately scoped to Sia rather than the whole interface: the app's own
/// copy has no translations, and switching the chrome to Hindi while every
/// label stayed English would be worse than leaving it alone.
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
      }
    } catch (_) {
      // A missing or unreadable preference is just English.
    }
  }

  static Future<void> set(String code) async {
    if (!supported.containsKey(code)) return;
    current.value = code;
    try {
      BlushyStorage.write(_key, {'languageCode': code});
    } catch (_) {
      // Kept for this session even if it could not be written.
    }
  }
}
