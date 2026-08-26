import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_base_url.dart';
import 'auth_storage.dart';

class PeriodEntry {
  final String? id;
  final String? userId;
  final DateTime periodStartDate;
  final DateTime? periodEndDate;
  final String? flowIntensity;
  final String source;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PeriodEntry({
    this.id,
    this.userId,
    required this.periodStartDate,
    this.periodEndDate,
    this.flowIntensity,
    this.source = 'manual_tracker',
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'periodStartDate': "${periodStartDate.year}-${periodStartDate.month.toString().padLeft(2, '0')}-${periodStartDate.day.toString().padLeft(2, '0')}",
    'periodEndDate': periodEndDate != null
        ? "${periodEndDate!.year}-${periodEndDate!.month.toString().padLeft(2, '0')}-${periodEndDate!.day.toString().padLeft(2, '0')}"
        : null,
    'flowIntensity': flowIntensity,
    'source': source,
    'notes': notes,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory PeriodEntry.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is DateTime) return d;
      final str = d.toString().split('T').first;
      final parts = str.split('-');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
      return DateTime.tryParse(d.toString()) ?? DateTime.now();
    }

    DateTime? parseOptDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      final str = d.toString().split('T').first;
      final parts = str.split('-');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
      return DateTime.tryParse(d.toString());
    }

    return PeriodEntry(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      userId: json['userId'] ?? json['user_id'],
      periodStartDate: parseDate(json['periodStartDate'] ?? json['period_start_date']),
      periodEndDate: parseOptDate(json['periodEndDate'] ?? json['period_end_date']),
      flowIntensity: json['flowIntensity'] ?? json['flow_intensity'],
      source: json['source'] ?? 'manual_tracker',
      notes: json['notes'],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }
}

class PeriodPrediction {
  final bool hasData;
  final String trackingState;
  final bool trackingSuppressed;
  final String? todayDate;
  final String? userTimezone;
  final String? lastPeriodStartDate;
  final int? currentCycleDay;
  final String currentPhase;
  final int cycleLengthDays;
  final int periodLengthDays;
  final bool isCurrentPeriod;
  final int? periodDay;
  final bool isOverdue;
  final int daysOverdue;
  final String? nextPeriodStartDate;
  final int? daysUntilNextPeriod;
  final String? estimatedOvulationDate;
  final String? fertileWindowStart;
  final String? fertileWindowEnd;
  final String confidence;
  final String displayLabel;
  final String message;
  final bool isIrregular;
  final int completedCyclesCount;
  final List<int> historicalIntervals;

  PeriodPrediction({
    required this.hasData,
    this.trackingState = 'no_data',
    this.trackingSuppressed = false,
    this.todayDate,
    this.userTimezone,
    this.lastPeriodStartDate,
    this.currentCycleDay,
    this.currentPhase = 'Not Logged',
    this.cycleLengthDays = 28,
    this.periodLengthDays = 5,
    this.isCurrentPeriod = false,
    this.periodDay,
    this.isOverdue = false,
    this.daysOverdue = 0,
    this.nextPeriodStartDate,
    this.daysUntilNextPeriod,
    this.estimatedOvulationDate,
    this.fertileWindowStart,
    this.fertileWindowEnd,
    this.confidence = 'none',
    this.displayLabel = '',
    this.message = '',
    this.isIrregular = false,
    this.completedCyclesCount = 0,
    this.historicalIntervals = const [],
  });

  factory PeriodPrediction.fromJson(Map<String, dynamic> json) {
    final cur = json['currentCycle'] is Map ? (json['currentCycle'] as Map<String, dynamic>) : null;
    final pred = json['prediction'] is Map ? (json['prediction'] as Map<String, dynamic>) : null;
    final suff = json['dataSufficiency'] is Map ? (json['dataSufficiency'] as Map<String, dynamic>) : null;

    final int? cycleDay = cur != null
        ? (cur['currentCycleDay'] is num ? (cur['currentCycleDay'] as num).toInt() : null)
        : (json['currentCycleDay'] is num ? (json['currentCycleDay'] as num).toInt() : null);

    final String phase = cur?['phase'] ?? json['currentPhase'] ?? 'Not Logged';
    final bool overdue = cur?['isOverdue'] == true || json['isOverdue'] == true;
    final int overdueDays = cur?['daysOverdue'] is num
        ? (cur!['daysOverdue'] as num).toInt()
        : (json['daysOverdue'] is num ? (json['daysOverdue'] as num).toInt() : 0);

    final String? nextPeriod = pred?['nextPeriodStartDate'] ?? json['nextPeriodStartDate'];
    final int? daysUntil = pred != null
        ? (pred['daysUntilNextPeriod'] is num ? (pred['daysUntilNextPeriod'] as num).toInt() : null)
        : (json['daysUntilNextPeriod'] is num ? (json['daysUntilNextPeriod'] as num).toInt() : null);

    final String? ovulation = pred?['estimatedOvulationDate'] ?? json['estimatedOvulationDate'];
    final String? fertileStart = pred?['fertileWindowStart'] ?? json['fertileWindowStart'];
    final String? fertileEnd = pred?['fertileWindowEnd'] ?? json['fertileWindowEnd'];

    final String conf = suff?['confidenceLevel'] ?? json['confidence'] ?? 'none';
    final String dispLabel = suff?['displayLabel'] ?? '';
    final String msg = suff?['message'] ?? '';

    return PeriodPrediction(
      hasData: json['hasData'] == true,
      trackingState: json['trackingState'] ?? (json['hasData'] == true ? 'sufficient_data' : 'no_data'),
      trackingSuppressed: json['trackingSuppressed'] == true,
      todayDate: json['todayDate'],
      userTimezone: json['userTimezone'],
      lastPeriodStartDate: cur?['latestConfirmedPeriodStartDate'] ?? cur?['cycleStartDate'] ?? json['lastPeriodStartDate'],
      currentCycleDay: cycleDay,
      currentPhase: phase,
      cycleLengthDays: json['cycleLengthDays'] is num ? (json['cycleLengthDays'] as num).toInt() : 28,
      periodLengthDays: cur?['periodDurationDays'] is num
          ? (cur!['periodDurationDays'] as num).toInt()
          : (json['periodLengthDays'] is num ? (json['periodLengthDays'] as num).toInt() : 5),
      isCurrentPeriod: cur?['isCurrentPeriod'] == true || json['isCurrentPeriod'] == true,
      periodDay: cur != null
          ? (cur['periodDay'] is num ? (cur['periodDay'] as num).toInt() : null)
          : (json['periodDay'] is num ? (json['periodDay'] as num).toInt() : null),
      isOverdue: overdue,
      daysOverdue: overdueDays,
      nextPeriodStartDate: nextPeriod,
      daysUntilNextPeriod: daysUntil,
      estimatedOvulationDate: ovulation,
      fertileWindowStart: fertileStart,
      fertileWindowEnd: fertileEnd,
      confidence: conf,
      displayLabel: dispLabel,
      message: msg,
      isIrregular: json['isIrregular'] == true,
      completedCyclesCount: suff?['completedCyclesCount'] is num
          ? (suff!['completedCyclesCount'] as num).toInt()
          : (json['completedCyclesCount'] is num ? (json['completedCyclesCount'] as num).toInt() : 0),
      historicalIntervals: json['historicalIntervals'] is List
          ? (json['historicalIntervals'] as List).map((e) => (e as num).toInt()).toList()
          : [],
    );
  }
}

class ApiPeriodService {
  static final ApiPeriodService _instance = ApiPeriodService._internal();
  factory ApiPeriodService() => _instance;
  ApiPeriodService._internal();

  String get _baseUrl => resolveApiBaseUrl();

  Future<Map<String, String>> _headers() async {
    final token = AuthStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  Future<PeriodEntry?> logPeriodEntry({
    required DateTime periodStartDate,
    DateTime? periodEndDate,
    String? flowIntensity,
    String source = 'manual_tracker',
    String? notes,
  }) async {
    try {
      final startStr = "${periodStartDate.year}-${periodStartDate.month.toString().padLeft(2, '0')}-${periodStartDate.day.toString().padLeft(2, '0')}";
      final endStr = periodEndDate != null
          ? "${periodEndDate.year}-${periodEndDate.month.toString().padLeft(2, '0')}-${periodEndDate.day.toString().padLeft(2, '0')}"
          : null;

      final url = Uri.parse('$_baseUrl/period/entries');
      final res = await http.post(
        url,
        headers: await _headers(),
        body: jsonEncode({
          'periodStartDate': startStr,
          ...?endStr != null ? {'periodEndDate': endStr} : null,
          ...?flowIntensity != null ? {'flowIntensity': flowIntensity} : null,
          'source': source,
          ...?notes != null ? {'notes': notes} : null,
        }),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] != null) {
          return PeriodEntry.fromJson(decoded['data']);
        }
      }
    } catch (e) {
      debugPrint('ApiPeriodService logPeriodEntry error: $e');
    }
    return null;
  }

  Future<List<PeriodEntry>> getPeriodEntries() async {
    try {
      final url = Uri.parse('$_baseUrl/period/entries');
      final res = await http.get(url, headers: await _headers());

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final list = decoded['data']?['entries'];
        if (list is List) {
          return list.map((item) => PeriodEntry.fromJson(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('ApiPeriodService getPeriodEntries error: $e');
    }
    return [];
  }

  Future<bool> deletePeriodEntry(String id) async {
    try {
      final url = Uri.parse('$_baseUrl/period/entries/$id');
      final res = await http.delete(url, headers: await _headers());
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('ApiPeriodService deletePeriodEntry error: $e');
    }
    return false;
  }

  Future<PeriodPrediction?> getPredictions() async {
    try {
      final url = Uri.parse('$_baseUrl/period/predictions');
      final res = await http.get(url, headers: await _headers());

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] != null) {
          return PeriodPrediction.fromJson(decoded['data']);
        }
      }
    } catch (e) {
      debugPrint('ApiPeriodService getPredictions error: $e');
    }
    return null;
  }
}
