import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_base_url.dart';
import 'auth_storage.dart';

/// Consent capture and withdrawal.
///
/// The onboarding wizard has always required the privacy policy and terms to
/// be ticked before it would continue, and has never recorded that they were.
/// The tick lived in a `setState` field and died with the widget. Under the
/// DPDP Act the company has to be able to demonstrate that consent was
/// obtained, and a screen that leaves no trace demonstrates nothing.
///
/// Everything here fails open. If the server cannot be reached, the app must
/// not conclude that consent is missing -- locking a paying user out of their
/// own health data because their train went into a tunnel would be a far worse
/// outcome than showing the consent screen one launch later than ideal.

/// The version of each legal document **this build ships**.
///
/// Sent with an acceptance so the record names the text the user actually saw.
/// The server compares these against the versions it holds and refuses an
/// acceptance that names an older one, rather than recording agreement to a
/// document that was never displayed. Keep in step with
/// `backend/src/domain/consent.js`, and with the text in
/// `lib/features/legal/legal_documents_screen.dart`.
const Map<String, String> kLegalDocumentVersions = {
  'privacy_policy': '1.0',
  'terms': '1.0',
  'medical_disclaimer': '1.0',
};

/// Why the app is being asked to collect consent again.
enum ConsentReason { neverGiven, withdrawn, documentsUpdated, unknown }

ConsentReason _reasonFromString(String? raw) {
  switch (raw) {
    case 'never_given':
      return ConsentReason.neverGiven;
    case 'withdrawn':
      return ConsentReason.withdrawn;
    case 'documents_updated':
      return ConsentReason.documentsUpdated;
    default:
      return ConsentReason.unknown;
  }
}

class ConsentStatus {
  const ConsentStatus({
    required this.hasConsent,
    required this.needsConsent,
    this.reason,
    this.grantedAt,
    this.withdrawnAt,
    this.acceptedVersions,
  });

  final bool hasConsent;
  final bool needsConsent;
  final ConsentReason? reason;
  final DateTime? grantedAt;
  final DateTime? withdrawnAt;
  final Map<String, String>? acceptedVersions;

  factory ConsentStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? value) {
      if (value is! String || value.isEmpty) return null;
      return DateTime.tryParse(value)?.toLocal();
    }

    Map<String, String>? versions(Object? value) {
      if (value is! Map) return null;
      return value.map((key, val) => MapEntry('$key', '$val'));
    }

    return ConsentStatus(
      hasConsent: json['hasConsent'] == true,
      needsConsent: json['needsConsent'] == true,
      reason: _reasonFromString(json['reason'] as String?),
      grantedAt: parse(json['grantedAt']),
      withdrawnAt: parse(json['withdrawnAt']),
      acceptedVersions: versions(json['acceptedVersions']),
    );
  }
}

/// What went wrong, where the caller needs to tell them apart.
enum ConsentFailure {
  /// The server could not be reached, or answered with something unusable.
  /// The caller must carry on rather than block.
  unreachable,

  /// The documents this build ships are older than the ones in force, so the
  /// user cannot be shown what they would be agreeing to. Only an app update
  /// fixes it.
  appOutOfDate,
}

class ConsentResult {
  const ConsentResult.ok(this.status)
      : failure = null,
        message = null;

  const ConsentResult.failed(this.failure, {this.message}) : status = null;

  final ConsentStatus? status;
  final ConsentFailure? failure;
  final String? message;

  bool get succeeded => status != null;
}

class ApiConsentService {
  ApiConsentService({Dio? dio, String? baseUrl}) {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: baseUrl ?? resolveApiBaseUrl(),
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            headers: {'Content-Type': 'application/json'},
          ),
        );
  }

  late final Dio _dio;

  Options? _authOptions() {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return null;
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// Which platform the acceptance came from, as part of the record.
  static String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  /// Supplied at build time with `--dart-define=APP_VERSION=1.2.3`.
  /// Left out of the record rather than guessed when it is not.
  static const String _appVersion = String.fromEnvironment('APP_VERSION');

  /// The user's current consent, or `null` if it could not be determined.
  ///
  /// `null` means "unknown", never "missing". Callers deciding whether to show
  /// the consent screen must treat it as "carry on".
  Future<ConsentStatus?> fetchStatus() async {
    final options = _authOptions();
    if (options == null) return null;

    try {
      final response = await _dio.get('/auth/me/consent', options: options);
      final data = response.data;
      if (response.statusCode != 200 || data is! Map) return null;
      return ConsentStatus.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('BlushyConsent: could not read consent status: $e');
      return null;
    }
  }

  /// Records that the user accepted the documents this build ships.
  ///
  /// [method] is `onboarding` for a first acceptance, `re_consent` when the
  /// documents have changed, `settings` when granted again from settings.
  Future<ConsentResult> accept({String method = 'onboarding'}) async {
    final options = _authOptions();
    if (options == null) {
      return const ConsentResult.failed(ConsentFailure.unreachable);
    }

    try {
      final response = await _dio.post(
        '/auth/me/consent',
        data: {
          'documents': kLegalDocumentVersions,
          'method': method,
          'platform': _platform,
          if (_appVersion.isNotEmpty) 'appVersion': _appVersion,
        },
        options: options,
      );

      final data = response.data;
      if (data is Map && (response.statusCode == 201 || response.statusCode == 200)) {
        return ConsentResult.ok(ConsentStatus.fromJson(Map<String, dynamic>.from(data)));
      }
      return const ConsentResult.failed(ConsentFailure.unreachable);
    } on DioException catch (e) {
      // 409 is the one failure that is not transient: the server holds a newer
      // version of a document than this build can display, so retrying will
      // never succeed and the user needs a new build.
      if (e.response?.statusCode == 409) {
        final body = e.response?.data;
        return ConsentResult.failed(
          ConsentFailure.appOutOfDate,
          message: body is Map ? body['message']?.toString() : null,
        );
      }
      debugPrint('BlushyConsent: acceptance failed: $e');
      return const ConsentResult.failed(ConsentFailure.unreachable);
    } catch (e) {
      debugPrint('BlushyConsent: acceptance failed: $e');
      return const ConsentResult.failed(ConsentFailure.unreachable);
    }
  }

  /// Withdraws consent. Does not delete anything.
  Future<bool> withdraw({String? reason}) async {
    final options = _authOptions();
    if (options == null) return false;

    try {
      final response = await _dio.post(
        '/auth/me/consent/withdraw',
        data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
        options: options,
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('BlushyConsent: withdrawal failed: $e');
      return false;
    }
  }
}
