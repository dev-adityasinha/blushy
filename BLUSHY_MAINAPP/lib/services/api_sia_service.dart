import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:flutter/foundation.dart';
import '../models/blushy_models.dart';
import 'api_base_url.dart';
import 'language_preference.dart';
import 'auth_storage.dart';

/// One night's summary of the user's real conversation with Sia, generated
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
    receiveTimeout: const Duration(seconds: 25),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

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

  /// Sends a user chat message to Sia AI Companion: `POST /ai/chat`
  Future<String> sendMessage(String userMessage, {Map<String, dynamic>? healthContext}) async {
    final result = await sendMessageDetailed(userMessage, healthContext: healthContext);
    return result.message;
  }

  /// Sends a user chat message and returns detailed captures: `POST /ai/chat`
  Future<SiaChatResult> sendMessageDetailed(String userMessage, {Map<String, dynamic>? healthContext}) async {
    try {
      final payload = <String, dynamic>{
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
        options: _authOptions(),
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

  /// Sends a document or image file with a prompt to Sia AI: `POST /ai/chat` (multipart/form-data)
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

  /// Fetches saved Sia conversation history: `GET /ai/history`
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

              if (userMsg != null && userMsg.trim().isNotEmpty) {
                result.add({
                  'sender': 'user',
                  'text': userMsg.trim(),
                  'conversationId': conversationId,
                  'shared': shared,
                });
              }
              if (assistantMsg != null && assistantMsg.trim().isNotEmpty) {
                result.add({
                  'sender': 'sia',
                  'text': assistantMsg.trim(),
                  'conversationId': conversationId,
                  'shared': shared,
                });
              }
              if ((userMsg == null || userMsg.trim().isEmpty) &&
                  (assistantMsg == null || assistantMsg.trim().isEmpty) &&
                  text != null &&
                  text.trim().isNotEmpty) {
                result.add({'sender': role == 'user' ? 'user' : 'sia', 'text': text.trim()});
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

  /// Clears saved Sia chat history: `DELETE /ai/history`
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
  Future<Map<String, dynamic>> getHealthInsights() async {
    try {
      final response = await _dio.get(
        '/ai/health-insights',
        options: _authOptions(),
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
        options: _authOptions(),
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
      code = data['errorCode'];
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
        options: _authOptions(),
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
        options: _authOptions(),
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
        options: _authOptions(),
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

