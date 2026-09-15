import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base_url.dart';
import 'auth_storage.dart';

class MilestoneItem {
  final String id;
  final String title;
  final String description;
  final String sourceField;
  final String completionRule;
  final bool isCompleted;
  final bool showGreenTick;
  final String statusLabel;

  MilestoneItem({
    required this.id,
    required this.title,
    required this.description,
    required this.sourceField,
    required this.completionRule,
    required this.isCompleted,
    required this.showGreenTick,
    required this.statusLabel,
  });

  factory MilestoneItem.fromJson(Map<String, dynamic> json) {
    return MilestoneItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      sourceField: json['sourceField']?.toString() ?? '',
      completionRule: json['completionRule']?.toString() ?? '',
      isCompleted: json['isCompleted'] == true,
      showGreenTick: json['showGreenTick'] == true,
      statusLabel: json['statusLabel']?.toString() ?? '',
    );
  }
}

class MonthlyReflection {
  final String headline;
  final String summaryText;
  final bool isPersonalized;
  final int sampleSize;

  MonthlyReflection({
    required this.headline,
    required this.summaryText,
    required this.isPersonalized,
    required this.sampleSize,
  });

  factory MonthlyReflection.fromJson(Map<String, dynamic> json) {
    return MonthlyReflection(
      headline: json['headline']?.toString() ?? '',
      summaryText: json['summaryText']?.toString() ?? '',
      isPersonalized: json['isPersonalized'] == true,
      sampleSize: json['sampleSize'] is num ? (json['sampleSize'] as num).toInt() : 0,
    );
  }
}

class MonthlyMetrics {
  final int checkinCount;
  final double checkinConsistencyPercentage;
  final int symptomLogCount;
  final int moodLogCount;
  final List<String> uniqueSymptomsTracked;
  final int periodDaysInMonth;
  final int completedCyclesInMonth;
  final int siaConversationsCount;

  MonthlyMetrics({
    required this.checkinCount,
    required this.checkinConsistencyPercentage,
    required this.symptomLogCount,
    required this.moodLogCount,
    required this.uniqueSymptomsTracked,
    required this.periodDaysInMonth,
    required this.completedCyclesInMonth,
    required this.siaConversationsCount,
  });

  factory MonthlyMetrics.fromJson(Map<String, dynamic> json) {
    return MonthlyMetrics(
      checkinCount: json['checkinCount'] is num ? (json['checkinCount'] as num).toInt() : 0,
      checkinConsistencyPercentage: json['checkinConsistencyPercentage'] is num
          ? (json['checkinConsistencyPercentage'] as num).toDouble()
          : 0.0,
      symptomLogCount: json['symptomLogCount'] is num ? (json['symptomLogCount'] as num).toInt() : 0,
      moodLogCount: json['moodLogCount'] is num ? (json['moodLogCount'] as num).toInt() : 0,
      uniqueSymptomsTracked: json['uniqueSymptomsTracked'] is List
          ? (json['uniqueSymptomsTracked'] as List).map((e) => e.toString()).toList()
          : [],
      periodDaysInMonth: json['periodDaysInMonth'] is num ? (json['periodDaysInMonth'] as num).toInt() : 0,
      completedCyclesInMonth: json['completedCyclesInMonth'] is num ? (json['completedCyclesInMonth'] as num).toInt() : 0,
      siaConversationsCount: json['siaConversationsCount'] is num ? (json['siaConversationsCount'] as num).toInt() : 0,
    );
  }
}

class MonthlyInsightsData {
  final String reportingMonth;
  final String startDate;
  final String endDate;
  final String userTimezone;
  final String timezoneSource;
  final String dataState;
  final int totalDaysInMonth;
  final MonthlyMetrics metrics;
  final List<MilestoneItem> milestones;
  final MonthlyReflection reflection;
  final String disclaimer;

  MonthlyInsightsData({
    required this.reportingMonth,
    required this.startDate,
    required this.endDate,
    required this.userTimezone,
    required this.timezoneSource,
    required this.dataState,
    required this.totalDaysInMonth,
    required this.metrics,
    required this.milestones,
    required this.reflection,
    required this.disclaimer,
  });

  factory MonthlyInsightsData.fromJson(Map<String, dynamic> json) {
    return MonthlyInsightsData(
      reportingMonth: json['reportingMonth']?.toString() ?? '',
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      userTimezone: json['userTimezone']?.toString() ?? '',
      timezoneSource: json['timezoneSource']?.toString() ?? 'user_profile',
      dataState: json['dataState']?.toString() ?? 'no_data',
      totalDaysInMonth: json['totalDaysInMonth'] is num ? (json['totalDaysInMonth'] as num).toInt() : 30,
      metrics: MonthlyMetrics.fromJson(json['metrics'] is Map ? (json['metrics'] as Map<String, dynamic>) : {}),
      milestones: json['milestones'] is List
          ? (json['milestones'] as List).map((m) => MilestoneItem.fromJson(m as Map<String, dynamic>)).toList()
          : [],
      reflection: MonthlyReflection.fromJson(json['reflection'] is Map ? (json['reflection'] as Map<String, dynamic>) : {}),
      disclaimer: json['disclaimer']?.toString() ?? '',
    );
  }
}

class ApiInsightsService {
  static final ApiInsightsService _instance = ApiInsightsService._internal();
  factory ApiInsightsService() => _instance;
  ApiInsightsService._internal();

  Map<String, String> _headers() {
    final token = AuthStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<MonthlyInsightsData?> getMonthlyInsights({String? month}) async {
    try {
      final queryParams = <String, String>{};
      if (month != null) queryParams['month'] = month;

      final baseUri = Uri.parse('${resolveApiBaseUrl()}/api/insights/monthly');
      final uri = baseUri.replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http.get(uri, headers: _headers());
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded != null && decoded['data'] != null) {
          return MonthlyInsightsData.fromJson(decoded['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
