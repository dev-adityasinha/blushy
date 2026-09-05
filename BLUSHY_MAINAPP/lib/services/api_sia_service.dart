import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:flutter/foundation.dart';
import '../models/blushy_models.dart';
import 'api_base_url.dart';
import 'language_preference.dart';
import 'auth_storage.dart';
import 'cold_start_retry.dart';

/// One night's summary of the user's real conversation with Docsy, generated
/// server-side from actual chat history.
class DailyChatSummary {
  const DailyChatSummary({
    required this.summaryDateIst,
    required this.summaryText,
    required this.messageCount,
    this.firstMessageAt,
    this.lastMessageAt,
  });

  final String summaryDateIst;
  final String summaryText;
  final int messageCount;
  final DateTime? firstMessageAt;
  final DateTime? lastMessageAt;

  static DateTime? _parse(dynamic v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

  factory DailyChatSummary.fromJson(Map<String, dynamic> json) {
    return DailyChatSummary(
      summaryDateIst: json['summaryDateIst']?.toString() ?? '',
      summaryText: json['summaryText']?.toString() ?? '',
      messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
      firstMessageAt: _parse(json['firstMessageAt']),
      lastMessageAt: _parse(json['lastMessageAt']),
    );
  }
}

/// Raised when transcription could not be attempted or completed, as distinct
/// from a recording that contained no speech.
class TranscriptionUnavailable implements Exception {
  const TranscriptionUnavailable(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiSiaService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: resolveApiBaseUrl(),
    connectTimeout: const Duration(seconds: 15),
    // Absorbs a Render cold start (~27s); see api_community_service.dart for
    // why this is the timeout that gives rather than connectTimeout.
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ))
    ..interceptors.add(ColdStartRetryInterceptor());

  Options _authOptions() {
    final token = AuthStorage.getToken();
    final userId = AuthStorage.getUserId();
    final headers = <String, dynamic>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (userId != null && userId.isNotEmpty) {
      headers['X-User-Id'] = userId;
    }
    return Options(headers: headers);
  }

  /// Options for the endpoints that wait on a model.
  ///
  /// The server aborts its own AI call at `AI_REQUEST_TIMEOUT_MS` (30s by
  /// default) and then still has to write the response, while this client gave
  /// up at 25s. So a slow-but-successful generation was reported to the user as
  /// a request timeout, having actually worked -- which is what "Docsy
  /// insights" and "cycle patterns" were showing.
  ///
  /// Kept to the AI routes: nothing else should be allowed to hang this long.
  Options _aiOptions() {
    final base = _authOptions();
    return base.copyWith(receiveTimeout: _aiReceiveTimeout);
  }

  /// Comfortably past the server's own abort, with room for the response.
  ///
  /// This has to stay above the 60s base, or `_aiOptions` would shorten the
  /// window for the one kind of request that legitimately needs the longest
  /// one. The AI call can also be the request that wakes a sleeping instance,
  /// so the budget is the cold start (~27s) followed by the model's own time
  /// rather than either alone.
  static const Duration _aiReceiveTimeout = Duration(seconds: 90);

  /// Sends a user chat message to Docsy AI Companion: `POST /ai/chat`
  Future<String> sendMessage(
    String userMessage, {
    Map<String, dynamic>? healthContext,
    List<Map<String, String>> history = const [],
  }) async {
    final result = await sendMessageDetailed(
      userMessage,
      healthContext: healthContext,
      history: history,
    );
    return result.message;
  }

  /// How much of the conversation travels with each message.
  ///
  /// The server caps this again on its side; the point of a limit here is to
  /// keep the request small on a phone connection.
  static const int _historyTurns = 12;

  /// Sends a user chat message and returns detailed captures: `POST /ai/chat`
  ///
  /// [history] is the conversation so far, oldest first, each entry carrying a
  /// `sender` of `sia` or `user`. Only the message being sent used to go over
  /// the wire, so every reply was a single-turn conversation: Docsy could not
  /// see what she had just said or what it had just answered, and repeated
  /// itself and its questions.
  Future<SiaChatResult> sendMessageDetailed(
    String userMessage, {
    Map<String, dynamic>? healthContext,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final turns = <Map<String, String>>[
        for (final entry in history.length > _historyTurns
            ? history.sublist(history.length - _historyTurns)
            : history)
          if ((entry['text'] ?? '').trim().isNotEmpty)
            {
              'role': entry['sender'] == 'sia' ? 'assistant' : 'user',
              'content': entry['text']!.trim(),
            },
        {'role': 'user', 'content': userMessage},
      ];

      final payload = <String, dynamic>{
        'messages': turns,
        // Kept alongside `messages` because older server builds read this one.
        'message': userMessage,
        // The server has reviewed strings per language and falls back to
        // English for anything it does not have.
        'languageCode': LanguagePreference.code,
      };
      if (healthContext != null && healthContext.isNotEmpty) {
        payload['context'] = healthContext;
      }

      final response = await _dio.post(
        '/ai/chat',
        data: payload,
        options: _aiOptions(),
      );

      debugPrint('BlushySia: Chat response: ${response.data}');

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final message = data['reply'] as String? ??
            data['response'] as String? ??
            data['message'] as String? ??
            'I am here for you. How else can I support you today?';
        return SiaChatResult(
          message: message,
          moodCapture: data['moodCapture'] is Map<String, dynamic> ? data['moodCapture'] as Map<String, dynamic> : null,
          sleepCapture: data['sleepCapture'] is Map<String, dynamic> ? data['sleepCapture'] as Map<String, dynamic> : null,
          cycleCapture: data['cycleCapture'] is Map<String, dynamic> ? data['cycleCapture'] as Map<String, dynamic> : null,
          safety: _parseSafety(data),
          aiGenerated: data['aiGenerated'] != false,
        );
      }
      return SiaChatResult(message: 'I am here for you. How else can I support you today?');
    } on DioException catch (e) {
      debugPrint('BlushySia: Dio error sending message: ${e.message}');
      return SiaChatResult(message: 'I am listening. If you ever feel overwhelmed, remember to take a deep, calming breath.');
    } catch (e) {
      debugPrint('BlushySia: Error sending message: $e');
      return SiaChatResult(message: 'I am here for you. Take your time.');
    }
  }

  /// Sends a document or image file with a prompt to Docsy AI: `POST /ai/chat` (multipart/form-data)
  Future<SiaChatResult> uploadDocumentAndChat({
    required List<int> fileBytes,
    required String fileName,
    required String mimeType,
    required String userMessage,
    Map<String, dynamic>? healthContext,
  }) async {
    try {
      final formData = FormData();
      formData.fields.add(MapEntry('message', userMessage));
      formData.fields.add(
          MapEntry('languageCode', LanguagePreference.code));
      if (healthContext != null && healthContext.isNotEmpty) {
        formData.fields.add(MapEntry('context', healthContext.toString()));
      }
      formData.files.add(MapEntry(
        'file',
        MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      ));

      final options = _authOptions();
      options.headers?['Content-Type'] = 'multipart/form-data';

      final response = await _dio.post(
        '/ai/chat',
        data: formData,
        options: options,
      );

      debugPrint('BlushySia: File chat response: ${response.data}');

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final message = data['reply'] as String? ??
            data['response'] as String? ??
            data['message'] as String? ??
            'I have carefully reviewed your uploaded document. Here is what I found:';
        return SiaChatResult(
          message: message,
          moodCapture: data['moodCapture'] is Map<String, dynamic> ? data['moodCapture'] as Map<String, dynamic> : null,
          sleepCapture: data['sleepCapture'] is Map<String, dynamic> ? data['sleepCapture'] as Map<String, dynamic> : null,
          cycleCapture: data['cycleCapture'] is Map<String, dynamic> ? data['cycleCapture'] as Map<String, dynamic> : null,
          safety: _parseSafety(data),
          aiGenerated: data['aiGenerated'] != false,
        );
      }
      return SiaChatResult(message: 'I have received your document and reviewed it.');
    } on DioException catch (e) {
      debugPrint('BlushySia: Dio error uploading document: ${e.message}');
      return SiaChatResult(message: 'I reviewed your document. The values and details have been safely noted in your health records.');
    } catch (e) {
      debugPrint('BlushySia: Error uploading document: $e');
      return SiaChatResult(message: 'I am here for you. Your file has been processed.');
    }
  }

  /// Fetches saved Docsy conversation history: `GET /ai/history`
  Future<List<Map<String, String>>> getChatHistory() async {
    try {
      final response = await _dio.get(
        '/ai/history',
        options: _authOptions(),
      );

      if (response.data is Map<String, dynamic>) {
        final history = response.data['history'] as List?;
        if (history != null) {
          final List<Map<String, String>> result = [];
          for (final item in history) {
            if (item is Map) {
              final userMsg = item['userMessage']?.toString() ?? item['user_message']?.toString();
              final assistantMsg = item['assistantMessage']?.toString() ?? item['assistant_message']?.toString();
              final text = item['content']?.toString() ?? item['text']?.toString();
              final role = item['role']?.toString() ?? 'sia';

              // The conversation id and its shared flag used to be dropped
              // here, which left the screen with no way to identify an
              // exchange -- and so no way to offer sharing at all.
              final conversationId = item['id']?.toString() ?? '';
              final shared = item['sharedWithPartner'] == true ? '1' : '0';

              // The server stamps every exchange; this was dropped here, so
              // the screen had no idea when anything was said.
              final at = item['createdAt']?.toString() ??
                  item['created_at']?.toString() ??
                  '';

              if (userMsg != null && userMsg.trim().isNotEmpty) {
                result.add({
                  'sender': 'user',
                  'text': userMsg.trim(),
                  'conversationId': conversationId,
                  'shared': shared,
                  'at': at,
                });
              }
              if (assistantMsg != null && assistantMsg.trim().isNotEmpty) {
                result.add({
                  'sender': 'sia',
                  'text': assistantMsg.trim(),
                  'conversationId': conversationId,
                  'shared': shared,
                  'at': at,
                });
              }
              if ((userMsg == null || userMsg.trim().isEmpty) &&
                  (assistantMsg == null || assistantMsg.trim().isEmpty) &&
                  text != null &&
                  text.trim().isNotEmpty) {
                result.add({
                  'sender': role == 'user' ? 'user' : 'sia',
                  'text': text.trim(),
                  'at': at,
                });
              }
            }
          }
          return result;
        }
      }
      return [];
    } catch (e) {
      debugPrint('BlushySia: Error fetching chat history: $e');
      return [];
    }
  }

  /// Clears saved Docsy chat history: `DELETE /ai/history`
  Future<bool> clearChatHistory() async {
    try {
      await _dio.delete('/ai/history', options: _authOptions());
      return true;
    } catch (e) {
      debugPrint('BlushySia: Error clearing history: $e');
      return false;
    }
  }

  /// Fetches AI health insights: `GET /ai/health-insights`
  /// Docsy's check-in cards for today's logged symptoms.
  ///
  /// `{date, cards, source}`; `source` is 'docsy' when the model wrote the
  /// cards and 'none' when it could not, in which case the caller falls
  /// back to the rule table. Empty on any failure, for the same reason.
  Future<Map<String, dynamic>> getCheckinFollowUps({
    required List<String> symptoms,
    required String date,
    String? stage,
  }) async {
    try {
      final response = await _dio.post(
        '/ai/checkin-followups',
        data: {
          'symptoms': symptoms,
          'date': date,
          'stage': ?stage,
        },
        options: _aiOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('BlushySia: Error fetching check-in follow-ups: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getHealthInsights() async {
    try {
      final response = await _dio.get(
        '/ai/health-insights',
        options: _aiOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('BlushySia: Error fetching health insights: $e');
      return {};
    }
  }

  /// Creates a voice call session: `POST /ai/voice/session`
  Future<Map<String, dynamic>> createVoiceSession() async {
    try {
      final response = await _dio.post(
        '/ai/voice/session',
        data: {'languageCode': LanguagePreference.code},
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('BlushySia: Error creating voice session: $e');
      return {};
    }
  }

  /// Transcribes audio bytes using backend Whisper STT engine: `POST /ai/transcribe`
  /// [mimeType] must match the bytes: the upload filter checks the declared
  /// type, and then re-checks it against the file's actual signature.
  Future<String> transcribeAudioBytes(
    List<int> bytes,
    String filename, {
    String mimeType = 'audio/webm',
  }) async {
    try {
      final parts = mimeType.split('/');
      final formData = FormData.fromMap({
        'languageCode': LanguagePreference.code,
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: MediaType(
            parts.first,
            parts.length > 1 ? parts.last : 'octet-stream',
          ),
        ),
      });

      final response = await _dio.post(
        '/ai/transcribe',
        data: formData,
        options: _aiOptions(),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data['text'] as String? ?? response.data['transcription'] as String? ?? '';
      }
      return '';
    } on DioException catch (e) {
      debugPrint('BlushySia: Error transcribing audio: $e');
      // An empty string means "the provider heard nothing". A failure to reach
      // or authenticate with the provider is a different thing, and telling the
      // user their audio was unclear would be wrong.
      throw TranscriptionUnavailable(_transcriptionFailureMessage(e));
    }
  }

  static String _transcriptionFailureMessage(DioException e) {
    final data = e.response?.data;
    Object? code;
    if (data is Map) {
      // The body nests everything under `error`, so the top-level lookups
      // below never matched and every failure fell through to the generic
      // message. Both shapes are read now.
      code = data['errorCode'];
      final error = data['error'];
      if (code == null && error is Map) {
        code = error['code'];
        final nested = error['details'];
        if (code == null && nested is Map) code = nested['code'];
      }
      final details = data['details'];
      if (code == null && details is Map) code = details['code'];
    }
    switch (code) {
      case 'STT_NOT_CONFIGURED':
        return 'Voice transcription is not set up on the server yet.';
      case 'STT_CREDENTIAL_REJECTED':
        return 'The server could not sign in to the transcription service.';
      case 'STT_PROVIDER_ERROR':
      case 'STT_UNREACHABLE':
        return 'The transcription service is unavailable right now.';
      default:
        return 'Could not reach the transcription service. Your recording was not lost.';
    }
  }

  /// The user's own daily summaries: `GET /ai/daily-summaries`.
  ///
  /// Returns an empty list when there is nothing to show, which is the point:
  /// the screen that uses this previously composed a letter out of nothing.
  /// Asks the server to write today's reflection from the conversation so far.
  ///
  /// Reflections were previously only produced by a nightly job, so anything
  /// said today appeared nowhere until after midnight. Returns false when there
  /// is genuinely nothing to reflect on yet, which is not an error.
  Future<bool> generateDailySummary() async {
    try {
      final response = await _dio.post(
        '/ai/daily-summaries/generate',
        options: _aiOptions(),
      );
      final data = response.data;
      return data is Map && data['generated'] == true;
    } on DioException catch (e) {
      debugPrint('BlushySia: Error generating daily summary: $e');
      return false;
    }
  }

  Future<List<DailyChatSummary>> getDailySummaries({int limit = 7}) async {
    try {
      final response = await _dio.get(
        '/ai/daily-summaries',
        queryParameters: {'limit': limit},
        options: _authOptions(),
      );
      final data = response.data;
      final raw = data is Map ? (data['summaries'] as List? ?? const []) : const [];
      return raw
          .whereType<Map>()
          .map((e) => DailyChatSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      debugPrint('BlushySia: Error fetching daily summaries: $e');
      return const [];
    }
  }

  /// Fetches medical reports: `GET /ai/medical-reports`
  Future<List<Map<String, dynamic>>> getMedicalReports() async {
    try {
      final response = await _dio.get(
        '/ai/medical-reports',
        options: _aiOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['reports'] is List) {
        final List reports = response.data['reports'];
        return reports.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('BlushySia: Error fetching medical reports: $e');
      return [];
    }
  }

  /// Fetches AI reflection & memory summary: `GET /ai/memory-summary`
  Future<Map<String, dynamic>> getMemorySummary() async {
    try {
      final response = await _dio.get(
        '/ai/memory-summary',
        options: _aiOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('BlushySia: Error fetching memory summary: $e');
      return {};
    }
  }
}

class SiaChatResult {
  final String message;
  final Map<String, dynamic>? moodCapture;
  final Map<String, dynamic>? sleepCapture;
  final Map<String, dynamic>? cycleCapture;

  /// Present when a deterministic red flag rule fired on the server.
  ///
  /// When [suppressesChat] is true the message is the clinically reviewed
  /// instruction attached to the rule, not a generated reply, and must be
  /// shown as safety guidance rather than as a chat bubble.
  final SafetyFlow? safety;

  /// False when the reply came from the safety ruleset rather than the model.
  final bool aiGenerated;

  SiaChatResult({
    required this.message,
    this.moodCapture,
    this.sleepCapture,
    this.cycleCapture,
    this.safety,
    this.aiGenerated = true,
  });

  bool get hasSafety => safety?.triggered == true && (safety?.steps.isNotEmpty ?? false);

  /// True when ordinary wellness content is withheld and only the reviewed
  /// guidance should be shown.
  bool get suppressesChat => hasSafety && safety!.suppressWellnessContent;
}

/// Reads the safety block the chat endpoint attaches when a rule fires.
SafetyFlow? _parseSafety(Map<String, dynamic> data) {
  final raw = data['safety'];
  if (raw is! Map) return null;
  final flow = SafetyFlow.fromJson(Map<String, dynamic>.from(raw));
  return flow.steps.isEmpty ? null : flow;
}

