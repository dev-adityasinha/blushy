import 'dart:convert';
import 'dart:typed_data';

import 'package:blushy_life_app/services/api_warmup.dart';
import 'package:blushy_life_app/services/cold_start_retry.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A request that ran into the API's cold start is sent once more -- where
/// that is safe -- after the wake-up ping has answered.
///
/// An adapter that fails the first call the way a sleeping instance does,
/// then answers, stands in for the network.
class _ColdAdapter implements HttpClientAdapter {
  _ColdAdapter(this.firstFailure);

  /// The failure type of the first call; later calls succeed.
  final DioExceptionType firstFailure;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls += 1;
    if (calls == 1) {
      throw DioException(requestOptions: options, type: firstFailure, message: 'cold');
    }
    return ResponseBody.fromString(jsonEncode({'ok': true, 'call': calls}), 200,
        headers: {'content-type': ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() {
    ApiWarmup.reset();
    ApiWarmup.clientOverride = MockClient((req) async => http.Response('{"ok":true}', 200));
  });
  tearDown(() {
    ColdStartRetryInterceptor.adapterFor = null;
    ApiWarmup.clientOverride = null;
    ApiWarmup.reset();
  });

  Dio client(_ColdAdapter adapter) {
    ColdStartRetryInterceptor.adapterFor = adapter;
    return Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(ColdStartRetryInterceptor(waitFor: const Duration(milliseconds: 50)));
  }

  test('a connection timeout is retried once and succeeds', () async {
    final adapter = _ColdAdapter(DioExceptionType.connectionTimeout);
    final res = await client(adapter).get<dynamic>('/auth/me');
    expect(res.statusCode, 200);
    expect(adapter.calls, 2);
    expect(ApiWarmup.awake, isTrue, reason: 'a reply proves the API is up');
  });

  test('a connection error on a POST is retried: the request never arrived', () async {
    final adapter = _ColdAdapter(DioExceptionType.connectionError);
    final res = await client(adapter).post<dynamic>('/auth/login-email', data: {'email': 'a@b.c'});
    expect(res.statusCode, 200);
    expect(adapter.calls, 2);
  });

  test('a receive timeout on a POST is not retried: it may have been accepted', () async {
    final adapter = _ColdAdapter(DioExceptionType.receiveTimeout);
    await expectLater(
      client(adapter).post<dynamic>('/auth/send-email-verification', data: {'email': 'a@b.c'}),
      throwsA(isA<DioException>().having((e) => e.type, 'type', DioExceptionType.receiveTimeout)),
    );
    expect(adapter.calls, 1);
  });

  test('a receive timeout on a GET is retried', () async {
    final adapter = _ColdAdapter(DioExceptionType.receiveTimeout);
    final res = await client(adapter).get<dynamic>('/ai/history');
    expect(res.statusCode, 200);
    expect(adapter.calls, 2);
  });

  test('a bad response is not retried', () async {
    final adapter = _ColdAdapter(DioExceptionType.badResponse);
    await expectLater(client(adapter).get<dynamic>('/x'), throwsA(isA<DioException>()));
    expect(adapter.calls, 1);
  });

  group('the wake-up ping', () {
    test('reports ready once the API answers', () async {
      ApiWarmup.ping();
      expect(await ApiWarmup.ready, isTrue);
      expect(ApiWarmup.awake, isTrue);
    });

    test('gives up quietly when it cannot reach the API', () async {
      ApiWarmup.reset();
      ApiWarmup.clientOverride = MockClient((req) async => throw http.ClientException('down'));
      ApiWarmup.ping();
      expect(await ApiWarmup.ready, isFalse);
    });

    test('is sent to the health route, once', () async {
      ApiWarmup.reset();
      final urls = <String>[];
      ApiWarmup.clientOverride = MockClient((req) async {
        urls.add(req.url.toString());
        return http.Response('{"ok":true}', 200);
      });
      ApiWarmup.ping();
      ApiWarmup.ping();
      await ApiWarmup.ready;
      expect(urls.length, 1);
      expect(urls.first, endsWith('/health'));
    });
  });
}
