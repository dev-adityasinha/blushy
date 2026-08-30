import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Records how many HTTP requests are in flight at once.
///
/// Concurrency is the thing under test, and it cannot be asserted from a
/// wall-clock total alone -- a fast machine makes sequential code look
/// parallel. So every response is held open for a fixed delay and the peak
/// number of simultaneously open requests is recorded directly.
class HttpConcurrencyProbe {
  HttpConcurrencyProbe({this.responseDelay = const Duration(milliseconds: 120)});

  final Duration responseDelay;

  int _inFlight = 0;
  int peakConcurrency = 0;
  final List<String> requestedPaths = [];

  void _open(String path) {
    requestedPaths.add(path);
    _inFlight++;
    if (_inFlight > peakConcurrency) peakConcurrency = _inFlight;
  }

  void _close() => _inFlight--;

  /// Runs [body] with every request served by this probe.
  Future<T> run<T>(Future<T> Function() body) {
    return HttpOverrides.runZoned(
      body,
      createHttpClient: (_) => _ProbeHttpClient(this),
    );
  }

  /// A body shaped enough for the caller to keep going past its null checks.
  static String bodyFor(String path) {
    if (path.endsWith('/auth/me')) {
      return jsonEncode({
        'user': {'userId': 'probe-user', 'email': 'probe@example.test', 'role': 'woman'}
      });
    }
    if (path.contains('/onboarding')) {
      return jsonEncode({'onboardingAnswers': <String, dynamic>{}});
    }
    // Everything else: a valid, empty-but-parseable envelope.
    return jsonEncode(<String, dynamic>{});
  }
}

class _ProbeHttpClient implements HttpClient {
  _ProbeHttpClient(this.probe);
  final HttpConcurrencyProbe probe;

  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _ProbeRequest(probe, url, method);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  void close({bool force = false}) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProbeRequest implements HttpClientRequest {
  _ProbeRequest(this.probe, this.uri, this.method) {
    probe._open(uri.path);
  }

  final HttpConcurrencyProbe probe;
  @override
  final Uri uri;
  @override
  final String method;

  @override
  final HttpHeaders headers = _ProbeHeaders();

  // Dio sets these on every request; without real fields the noSuchMethod
  // fallback throws and nothing is ever served.
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  bool bufferOutput = true;
  @override
  int contentLength = -1;
  @override
  Encoding encoding = utf8;

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }
  @override
  Future<void> flush() async {}
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {}
  @override
  void writeCharCode(int charCode) {}
  @override
  void writeln([Object? obj = '']) {}

  @override
  Future<HttpClientResponse> close() async {
    // Held open so overlapping requests are actually observable.
    await Future<void>.delayed(probe.responseDelay);
    probe._close();
    return _ProbeResponse(HttpConcurrencyProbe.bodyFor(uri.path));
  }

  @override
  Future<HttpClientResponse> get done => close();
  @override
  void add(List<int> data) {}
  @override
  void write(Object? obj) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Extends StreamView so every Stream method (cast, transform, listen) comes
/// from a real stream. Implementing them by hand meant Dio hit noSuchMethod on
/// whichever one it happened to call.
class _ProbeResponse extends StreamView<List<int>> implements HttpClientResponse {
  _ProbeResponse(String body)
      : super(Stream<List<int>>.fromIterable(
          [Uint8List.fromList(utf8.encode(body))],
        )) {
    _length = utf8.encode(body).length;
  }

  late final int _length;

  @override
  int get statusCode => 200;
  @override
  String get reasonPhrase => 'OK';
  @override
  int get contentLength => _length;
  @override
  HttpHeaders get headers => _ProbeHeaders();
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  List<Cookie> get cookies => const [];
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProbeHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {
    'content-type': ['application/json; charset=utf-8']
  };

  @override
  List<String>? operator [](String name) => _headers[name.toLowerCase()];
  @override
  String? value(String name) => _headers[name.toLowerCase()]?.first;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void forEach(void Function(String name, List<String> values) action) =>
      _headers.forEach(action);
  @override
  ContentType? get contentType => ContentType.json;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
