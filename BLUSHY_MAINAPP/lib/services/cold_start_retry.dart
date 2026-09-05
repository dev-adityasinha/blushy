import 'package:dio/dio.dart';

import 'api_warmup.dart';

/// One more try after a request ran into the API's cold start.
///
/// The service sleeps when idle, and the first request after that waits for
/// it to boot. For the Dio-based calls -- sign-in, sign-up, Docsy, community,
/// partner -- that wait ended in a timeout and a "connection" error on
/// screen, while the request itself was what had woken the service. This
/// waits for the launch-time wake-up ping to finish (see [ApiWarmup]) and
/// sends the request once more.
///
/// It only repeats what is safe to repeat. A connection timeout or error
/// means the request never reached the server, so any method may go again.
/// A receive timeout means it may well have been accepted, so only reads
/// are repeated: a sign-up code that timed out on the way back must not be
/// sent twice.
class ColdStartRetryInterceptor extends Interceptor {
  ColdStartRetryInterceptor({this.waitFor = const Duration(seconds: 60)});

  /// The longest a retry waits for the wake-up before going ahead anyway.
  final Duration waitFor;

  static const String _flag = 'coldStartRetried';

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (options.extra[_flag] == true || !_worthRetrying(err)) {
      handler.next(err);
      return;
    }

    // The failed attempt is usually what woke the service; give the ping,
    // or the service itself, a moment to finish coming up.
    try {
      await ApiWarmup.ready.timeout(waitFor);
    } catch (_) {
      // Waited as long as agreed; try regardless.
    }

    try {
      options.extra[_flag] = true;
      final dio = Dio(BaseOptions(
        baseUrl: options.baseUrl,
        connectTimeout: options.connectTimeout,
        receiveTimeout: options.receiveTimeout,
        sendTimeout: options.sendTimeout,
        headers: options.headers,
        responseType: options.responseType,
        contentType: options.contentType,
        validateStatus: options.validateStatus,
      ));
      if (adapterFor != null) dio.httpClientAdapter = adapterFor!;
      final response = await dio.fetch<dynamic>(options);
      ApiWarmup.noteAwake();
      handler.resolve(response);
    } on DioException catch (second) {
      handler.next(second);
    }
  }

  /// Tests only: the adapter the retry sends through.
  static HttpClientAdapter? adapterFor;

  static bool _worthRetrying(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.receiveTimeout:
        return err.requestOptions.method.toUpperCase() == 'GET';
      default:
        return false;
    }
  }
}
