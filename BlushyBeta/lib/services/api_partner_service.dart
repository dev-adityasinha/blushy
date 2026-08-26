import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_base_url.dart';
import 'auth_storage.dart';

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

  /// Generates a partner invite code / link: `POST /partner/invite`
  Future<String?> createInviteLink() async {
    try {
      final response = await _dio.post(
        '/partner/invite',
        options: _authOptions(),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data['inviteCode'] as String? ?? response.data['inviteUrl'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('BlushyPartner: Error creating invite link: $e');
      return null;
    }
  }

  /// Accepts a partner invite code: `POST /partner/accept-invite`
  Future<bool> acceptInviteLink(String inviteCode) async {
    try {
      await _dio.post(
        '/partner/accept-invite',
        data: {'inviteCode': inviteCode},
        options: _authOptions(),
      );
      return true;
    } catch (e) {
      debugPrint('BlushyPartner: Error accepting invite link: $e');
      return false;
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
}

