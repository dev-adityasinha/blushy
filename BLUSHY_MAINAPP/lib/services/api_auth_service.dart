import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../features/auth/presentation/auth_service.dart';
import 'api_base_url.dart';
import 'auth_storage.dart';
import 'offline_event_queue.dart';
import 'log_redaction.dart';

class ApiAuthService implements AuthService {
  late final Dio _dio;

  ApiAuthService({Dio? dio, String? baseUrl}) {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: baseUrl ?? resolveApiBaseUrl(),
            connectTimeout: const Duration(seconds: 35),
            receiveTimeout: const Duration(seconds: 35),
            headers: {'Content-Type': 'application/json'},
          ),
        );
  }

  @override
  Future<bool> signUpWithEmail(
    String email,
    String password, {
    String role = 'woman',
    String? displayName,
    String? phoneNumber,
    bool termsAccepted = true,
  }) async {
    try {
      final response = await _dio.post('/auth/send-email-verification', data: {
        'email': email,
        'password': password,
        'mode': 'signup',
        'role': role,
        'termsAccepted': termsAccepted,
        if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
        if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
      });

      debugPrint('BlushyAuth: signUpWithEmail ok (${shapeOf(response.data)})');
      // The verification code is deliberately not read out of the response.
      //
      // A development server returns it so somebody with no mail delivery can
      // still get past the screen; production does not (render.yaml sets
      // EMAIL_DELIVERY_FALLBACK_ENABLED=false). It used to be captured here
      // either way, then shown on the dialog and typed into the boxes -- which
      // makes the check ceremonial. A code proves someone owns an address only
      // because it arrives at that address; handing it back through the same
      // response and filling it in proves nothing at all.
      //
      // A developer who needs it reads it from the server log, where
      // `[DEV OTP CODE]` prints it outside production.
      return true;
    } on DioException catch (e) {
      final errorMsg = _extractErrorMessage(e);
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception(cleanErrorMessage(e));
    }
  }

  @override
  Future<bool> verifyCode(String email, String code) async {
    try {
      final response = await _dio.post('/auth/verify-email-code', data: {
        'email': email,
        'code': code,
      });

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final token = (data['token'] as String?) ?? (data['user']?['token'] as String?);
        final userId = (data['userId'] as String?) ?? (data['user']?['userId'] as String?);
        final role = (data['role'] as String?) ?? (data['user']?['role'] as String?) ?? 'woman';
        final isOnboardingCompleted = data['onboardingCompleted'] == true || (data['user'] is Map && data['user']['onboardingCompleted'] == true);

        if (token != null) {
          AuthStorage.saveSession(
            token: token,
            userId: userId,
            email: email,
            role: role,
            onboardingCompleted: isOnboardingCompleted,
          );
        }
      }
      return true;
    } on DioException catch (e) {
      final errorMsg = _extractErrorMessage(e);
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('Verification failed: ${e.toString()}');
    }
  }

  @override
  Future<bool> loginWithEmail(String email, String password, {String? role}) async {
    try {
      final response = await _dio.post('/auth/login-email', data: {
        'email': email,
        'password': password,
        if (role != null && role.isNotEmpty) 'role': role,
      });

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final token = (data['token'] as String?) ?? (data['user']?['token'] as String?);
        final userId = (data['userId'] as String?) ?? (data['user']?['userId'] as String?);
        final userRole = (data['role'] as String?) ?? (data['user']?['role'] as String?) ?? role ?? 'woman';
        final isOnboardingCompleted = data['onboardingCompleted'] == true || (data['user'] is Map && data['user']['onboardingCompleted'] == true);

        if (token != null) {
          AuthStorage.saveSession(
            token: token,
            userId: userId,
            email: email,
            role: userRole,
            onboardingCompleted: isOnboardingCompleted,
          );
        }
      }
      return true;
    } on DioException catch (e) {
      final errorMsg = _extractErrorMessage(e);
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<bool> loginWithGoogle(String idToken, {String role = 'woman'}) async {
    try {
      final response = await _dio.post('/auth/google', data: {
        'idToken': idToken,
        'role': role,
      });

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final token = data['token'] as String?;
        final userId = data['userId'] as String?;
        final email = data['email'] as String?;
        final userRole = data['role'] as String? ?? role;
        final isOnboardingCompleted = data['onboardingCompleted'] == true;

        if (token != null) {
          AuthStorage.saveSession(
            token: token,
            userId: userId,
            email: email,
            role: userRole,
            onboardingCompleted: isOnboardingCompleted,
          );
        }
      }
      return true;
    } on DioException catch (e) {
      final errorMsg = _extractErrorMessage(e);
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('Google login failed: ${e.toString()}');
    }
  }

  /// Signs in (or creates an account) with an Apple identity token.
  ///
  /// Mirrors [loginWithGoogle]. Apple only returns the user's name on the very
  /// first authorization, so [givenName]/[familyName] are sent along with the
  /// token; the backend uses them only to fill a blank display name on first
  /// sign-in. Email lives in the token, so it need not be sent.
  Future<bool> loginWithApple(
    String identityToken, {
    String role = 'woman',
    String? givenName,
    String? familyName,
    String? email,
  }) async {
    try {
      final response = await _dio.post('/auth/apple', data: {
        'identityToken': identityToken,
        'role': role,
        if (givenName != null || familyName != null)
          'fullName': {
            'givenName': ?givenName,
            'familyName': ?familyName,
          },
        'email': ?email,
      });

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final token = data['token'] as String?;
        final userId = data['userId'] as String?;
        final userEmail = data['email'] as String?;
        final userRole = data['role'] as String? ?? role;
        final isOnboardingCompleted = data['onboardingCompleted'] == true;

        if (token != null) {
          AuthStorage.saveSession(
            token: token,
            userId: userId,
            email: userEmail,
            role: userRole,
            onboardingCompleted: isOnboardingCompleted,
          );
        }
      }
      return true;
    } on DioException catch (e) {
      final errorMsg = _extractErrorMessage(e);
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('Apple login failed: ${e.toString()}');
    }
  }

  /// Marks one day's journal as shared with a partner, or takes it back.
  ///
  /// The partner `journal` permission decides whether a partner may receive
  /// journal entries at all; this decides which days actually go. Both have to
  /// be on, so granting the category never releases a back catalogue.
  Future<bool> setJournalShared({required String entryDate, required bool shared}) async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return false;

    try {
      await _dio.put(
        '/auth/me/journal/$entryDate/share',
        data: {'shared': shared},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } on DioException catch (e) {
      debugPrint('BlushyBackend: Error sharing journal: ${_extractErrorMessage(e)}');
      return false;
    }
  }

  /// Same, for one Docsy exchange.
  Future<bool> setSiaConversationShared({
    required String conversationId,
    required bool shared,
  }) async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return false;

    try {
      await _dio.put(
        '/auth/me/sia-conversations/$conversationId/share',
        data: {'shared': shared},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } on DioException catch (e) {
      debugPrint('BlushyBackend: Error sharing conversation: ${_extractErrorMessage(e)}');
      return false;
    }
  }

  @override
  Future<bool> requestPasswordResetCode(String email) async {
    try {
      await _dio.post('/auth/send-password-reset-code', data: {'email': email});
      // The verification code is deliberately not read out of the response.
      //
      // A development server returns it so somebody with no mail delivery can
      // still get past the screen; production does not (render.yaml sets
      // EMAIL_DELIVERY_FALLBACK_ENABLED=false). It used to be captured here
      // either way, then shown on the dialog and typed into the boxes -- which
      // makes the check ceremonial. A code proves someone owns an address only
      // because it arrives at that address; handing it back through the same
      // response and filling it in proves nothing at all.
      //
      // A developer who needs it reads it from the server log, where
      // `[DEV OTP CODE]` prints it outside production.
      return true;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    } catch (e) {
      throw Exception('Could not send the reset code: ${e.toString()}');
    }
  }

  @override
  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
    required String confirmPassword,
    String? phoneNumber,
  }) async {
    try {
      await _dio.post('/auth/reset-password', data: {
        'email': email,
        'code': code,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
        if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
      });
      return true;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    } catch (e) {
      throw Exception('Reset password failed: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    final token = AuthStorage.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        await _dio.post(
          '/auth/logout',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      } catch (e) {
        debugPrint('BlushyAuth: Backend logout error (proceeding with local purge): $e');
      }
    }
    // Cleared before the session goes, while the queue key can still be
    // resolved: one account's unsent writes must never replay under another.
    await OfflineEventQueue.instance.clear();
    AuthStorage.clearSession();
  }

  Future<void> logout() => signOut();

  /// Permanently deletes the account and everything stored against it:
  /// `DELETE /auth/me`
  ///
  /// Returns true only when the server confirms the deletion. On success the
  /// local session is purged the same way [signOut] does, so the app cannot be
  /// left holding a token for an account that no longer exists.
  ///
  /// The typed confirmation is what the endpoint requires; it guards against an
  /// accidental call, not an unauthorised one, since the request is
  /// authenticated.
  Future<bool> deleteAccount() async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return false;

    try {
      final response = await _dio.delete(
        '/auth/me',
        data: {'confirm': 'DELETE'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode != 200) return false;
    } catch (e) {
      debugPrint('BlushyAuth: Account deletion failed: $e');
      return false;
    }

    // Only after the server has confirmed. Clearing first would strand the
    // account with no way back into it if the request had failed.
    await OfflineEventQueue.instance.clear();
    AuthStorage.clearSession();
    return true;
  }

  /// Sends frontend onboarding answers directly to the Node.js/Express backend API endpoint:
  /// `PUT /api/auth/me/onboarding`
  Future<Map<String, dynamic>> saveOnboardingAnswers(Map<String, dynamic> rawAnswers) async {
    final token = AuthStorage.getToken();

    // Map answers into strings required by backend format
    final Map<String, String> sanitized = {};

    rawAnswers.forEach((key, val) {
      if (val != null) {
        if (val is DateTime) {
          sanitized[key] = val.toIso8601String().split('T').first;
        } else if (val is List || val is Map) {
          sanitized[key] = jsonEncode(val);
        } else {
          sanitized[key] = val.toString();
        }
      }
    });

    debugPrint('BlushyBackend: Sending onboarding answers to backend: $sanitized');

    if (token == null || token.isEmpty) {
      debugPrint('BlushyBackend: No auth token present yet. Answers cached locally.');
      return {'status': 'cached_locally', 'answers': sanitized};
    }

    try {
      final response = await _dio.put(
        '/auth/me/onboarding',
        data: {'answers': sanitized},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      debugPrint('BlushyBackend: Onboarding saved (${shapeOf(response.data)})');
      return response.data is Map<String, dynamic> ? response.data : {'status': 'ok'};
    } on DioException catch (e) {
      debugPrint('BlushyBackend: Error saving onboarding to backend: ${_extractErrorMessage(e)}');
      // If error occurs (e.g. offline backend), rethrow or report
      rethrow;
    }
  }

  /// Exchanges the stored refresh token for a new access token.
  ///
  /// The refresh token was being saved at sign-in and never used, so once the
  /// access token expired every request simply started failing. Returns false
  /// when there is nothing to refresh with or the server rejects it, which is
  /// the only case where signing in again is genuinely required.
  Future<bool> refreshSession() async {
    final refreshToken = AuthStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data;
      if (data is! Map || data['token'] is! String) return false;

      AuthStorage.saveSession(
        token: data['token'] as String,
        refreshToken: data['refreshToken'] as String? ?? refreshToken,
        userId: data['userId'] as String? ?? AuthStorage.getUserId(),
        role: data['role'] as String?,
        onboardingCompleted: AuthStorage.isOnboardingCompleted(),
      );
      return true;
    } on DioException catch (e) {
      debugPrint('BlushyBackend: Token refresh failed: ${_extractErrorMessage(e)}');
      return false;
    }
  }

  /// Pushes one day's journal entries: `PUT /auth/me/journal`.
  ///
  /// Journals were stored on the device only, so a reinstall or a move between
  /// web and Android lost them. The server has held journal storage all along;
  /// nothing was writing to it.
  Future<bool> saveJournalForDate({
    required String entryDate,
    required List<Map<String, dynamic>> entries,
    String summary = '',
  }) async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return false;

    try {
      await _dio.put(
        '/auth/me/journal',
        data: {'entryDate': entryDate, 'entries': entries, 'summary': summary},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } on DioException catch (e) {
      debugPrint('BlushyBackend: Error saving journal: ${_extractErrorMessage(e)}');
      return false;
    }
  }

  /// The user's stored journals, newest first: `GET /auth/me/journal`.
  Future<List<Map<String, dynamic>>> getJournals({int limit = 100}) async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return const [];

    try {
      final response = await _dio.get(
        '/auth/me/journal',
        queryParameters: {'limit': limit},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final raw = response.data is Map
          ? (response.data['journals'] as List? ?? const [])
          : const [];
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } on DioException catch (e) {
      debugPrint('BlushyBackend: Error loading journals: ${_extractErrorMessage(e)}');
      return const [];
    }
  }

  /// Fetches onboarding answers from backend `GET /api/auth/me/onboarding`
  Future<Map<String, dynamic>> getOnboardingAnswers() async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) {
      return {};
    }

    try {
      final response = await _dio.get(
        '/auth/me/onboarding',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data['onboardingAnswers'] as Map<String, dynamic>? ?? {};
      }
      return {};
    } on DioException catch (e) {
      debugPrint('BlushyBackend: Error getting onboarding from backend: ${_extractErrorMessage(e)}');
      return {};
    }
  }

  /// Fetches onboarding questions schema from backend `GET /api/onboarding/questions?role=...`
  Future<List<Map<String, dynamic>>> getOnboardingQuestions({String role = 'woman'}) async {
    try {
      final response = await _dio.get('/onboarding/questions', queryParameters: {'role': role});
      if (response.data is Map<String, dynamic> && response.data['questions'] is List) {
        final List questionsList = response.data['questions'];
        return questionsList.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('BlushyBackend: Error getting onboarding questions: ${_extractErrorMessage(e)}');
      return [];
    }
  }

  /// Saves daily mood entry to backend `PUT /auth/me/daily-mood`
  Future<bool> saveDailyMood({
    required String mood,
    int score = 5,
    String? energyLevel,
    String? stressLevel,
    List<String>? symptoms,
  }) async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return false;
    try {
      final payload = <String, dynamic>{
        'mood': mood,
        'score': score,
      };
      if (energyLevel != null && energyLevel.isNotEmpty) payload['energyLevel'] = energyLevel;
      if (stressLevel != null && stressLevel.isNotEmpty) payload['stressLevel'] = stressLevel;
      if (symptoms != null && symptoms.isNotEmpty) payload['symptoms'] = symptoms;

      await _dio.put(
        '/auth/me/daily-mood',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (e) {
      debugPrint('BlushyBackend: Error saving daily mood: $e');
      return false;
    }
  }

  /// Fetches daily mood & wellbeing from backend `GET /auth/me/daily-mood`
  Future<Map<String, dynamic>> getMyDailyMood({String? date}) async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return {};
    try {
      final response = await _dio.get(
        '/auth/me/daily-mood',
        queryParameters: date != null ? {'date': date} : null,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('BlushyBackend: Error getting daily mood: $e');
      return {};
    }
  }

  /// Saves sleep log entry to backend `PUT /auth/me/sleep`
  Future<bool> saveSleepLog({required int durationMinutes, String sleepQuality = 'good'}) async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return false;
    try {
      await _dio.put(
        '/auth/me/sleep',
        data: {'durationMinutes': durationMinutes, 'sleepQuality': sleepQuality},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (e) {
      debugPrint('BlushyBackend: Error saving sleep log: $e');
      return false;
    }
  }

  /// Fetches latest sleep log from backend `GET /auth/me/sleep`
  Future<Map<String, dynamic>> getMySleep({String? date}) async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return {};
    try {
      final response = await _dio.get(
        '/auth/me/sleep',
        queryParameters: date != null ? {'date': date} : null,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('BlushyBackend: Error getting sleep log: $e');
      return {};
    }
  }

  /// Fetches sleep history from backend `GET /auth/me/sleep/history`
  Future<List<dynamic>> getMySleepHistory({int limit = 14}) async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return [];
    try {
      final response = await _dio.get(
        '/auth/me/sleep/history',
        queryParameters: {'limit': limit},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data is Map<String, dynamic> && response.data['history'] is List) {
        return response.data['history'] as List;
      }
      return [];
    } catch (e) {
      debugPrint('BlushyBackend: Error getting sleep history: $e');
      return [];
    }
  }

  /// Saves nutrition answers to backend `POST /auth/me/nutrition/answers`
  Future<bool> saveNutritionAnswers(Map<String, dynamic> answers) async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return false;
    try {
      await _dio.post(
        '/auth/me/nutrition/answers',
        data: answers,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (e) {
      debugPrint('BlushyBackend: Error saving nutrition answers: $e');
      return false;
    }
  }

  /// Generates custom AI nutrition plan `POST /auth/me/nutrition/generate-plan`
  Future<Map<String, dynamic>> generateNutritionPlan() async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return {};
    try {
      final response = await _dio.post(
        '/auth/me/nutrition/generate-plan',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('BlushyBackend: Error generating nutrition plan: $e');
      return {};
    }
  }

  /// Fetches complete user profile and data from backend endpoints:
  /// `GET /auth/me` and `GET /auth/me/onboarding`
  Future<Map<String, dynamic>> fetchUserData() async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return {};

    try {
      // Two independent reads, so they go out together. Awaiting the first
      // before starting the second doubled the latency of the very first
      // request the app makes after sign-in for no reason.
      final responses = await Future.wait([
        _dio.get(
          '/auth/me',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        ),
        _dio.get(
          '/auth/me/onboarding',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        ),
      ]);
      final meResponse = responses[0];
      final onboardingResponse = responses[1];

      final Map<String, dynamic> result = {};

      if (meResponse.data is Map<String, dynamic>) {
        final userData = meResponse.data['user'];
        if (userData is Map<String, dynamic>) {
          result['profile'] = userData;
        }
      }

      if (onboardingResponse.data is Map<String, dynamic>) {
        result['onboarding'] = onboardingResponse.data;
      }

      return result;
    } catch (e) {
      debugPrint('BlushyBackend: Error fetching user profile data: $e');
      return {};
    }
  }

  /// Fetches saved nutrition plan `GET /auth/me/nutrition/plan`
  Future<Map<String, dynamic>> getNutritionPlan() async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return {};
    try {
      final response = await _dio.get(
        '/auth/me/nutrition/plan',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('BlushyBackend: Error fetching nutrition plan: $e');
      return {};
    }
  }

  /// Saves weight log entry to backend `PUT /auth/me/weight`
  Future<bool> saveWeightLog(double weightKg, {String? date}) async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return false;
    try {
      await _dio.put(
        '/auth/me/weight',
        data: {
          'weightKg': weightKg,
          'date': date ?? DateTime.now().toIso8601String(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (e) {
      debugPrint('BlushyBackend: Error saving weight log: $e');
      return false;
    }
  }

  /// Performs AI web search detailed explanation for a given topic and summary
  Future<String> getDetailedWebExplanation(String topic, String summary) async {
    final token = AuthStorage.getToken();
    try {
      final prompt = "Please perform an in-depth health & wellness web search synthesis for topic: '$topic'. "
          "Existing summary: '$summary'. "
          "Provide a clear, detailed 3-4 paragraph explanation covering: "
          "1) Physiological/biological mechanisms, "
          "2) How it impacts energy, stress, or cycle health, "
          "3) Actionable lifestyle recommendations, "
          "4) Key scientific/medical insights.";

      final response = await _dio.post(
        '/ai/chat',
        data: {
          'messages': [
            {'role': 'user', 'content': prompt}
          ]
        },
        options: Options(
          headers: token != null && token.isNotEmpty ? {'Authorization': 'Bearer $token'} : {},
        ),
      );

      if (response.data is Map<String, dynamic>) {
        final reply = response.data['reply'] ?? response.data['message'] ?? response.data['text'];
        if (reply is String && reply.trim().isNotEmpty) {
          return reply.trim();
        }
      }
    } catch (e) {
      debugPrint('BlushyBackend: Error fetching AI detailed explanation: $e');
    }
    return '';
  }


  /// How long is actually left on a 429, in words. Null for anything else.
  ///
  /// `Retry-After` and `RateLimit-Reset` are both seconds remaining, and the
  /// server sends both. Either will do; neither was being read.
  static String? _rateLimitMessage(DioException e) {
    final response = e.response;
    if (response?.statusCode != 429) return null;

    final header = response!.headers.value('retry-after') ??
        response.headers.value('ratelimit-reset');
    final seconds = int.tryParse(header?.trim() ?? '');
    if (seconds == null || seconds <= 0) {
      // Rate limited, but the server did not say for how long. Better than
      // repeating a window length that may have almost run out.
      return 'Too many attempts. Please wait a little and try again.';
    }

    if (seconds < 60) {
      return 'Too many attempts. Please try again in $seconds seconds.';
    }
    final minutes = (seconds / 60).ceil();
    return 'Too many attempts. Please try again in '
        '$minutes ${minutes == 1 ? 'minute' : 'minutes'}.';
  }

  String _extractErrorMessage(DioException e) {
    // A refusal for going too fast is worded from the clock, not the policy.
    // The server says "try again in 15 minutes" because that is the window it
    // is configured with -- but somebody fourteen minutes into it was being
    // told to wait fifteen more. `Retry-After` is what is actually left.
    final waitMessage = _rateLimitMessage(e);
    if (waitMessage != null) return waitMessage;

    if (e.response != null && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('error') && data['error'] is Map) {
          return data['error']['message'] as String? ?? 'Request failed';
        }
        if (data.containsKey('error') && data['error'] is String) {
          return data['error'] as String;
        }
        if (data.containsKey('message') && data['message'] is String) {
          return data['message'] as String;
        }
      } else if (data is String && data.isNotEmpty && !data.contains('<!DOCTYPE') && !data.contains('<html')) {
        return data;
      }
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Server connection timed out. Please check your internet connection and try again.';
    }

    if (e.type == DioExceptionType.connectionError) {
      // Names the host, so a report of this message says which backend the
      // build was pointed at; the sentence alone could not tell a wrong
      // base URL from a server that was down.
      return 'Unable to connect to server at ${e.requestOptions.uri.origin}. '
          'Please check if the backend server is running.';
    }

    final fullMsg = '${e.message ?? ''} ${e.error?.toString() ?? ''}';
    if (fullMsg.contains('XMLHttpRequest') ||
        fullMsg.contains('SocketException') ||
        fullMsg.contains('Network Error') ||
        fullMsg.contains('CORS') ||
        fullMsg.contains('Failed host lookup') ||
        fullMsg.contains('Connection refused') ||
        fullMsg.contains('ClientException') ||
        fullMsg.contains('onError callback')) {
      return 'Unable to connect to server at ${e.requestOptions.uri.origin}. '
          'Please check if the backend server is running.';
    }

    if (e.response?.statusCode != null) {
      final code = e.response!.statusCode;
      if (code! >= 500) {
        return 'Server error ($code). Please try again in a few moments.';
      }
      return 'Request failed ($code).';
    }

    return 'Unable to connect to server. Please check if the backend server is running.';
  }

  static String cleanErrorMessage(dynamic e) {
    if (e == null) return 'An unexpected error occurred.';
    String msg = e.toString();
    if (msg.startsWith('Exception: ')) {
      msg = msg.substring(11).trim();
    }
    if (msg.contains('XMLHttpRequest') ||
        msg.contains('SocketException') ||
        msg.contains('Network Error') ||
        msg.contains('CORS') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Connection refused') ||
        msg.contains('ClientException') ||
        msg.contains('onError callback') ||
        msg.contains('DioException')) {
      // A message that already names the host (from _extractErrorMessage)
      // is kept as it is; only a bare transport error is replaced.
      if (msg.contains('Unable to connect to server at ')) return msg;
      return 'Unable to connect to server. Please check if the backend server is running.';
    }
    return msg;
  }
}
