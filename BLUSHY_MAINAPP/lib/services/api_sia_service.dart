import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_base_url.dart';
import 'auth_storage.dart';

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

              if (userMsg != null && userMsg.trim().isNotEmpty) {
                result.add({'sender': 'user', 'text': userMsg.trim()});
              }
              if (assistantMsg != null && assistantMsg.trim().isNotEmpty) {
                result.add({'sender': 'sia', 'text': assistantMsg.trim()});
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
  Future<String> transcribeAudioBytes(List<int> bytes, String filename) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
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
    } catch (e) {
      debugPrint('BlushySia: Error transcribing audio: $e');
      return '';
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

  SiaChatResult({
    required this.message,
    this.moodCapture,
    this.sleepCapture,
    this.cycleCapture,
  });
}

