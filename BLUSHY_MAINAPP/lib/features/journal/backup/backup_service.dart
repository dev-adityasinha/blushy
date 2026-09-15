import 'dart:convert';
import 'package:crypto/crypto.dart';

class BackupManifest {
  final String backupId;
  final String appVersion;
  final String schemaVersion;
  final String createdDate;
  final int entryCount;
  final int mediaCount;
  final String checksum;

  BackupManifest({
    required this.backupId,
    required this.appVersion,
    required this.schemaVersion,
    required this.createdDate,
    required this.entryCount,
    required this.mediaCount,
    required this.checksum,
  });

  Map<String, dynamic> toJson() => {
        'backupId': backupId,
        'appVersion': appVersion,
        'schemaVersion': schemaVersion,
        'createdDate': createdDate,
        'entryCount': entryCount,
        'mediaCount': mediaCount,
        'checksum': checksum,
      };

  factory BackupManifest.fromJson(Map<String, dynamic> json) => BackupManifest(
        backupId: json['backupId'] as String? ?? 'backup_1',
        appVersion: json['appVersion'] as String? ?? '1.0.0',
        schemaVersion: json['schemaVersion'] as String? ?? 'v2',
        createdDate: json['createdDate'] as String? ?? DateTime.now().toIso8601String(),
        entryCount: json['entryCount'] as int? ?? 0,
        mediaCount: json['mediaCount'] as int? ?? 0,
        checksum: json['checksum'] as String? ?? '',
      );
}

class BackupService {
  String generateChecksum(String payload) {
    final bytes = utf8.encode(payload);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Map<String, dynamic> createBackupPackage(List<Map<String, dynamic>> rawEntries) {
    final payloadStr = jsonEncode(rawEntries);
    final checksum = generateChecksum(payloadStr);

    final manifest = BackupManifest(
      backupId: 'backup_${DateTime.now().millisecondsSinceEpoch}',
      appVersion: '1.0.0',
      schemaVersion: 'v2',
      createdDate: DateTime.now().toIso8601String(),
      entryCount: rawEntries.length,
      mediaCount: 0,
      checksum: checksum,
    );

    return {
      'manifest': manifest.toJson(),
      'payload': rawEntries,
    };
  }

  bool verifyBackupIntegrity(Map<String, dynamic> package) {
    try {
      final manifestJson = package['manifest'] as Map<String, dynamic>?;
      final payloadList = package['payload'] as List<dynamic>?;
      if (manifestJson == null || payloadList == null) return false;

      final manifest = BackupManifest.fromJson(manifestJson);
      final payloadStr = jsonEncode(payloadList);
      final computedChecksum = generateChecksum(payloadStr);

      return manifest.checksum == computedChecksum;
    } catch (_) {
      return false;
    }
  }
}
