import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/services/push_registration_service.dart';

/// Counts calls so an "unconfigured" build can be shown to make none.
class _CountingSource implements PushTokenSource {
  _CountingSource(this._token);
  final String? _token;
  int getTokenCalls = 0;

  @override
  Future<String?> getToken() async {
    getTokenCalls++;
    return _token;
  }

  @override
  Stream<String> get onTokenRefresh => const Stream<String>.empty();
}

void main() {
  group('push registration', () {
    test('with no provider configured, nothing registers and nothing throws', () async {
      final service = PushRegistrationService();

      await service.registerCurrentDevice();
      expect(service.isRegistered, isFalse);

      // Sign-out must stay safe even though sign-in registered nothing.
      await service.unregisterCurrentDevice();
      expect(service.isRegistered, isFalse);
    });

    test('a null token is asked for but never sent', () async {
      final source = _CountingSource(null);
      final service = PushRegistrationService(tokenSource: source);

      await service.registerCurrentDevice();

      expect(source.getTokenCalls, 1);
      expect(service.isRegistered, isFalse,
          reason: 'a null token must not be registered as if it were real');
    });

    test('an empty token is treated as absent, not as a valid device', () async {
      final service = PushRegistrationService(tokenSource: _CountingSource(''));
      await service.registerCurrentDevice();
      expect(service.isRegistered, isFalse);
    });

    test('the platform reported matches what the backend accepts', () {
      // The server rejects anything outside this set.
      expect(
        PushRegistrationService.resolvePlatform(),
        anyOf('android', 'ios', 'web'),
      );
    });
  });
}
