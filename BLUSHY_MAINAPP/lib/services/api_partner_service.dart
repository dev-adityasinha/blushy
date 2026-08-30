import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_base_url.dart';
import 'auth_storage.dart';

/// A relationship activity whose state belongs to the connection, so both
/// partners see the same thing.
class SharedActivity {
  const SharedActivity({
    required this.key,
    required this.title,
    required this.description,
    required this.status,
    this.startedByUserId,
    this.completedByUserId,
    this.completedAt,
    this.completionCount = 0,
  });

  final String key;
  final String title;
  final String description;
  final String status; // not_started | in_progress | completed
  final String? startedByUserId;
  final String? completedByUserId;
  /// When the pair finished it. Returned by the server all along; the Memory
  /// Book needs it to order what they have actually done together.
  final DateTime? completedAt;
  final int completionCount;

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';

  factory SharedActivity.fromJson(Map<String, dynamic> json) {
    return SharedActivity(
      key: json['key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'not_started',
      startedByUserId: json['startedByUserId']?.toString(),
      completedByUserId: json['completedByUserId']?.toString(),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(json['completedAt'].toString()),
      completionCount: (json['completionCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ApiPartnerService {
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
    if (token != null && token.isNotEmpty) {
      return Options(headers: {'Authorization': 'Bearer $token'});
    }
    return Options();
  }

  /// Fetches partner connection status: `GET /partner/status`
  Future<Map<String, dynamic>> getPartnerStatus() async {
    try {
      final response = await _dio.get(
        '/partner/status',
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('BlushyPartner: Error getting partner status: $e');
      return {};
    }
  }

  /// Generates a partner invite code / link: `POST /partner/invite/link`
  ///
  /// Returns an `{'error': ...}` map rather than null on failure. Returning
  /// null meant the caller could not tell "no link" from "it went wrong", and
  /// the button silently did nothing whenever the server was unreachable.
  Future<Map<String, dynamic>> createInviteLink() async {
    try {
      final response = await _dio.post(
        '/partner/invite/link',
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'error': 'The server returned an unexpected response.'};
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ??
          e.response?.data?['error']?['message'] ??
          e.message ??
          'Could not reach the server.';
      debugPrint('BlushyPartner: Error creating invite link: $e');
      return {'error': message.toString()};
    } catch (e) {
      debugPrint('BlushyPartner: Error creating invite link: $e');
      return {'error': e.toString()};
    }
  }

  /// Claims an unassigned invite token / code: `POST /partner/invite/claim`
  Future<Map<String, dynamic>> acceptInviteLink(String inviteCode) async {
    try {
      final response = await _dio.post(
        '/partner/invite/claim',
        data: {'inviteCode': inviteCode},
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'success': true};
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? 'Failed to claim invitation.';
      return {'error': message};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Updates granular partner sharing permissions: `PATCH /partner/connections/:connectionId/permissions`
  Future<bool> updatePermissions(String connectionId, Map<String, dynamic> permissions) async {
    try {
      final response = await _dio.patch(
        '/partner/connections/$connectionId/permissions',
        data: permissions,
        options: _authOptions(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('BlushyPartner: Error updating partner permissions: $e');
      return false;
    }
  }

  /// Asks Sia a relationship question about a connected partner.
  ///
  /// `POST /ai/relationship-advice/:connectionId`. The server gates any partner
  /// data behind that partner's sharing permissions and runs the deterministic
  /// safety ruleset over both the question and the answer.
  Future<Map<String, dynamic>> askRelationshipAi({
    required String connectionId,
    required String question,
  }) async {
    try {
      final response = await _dio.post(
        '/ai/relationship-advice/$connectionId',
        data: {'question': question},
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'error': 'The server returned an unexpected response.'};
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ??
          e.response?.data?['error']?['message'] ??
          e.message ??
          'Could not reach Sia.';
      return {'error': message.toString()};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Invites a partner by email: `POST /partner/invite`
  Future<Map<String, dynamic>> invitePartnerByEmail(String email) async {
    try {
      final response = await _dio.post(
        '/partner/invite',
        data: {'partnerEmail': email},
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'success': true};
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? 'Failed to send invite.';
      return {'error': message};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Fetches incoming partner requests: `GET /partner/requests/incoming`
  Future<List<Map<String, dynamic>>> getIncomingInvitations() async {
    try {
      final response = await _dio.get(
        '/partner/requests/incoming',
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['invitations'] is List) {
        return List<Map<String, dynamic>>.from(response.data['invitations']);
      }
      return [];
    } catch (e) {
      debugPrint('BlushyPartner: Error fetching incoming invitations: $e');
      return [];
    }
  }

  /// Fetches outgoing partner requests: `GET /partner/requests/outgoing`
  Future<List<Map<String, dynamic>>> getOutgoingInvitations() async {
    try {
      final response = await _dio.get(
        '/partner/requests/outgoing',
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['invitations'] is List) {
        return List<Map<String, dynamic>>.from(response.data['invitations']);
      }
      return [];
    } catch (e) {
      debugPrint('BlushyPartner: Error fetching outgoing invitations: $e');
      return [];
    }
  }

  /// Responds to a partner invitation (accept/reject): `POST /partner/requests/:invitationId/respond`
  Future<bool> respondToInvitation(String invitationId, String action) async {
    try {
      await _dio.post(
        '/partner/requests/$invitationId/respond',
        data: {'action': action},
        options: _authOptions(),
      );
      return true;
    } catch (e) {
      debugPrint('BlushyPartner: Error responding to invitation: $e');
      return false;
    }
  }

  /// Responds to a partner connection confirmation: `POST /partner/connections/:connectionId/respond`
  Future<bool> respondToConnection(String connectionId, String action) async {
    try {
      await _dio.post(
        '/partner/connections/$connectionId/respond',
        data: {'action': action},
        options: _authOptions(),
      );
      return true;
    } catch (e) {
      debugPrint('BlushyPartner: Error responding to connection: $e');
      return false;
    }
  }

  /// Fetches all active connections for current user: `GET /partner/connections`
  Future<List<Map<String, dynamic>>> getConnections() async {
    try {
      final response = await _dio.get(
        '/partner/connections',
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['connections'] is List) {
        return List<Map<String, dynamic>>.from(response.data['connections']);
      }
      return [];
    } catch (e) {
      debugPrint('BlushyPartner: Error getting partner connections: $e');
      return [];
    }
  }

  /// Breaks up or cancels a partner connection: `POST /partner/connections/:connectionId/breakup`
  Future<bool> breakupConnection(String connectionId) async {
    try {
      await _dio.post(
        '/partner/connections/$connectionId/breakup',
        options: _authOptions(),
      );
      return true;
    } catch (e) {
      debugPrint('BlushyPartner: Error disconnecting partner: $e');
      return false;
    }
  }

  /// Fetches shared live partner data (her cycle, mood, sleep, suggestions): `GET /partner/connections/:connectionId/shared-data`
  Future<Map<String, dynamic>> getPartnerSharedData(String connectionId) async {
    try {
      final response = await _dio.get(
        '/partner/connections/$connectionId/shared-data',
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data['data']);
      }
      return {};
    } catch (e) {
      debugPrint('BlushyPartner: Error fetching partner shared data: $e');
      return {};
    }
  }

  /// Fetches AI partner decoder suggestions: `GET /ai/partner-suggestions/:connectionId`
  Future<Map<String, dynamic>> getPartnerDecoder(String connectionId) async {
    try {
      final response = await _dio.get(
        '/ai/partner-suggestions/$connectionId',
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('BlushyPartner: Error fetching partner decoder: $e');
      return {};
    }
  }

  /// Fetches all messages for a partner connection: `GET /partner/connections/:connectionId/messages`
  Future<List<Map<String, dynamic>>> getMessages(String connectionId) async {
    try {
      final response = await _dio.get(
        '/partner/connections/$connectionId/messages',
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic> && response.data['messages'] is List) {
        return List<Map<String, dynamic>>.from(response.data['messages']);
      }
      return [];
    } catch (e) {
      debugPrint('BlushyPartner: Error fetching messages: $e');
      return [];
    }
  }

  /// Sends a text message to a partner connection: `POST /partner/connections/:connectionId/messages`
  Future<Map<String, dynamic>?> sendMessage(String connectionId, String message) async {
    try {
      final response = await _dio.post(
        '/partner/connections/$connectionId/messages',
        data: {'message': message},
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('BlushyPartner: Error sending partner message: $e');
      return null;
    }
  }

  /// Toggles completion of a daily support action: `POST /partner/connections/:connectionId/support-actions/toggle`
  Future<List<String>> toggleSupportAction({
    required String connectionId,
    required String actionId,
    required bool completed,
  }) async {
    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final response = await _dio.post(
        '/partner/connections/$connectionId/support-actions/toggle',
        data: {
          'actionId': actionId,
          'completed': completed,
          'date': todayStr,
        },
        options: _authOptions(),
      );
      if (response.data is Map && response.data['completedActionIds'] is List) {
        return List<String>.from(response.data['completedActionIds'].map((e) => e.toString()));
      }
      return [];
    } catch (e) {
      debugPrint('BlushyPartner: Error toggling support action: $e');
      return [];
    }
  }

  /// Decodes emotional subtext and physiological context of a partner message: `POST /partner/connections/:connectionId/decode-message`
  Future<Map<String, dynamic>?> decodeMessage({
    required String connectionId,
    required String messageText,
  }) async {
    try {
      final response = await _dio.post(
        '/partner/connections/$connectionId/decode-message',
        data: {
          'messageText': messageText,
        },
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('BlushyPartner: Error decoding message: $e');
      return null;
    }
  }

  /// Shared activities for a connection: `GET /partner/connections/:id/activities`
  Future<List<SharedActivity>> getSharedActivities(String connectionId) async {
    try {
      final response = await _dio.get(
        '/partner/connections/$connectionId/activities',
        options: _authOptions(),
      );
      final raw = response.data is Map
          ? (response.data['activities'] as List? ?? const [])
          : const [];
      return raw
          .whereType<Map>()
          .map((e) => SharedActivity.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      debugPrint('BlushyPartner: Error loading shared activities: $e');
      return const [];
    }
  }

  /// Moves an activity to [status]. Returns the refreshed list, so both the
  /// tapped card and every other card reflect the server's view.
  Future<List<SharedActivity>?> setSharedActivityStatus(
    String connectionId,
    String activityKey,
    String status,
  ) async {
    try {
      final response = await _dio.post(
        '/partner/connections/$connectionId/activities/$activityKey',
        data: {'status': status},
        options: _authOptions(),
      );
      final raw = response.data is Map
          ? (response.data['activities'] as List? ?? const [])
          : const [];
      return raw
          .whereType<Map>()
          .map((e) => SharedActivity.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      debugPrint('BlushyPartner: Error updating shared activity: $e');
      return null;
    }
  }

}

