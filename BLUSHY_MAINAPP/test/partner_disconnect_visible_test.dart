import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/features/partner/partner_screen.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// Does the Disconnect control actually appear once a partner is connected?
///
/// Reading the widget tree in the source is not an answer: the control sits
/// behind `hasConnection`, which is filled from the network, so the only
/// honest check is to render the real screen with a real connection in it.
///
/// The screen builds its own `ApiPartnerService`, which builds its own `Dio`,
/// so neither can be injected. Dio's default adapter goes through `HttpClient`
/// though, so the seam is `HttpOverrides`: the service, its parsing and the
/// widget all run untouched, and only the socket is answered from here.
class _FakeBackend extends HttpOverrides {
  _FakeBackend(this.connections);

  /// What `GET /partner/connections` returns.
  final List<Map<String, dynamic>> connections;

  /// Paths actually requested, so a silent change of endpoint is visible.
  final List<String> requested = [];

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _FakeClient(this) as HttpClient;
}

class _FakeClient implements HttpClient {
  _FakeClient(this.backend);
  final _FakeBackend backend;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    backend.requested.add(url.path);
    final body = url.path.endsWith('/partner/connections')
        ? {'connections': backend.connections}
        : <String, dynamic>{};
    return _FakeRequest(jsonEncode(body));
  }

  // Dio configures things this fake does not model -- idleTimeout, badCertificateCallback.
  // Absorbing them keeps the fake to the few members the request path uses,
  // rather than re-implementing HttpClient.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.payload);
  final String payload;

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  Future<HttpClientResponse> close() async => _FakeResponse(payload);

  @override
  void add(List<int> data) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  // Dio configures things this fake does not model -- idleTimeout, badCertificateCallback.
  // Absorbing them keeps the fake to the few members the request path uses,
  // rather than re-implementing HttpClient.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this.payload);
  final String payload;

  @override
  int get statusCode => 200;

  @override
  int get contentLength => utf8.encode(payload).length;

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  String get reasonPhrase => 'OK';

  @override
  List<Cookie> get cookies => const [];

  @override
  bool get persistentConnection => false;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(utf8.encode(payload)).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  // Dio configures things this fake does not model -- idleTimeout, badCertificateCallback.
  // Absorbing them keeps the fake to the few members the request path uses,
  // rather than re-implementing HttpClient.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = {
    HttpHeaders.contentTypeHeader: ['application/json; charset=utf-8'],
  };

  @override
  List<String>? operator [](String name) => _values[name.toLowerCase()];

  @override
  String? value(String name) => _values[name.toLowerCase()]?.first;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = ['$value'];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values.putIfAbsent(name.toLowerCase(), () => []).add('$value');
  }

  @override
  ContentType? get contentType => ContentType.json;

  @override
  int get contentLength => -1;

  @override
  set contentLength(int value) {}

  @override
  bool get chunkedTransferEncoding => false;

  @override
  set chunkedTransferEncoding(bool value) {}

  @override
  void forEach(void Function(String name, List<String> values) action) =>
      _values.forEach(action);

  // Dio configures things this fake does not model -- idleTimeout, badCertificateCallback.
  // Absorbing them keeps the fake to the few members the request path uses,
  // rather than re-implementing HttpClient.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _meId = 'me-user-id';
const _themId = 'them-user-id';

Map<String, dynamic> connection({
  String status = 'active',
  String? breakupRequestedBy,
}) =>
    {
      'connectionId': 'conn-1',
      'status': status,
      'userAId': _meId,
      'userBId': _themId,
      'partnerUserId': _themId,
      'partnerEmail': 'aarav@example.com',
      'partnerRole': 'man',
      'breakupRequestedByUserId': breakupRequestedBy,
      'permissionOwnerUserId': _meId,
      'permissions': <String, dynamic>{},
      'canManagePermissions': true,
      'viewerIsSender': true,
    };

void main() {
  useIsolatedStorage();

  Widget host() => BlushyOSProvider(
        notifier: BlushyOSState(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BlushyPartnerScreen(),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// Renders the portal for [role] with [conns] already connected.
  Future<_FakeBackend> renderPortal(
    WidgetTester tester,
    String role,
    List<Map<String, dynamic>> conns,
  ) async {
    AuthStorage.saveSession(
      token: 't',
      userId: _meId,
      email: 'me@example.com',
      role: role,
      onboardingCompleted: true,
    );

    final backend = _FakeBackend(conns);
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(host());
      await settle(tester);
    }, createHttpClient: backend.createHttpClient);
    return backend;
  }

  testWidgets('with no partner, the portal offers no disconnect',
      (tester) async {
    await renderPortal(tester, 'woman', const []);

    expect(
      find.text('Disconnect'),
      findsNothing,
      reason: 'nothing to disconnect from',
    );
  });

  for (final role in ['woman', 'man']) {
    testWidgets('$role sees Disconnect once connected', (tester) async {
      final backend = await renderPortal(tester, role, [connection()]);

      expect(
        backend.requested.any((p) => p.endsWith('/partner/connections')),
        isTrue,
        reason: 'the screen should have asked for its connections',
      );
      // Disconnect is safely located in the Manage Connection sheet, opened via Sharing Active button or Manage Connection footer
      final manageTrigger = find.byIcon(Icons.keyboard_arrow_down_rounded);
      if (manageTrigger.evaluate().isNotEmpty) {
        await tester.tap(manageTrigger.first);
      } else {
        await tester.tap(find.text('Manage Connection').first);
      }
      await tester.pumpAndSettle();
      expect(
        find.text('Disconnect Partner'),
        findsWidgets,
        reason: '$role must be able to end the connection from the portal',
      );
    });
  }

  testWidgets('nothing is ever described as pending', (tester) async {
    // Disconnecting was a request the other partner had to grant, so the one
    // who asked was shown "Disconnect pending" and left connected until they
    // agreed. Leaving is one person's decision now, and no state waits on
    // anybody. `breakup_pending` rows can still exist in older data; they must
    // not bring the wording back.
    await renderPortal(tester, 'woman', [
      connection(status: 'breakup_pending', breakupRequestedBy: _meId),
    ]);

    expect(find.text('Disconnect pending'), findsNothing);
    final manageTrigger = find.byIcon(Icons.keyboard_arrow_down_rounded);
    if (manageTrigger.evaluate().isNotEmpty) {
      await tester.tap(manageTrigger.first);
    } else {
      await tester.tap(find.text('Manage Connection').first);
    }
    await tester.pumpAndSettle();
    expect(find.text('Disconnect Partner'), findsWidgets);
  });

  testWidgets('the partner who was left is not asked to agree to anything',
      (tester) async {
    // They used to be shown a Disconnect they had to tap to complete someone
    // else's departure. It is already over; they are told, not asked.
    await renderPortal(tester, 'man', [
      connection(status: 'breakup', breakupRequestedBy: _themId),
    ]);

    expect(find.text('Disconnect pending'), findsNothing);
    expect(
      find.textContaining('asked to disconnect'),
      findsNothing,
      reason: 'there is no request to answer',
    );
  });
}
