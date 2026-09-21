import 'dart:io' show Platform;

/// True when running under `flutter test` -- the test runner sets the
/// FLUTTER_TEST environment variable. Used to skip the network warm-up so unit
/// and widget tests never block on a real `/health` ping.
bool get isUnderFlutterTest => Platform.environment.containsKey('FLUTTER_TEST');
