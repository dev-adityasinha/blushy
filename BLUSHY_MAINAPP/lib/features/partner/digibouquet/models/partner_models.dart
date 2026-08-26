import 'package:flutter/foundation.dart';
import '../../../../services/api_partner_service.dart';

class PartnerPermissions {
  const PartnerPermissions({
    required this.shareMood,
    required this.shareCycle,
    required this.shareSleep,
    required this.shareInsights,
    required this.shareOnboarding,
    required this.allowAiSuggestionsWoman,
    required this.allowAiSuggestionsMan,
    required this.allowDecoderMan,
  });

  final bool shareMood;
  final bool shareCycle;
  final bool shareSleep;
  final bool shareInsights;
  final bool shareOnboarding;
  final bool allowAiSuggestionsWoman;
  final bool allowAiSuggestionsMan;
  final bool allowDecoderMan;

  factory PartnerPermissions.fromJson(Map<String, dynamic>? json) {
    final map = json ?? const {};
    return PartnerPermissions(
      shareMood: map['shareMood'] as bool? ?? false,
      shareCycle: map['shareCycle'] as bool? ?? false,
      shareSleep: map['shareSleep'] as bool? ?? false,
      shareInsights: map['shareInsights'] as bool? ?? false,
      shareOnboarding: map['shareOnboarding'] as bool? ?? false,
      allowAiSuggestionsWoman: map['allowAiSuggestionsWoman'] as bool? ?? false,
      allowAiSuggestionsMan: map['allowAiSuggestionsMan'] as bool? ?? false,
      allowDecoderMan: map['allowDecoderMan'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shareMood': shareMood,
      'shareCycle': shareCycle,
      'shareSleep': shareSleep,
      'shareInsights': shareInsights,
      'shareOnboarding': shareOnboarding,
      'allowAiSuggestionsWoman': allowAiSuggestionsWoman,
      'allowAiSuggestionsMan': allowAiSuggestionsMan,
      'allowDecoderMan': allowDecoderMan,
    };
  }
}

class PartnerConnection {
  const PartnerConnection({
    required this.connectionId,
    required this.partnerUserId,
    this.partnerEmail,
    this.partnerRole,
    required this.permissionOwnerUserId,
    required this.canManagePermissions,
    required this.permissions,
    required this.status,
    required this.viewerIsSender,
    this.senderAcceptedAt,
    this.receiverAcceptedAt,
    this.breakupRequestedByUserId,
    this.breakupRequestedAt,
    this.endedAt,
    this.createdAt,
  });

  final String connectionId;
  final String partnerUserId;
  final String? partnerEmail;
  final String? partnerRole;
  final String permissionOwnerUserId;
  final bool canManagePermissions;
  final PartnerPermissions permissions;
  final String status;
  final bool viewerIsSender;
  final DateTime? senderAcceptedAt;
  final DateTime? receiverAcceptedAt;
  final String? breakupRequestedByUserId;
  final DateTime? breakupRequestedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;

  bool get isActive => status == 'active';

  factory PartnerConnection.fromJson(Map<String, dynamic> json) {
    return PartnerConnection(
      connectionId: json['connectionId'] as String? ?? '',
      partnerUserId: json['partnerUserId'] as String? ?? '',
      partnerEmail: json['partnerEmail'] as String?,
      partnerRole: json['partnerRole'] as String?,
      permissionOwnerUserId: json['permissionOwnerUserId'] as String? ?? '',
      canManagePermissions: json['canManagePermissions'] as bool? ?? false,
      permissions: PartnerPermissions.fromJson(json['permissions'] as Map<String, dynamic>?),
      status: json['status'] as String? ?? 'active',
      viewerIsSender: json['viewerIsSender'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ?? DateTime.now().toUtc(),
    );
  }
}

class PartnerService {
  final ApiPartnerService _api = ApiPartnerService();

  Future<void> sendMessage({
    required String token,
    required String connectionId,
    required String message,
  }) async {
    debugPrint('Sending bouquet message to connection $connectionId: $message');
    await _api.sendMessage(connectionId, message);
  }
}
