import 'package:flutter/widgets.dart';

import '../core/state.dart';
import '../core/storage.dart';

/// The name to greet this user by, or a neutral address when it is not known.
///
/// Several stage dashboards each rolled their own version of this and read the
/// stored profile with keys that are never written:
///
/// ```dart
/// userName = decoded['name'] ?? decoded['profile']?['name'] ?? 'nithya';
/// ```
///
/// Onboarding writes `{'profile': {'preferredName': ...}}`, so neither
/// `name` nor `profile.name` ever exists. Every one of those lookups missed and
/// fell through to the literal, and three dashboards greeted every user in the
/// world as "nithya" while a fourth used "Ananya".
///
/// Resolution order, most authoritative first:
///
/// 1. `personalContext.userName`, which the app state fills from the server
///    profile and from onboarding, and refreshes on sign-in.
/// 2. The stored profile, checked under every key that has been written to it
///    across versions.
/// 3. [fallback] -- a form of address, never an invented name.
///
/// Pass a [fallback] that suits the surface: the pregnancy and postpartum
/// screens use "mama", which is a deliberate endearment rather than a guess at
/// who the user is.
String userDisplayName(BuildContext context, {String fallback = 'there'}) {
  // `get`, not `dependOn`.
  //
  // Two reasons. `BlushyOSProvider.of` asserts a provider exists, and these
  // dashboards used to render without one. And registering a dependency is
  // illegal before initState completes -- the pregnancy dashboard rebuilds
  // during its own initialisation, so `dependOnInheritedWidgetOfExactType`
  // there threw and took the whole screen down.
  //
  // The cost is that a greeting will not rebuild by itself the moment a name
  // arrives; it picks it up on the screen's next build, which these dashboards
  // do as soon as their data loads. A name appearing a frame late is a far
  // smaller problem than a screen that throws.
  final provider = context.getInheritedWidgetOfExactType<BlushyOSProvider>();
  final fromState = _clean(provider?.notifier?.personalContext.userName);
  if (fromState != null) return fromState;

  try {
    final stored = BlushyStorage.read('user_profile.json');
    final profile = stored['profile'];

    for (final candidate in <Object?>[
      stored['preferredName'],
      stored['name'],
      if (profile is Map) profile['preferredName'],
      if (profile is Map) profile['name'],
    ]) {
      final value = _clean(candidate?.toString());
      if (value != null) return value;
    }
  } catch (_) {
    // Storage not ready, or the file is unreadable. The fallback covers it.
  }

  return fallback;
}

/// The first word of [userDisplayName], for surfaces that address the user
/// informally and would look wrong with a full name.
String userFirstName(BuildContext context, {String fallback = 'there'}) {
  final name = userDisplayName(context, fallback: fallback);
  final first = name.trim().split(RegExp(r'\s+')).first;
  return first.isEmpty ? fallback : first;
}

/// A usable name, or null.
///
/// Returns the *cleaned* value rather than the original: leading punctuation
/// appears in some stored values and would render as ", Good morning". And
/// "Blushy User" is the placeholder the app writes when it has no real name,
/// so it must never be greeted as one.
String? _clean(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(RegExp(r'^[,.\s]+'), '').trim();
  if (cleaned.isEmpty || cleaned == 'Blushy User') return null;
  return cleaned;
}
