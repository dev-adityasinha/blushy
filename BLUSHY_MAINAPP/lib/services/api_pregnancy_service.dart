import 'dart:async';

import '../core/storage.dart';
import 'api_contract_client.dart';

class PregnancyOverviewData {
  final bool isDueDateConfigured;
  final String? dueDate;
  final int? week;
  final int? day;
  final int? trimester;
  final String trimesterLabel;
  final int? daysRemaining;
  final int progressPercent;
  final String babySizeName;
  final String babySizeEmoji;
  final double babyLengthCm;
  final double babyWeightG;
  final List<String> babyHighlights;
  final List<String> maternalBodyHighlights;
  final String oneThingToKnow;
  final String oneThingToDo;
  final Map<String, dynamic>? teachMeTopic;
  final Map<String, dynamic>? partnerHelp;
  final List<String> suggestedPrompts;

  PregnancyOverviewData({
    required this.isDueDateConfigured,
    this.dueDate,
    this.week,
    this.day,
    this.trimester,
    required this.trimesterLabel,
    this.daysRemaining,
    required this.progressPercent,
    required this.babySizeName,
    required this.babySizeEmoji,
    required this.babyLengthCm,
    required this.babyWeightG,
    required this.babyHighlights,
    required this.maternalBodyHighlights,
    required this.oneThingToKnow,
    required this.oneThingToDo,
    this.teachMeTopic,
    this.partnerHelp,
    required this.suggestedPrompts,
  });

  factory PregnancyOverviewData.fromJson(Map<String, dynamic> json) {
    final weekly = json['weeklyData'] is Map<String, dynamic>
        ? json['weeklyData'] as Map<String, dynamic>
        : <String, dynamic>{};
    final isConfigured = json['isDueDateConfigured'] == true;

    return PregnancyOverviewData(
      isDueDateConfigured: isConfigured,
      dueDate: json['dueDate']?.toString(),
      week: (json['week'] as num?)?.toInt(),
      day: (json['day'] as num?)?.toInt(),
      trimester: (json['trimester'] as num?)?.toInt(),
      trimesterLabel: json['trimesterLabel']?.toString() ?? (isConfigured ? 'First Trimester' : 'Not Set'),
      daysRemaining: (json['daysRemaining'] as num?)?.toInt(),
      progressPercent: (json['progressPercent'] as num?)?.toInt() ?? 0,
      babySizeName: weekly['babySizeName']?.toString() ?? 'Poppy Seed',
      babySizeEmoji: weekly['babySizeEmoji']?.toString() ?? '🌱',
      babyLengthCm: (weekly['babyLengthCm'] as num?)?.toDouble() ?? 0.1,
      babyWeightG: (weekly['babyWeightG'] as num?)?.toDouble() ?? 0.1,
      babyHighlights: (weekly['babyHighlights'] as List?)?.map((e) => e.toString()).toList() ?? [],
      maternalBodyHighlights: (weekly['maternalBodyHighlights'] as List?)?.map((e) => e.toString()).toList() ?? [],
      oneThingToKnow: weekly['oneThingToKnow']?.toString() ?? 'Rest is essential work during pregnancy.',
      oneThingToDo: weekly['oneThingToDo']?.toString() ?? 'Take 5 minutes for gentle stretches or hydration.',
      teachMeTopic: weekly['teachMeTopic'] is Map<String, dynamic> ? weekly['teachMeTopic'] as Map<String, dynamic> : null,
      partnerHelp: weekly['partnerHelp'] is Map<String, dynamic> ? weekly['partnerHelp'] as Map<String, dynamic> : null,
      suggestedPrompts: (weekly['suggestedPrompts'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class PregnancyTodayBriefData {
  final bool isDueDateConfigured;
  final String greeting;
  final String gestationalDisplay;
  final String trimesterLabel;
  final String yourBody;
  final String yourBaby;
  final String yourCare;
  final String oneThingToKnow;
  final String oneThingToDo;
  final String? activeMode;
  final String modeAdvice;
  final List<String> suggestedPrompts;

  PregnancyTodayBriefData({
    required this.isDueDateConfigured,
    required this.greeting,
    required this.gestationalDisplay,
    required this.trimesterLabel,
    required this.yourBody,
    required this.yourBaby,
    required this.yourCare,
    required this.oneThingToKnow,
    required this.oneThingToDo,
    this.activeMode,
    required this.modeAdvice,
    required this.suggestedPrompts,
  });

  factory PregnancyTodayBriefData.fromJson(Map<String, dynamic> json) {
    return PregnancyTodayBriefData(
      isDueDateConfigured: json['isDueDateConfigured'] == true,
      greeting: json['greeting']?.toString() ?? 'Good morning ❤️',
      gestationalDisplay: json['gestationalDisplay']?.toString() ?? 'Due date not set',
      trimesterLabel: json['trimesterLabel']?.toString() ?? 'Getting Started',
      yourBody: json['yourBody']?.toString() ?? 'Set your due date to see weekly maternal changes.',
      yourBaby: json['yourBaby']?.toString() ?? 'Set your due date to follow baby\'s growth.',
      yourCare: json['yourCare']?.toString() ?? 'Initial prenatal intake.',
      oneThingToKnow: json['oneThingToKnow']?.toString() ?? 'Take things at your own pace.',
      oneThingToDo: json['oneThingToDo']?.toString() ?? 'Drink a tall glass of water.',
      activeMode: json['activeMode']?.toString(),
      modeAdvice: json['modeAdvice']?.toString() ?? 'Tap any mood or reality above to tailor Docsy\'s recommendations for your day.',
      suggestedPrompts: (json['suggestedPrompts'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class SymptomTriageResult {
  final String category;
  final String badgeLabel;
  final String colorHex;
  final String summary;
  final String reasoning;
  final String guidance;
  final List<String> questionsForDoctor;

  SymptomTriageResult({
    required this.category,
    required this.badgeLabel,
    required this.colorHex,
    required this.summary,
    required this.reasoning,
    required this.guidance,
    required this.questionsForDoctor,
  });

  factory SymptomTriageResult.fromJson(Map<String, dynamic> json) {
    return SymptomTriageResult(
      category: json['category']?.toString() ?? 'common',
      badgeLabel: json['badgeLabel']?.toString() ?? 'Common in Pregnancy',
      colorHex: json['colorHex']?.toString() ?? '#0D9488',
      summary: json['summary']?.toString() ?? 'Common physiological sensation in pregnancy.',
      reasoning: json['reasoning']?.toString() ?? 'Hormonal shifts and expanding tissues.',
      guidance: json['guidance']?.toString() ?? 'Rest, hydrate, and mention to your provider at your next visit.',
      questionsForDoctor: (json['questionsForDoctor'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class ApiPregnancyService {
  const ApiPregnancyService._();

  static Future<ApiResult<PregnancyOverviewData>> getOverview({String? dueDate}) async {
    final query = <String, String>{};
    if (dueDate != null && dueDate.isNotEmpty) {
      query['dueDate'] = dueDate;
    }
    return ApiContractClient.get(
      '/pregnancy/overview',
      query: query,
      parse: (data) => PregnancyOverviewData.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  static Future<ApiResult<PregnancyTodayBriefData>> getTodayBrief({String? dueDate, String? mode}) async {
    final query = <String, String>{};
    if (mode != null && mode.isNotEmpty) {
      query['mode'] = mode;
    }
    if (dueDate != null && dueDate.isNotEmpty) {
      query['dueDate'] = dueDate;
    }
    return ApiContractClient.get(
      '/pregnancy/today-brief',
      query: query,
      parse: (data) => PregnancyTodayBriefData.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> submitCheckIn(Map<String, dynamic> checkin) async {
    // Also backup to BlushyStorage
    try {
      BlushyStorage.write('pregnancy_last_checkin.json', checkin);
    } catch (_) {}

    return ApiContractClient.post(
      '/pregnancy/check-in',
      body: checkin,
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> getBaseline() async {
    return ApiContractClient.get(
      '/pregnancy/baseline',
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<SymptomTriageResult>> classifySymptom({required String query, int week = 20}) async {
    return ApiContractClient.get(
      '/pregnancy/is-this-normal',
      query: {'query': query, 'week': week.toString()},
      parse: (data) => SymptomTriageResult.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> saveMemory(Map<String, dynamic> memory) async {
    return ApiContractClient.post(
      '/pregnancy/memory',
      body: memory,
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<List<Map<String, dynamic>>>> getMemories() async {
    return ApiContractClient.get(
      '/pregnancy/memories',
      parse: (data) {
        if (data is Map && data['memories'] is List) {
          return (data['memories'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
        return <Map<String, dynamic>>[];
      },
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> saveQuestion(Map<String, dynamic> question) async {
    return ApiContractClient.post(
      '/pregnancy/question',
      body: question,
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<List<Map<String, dynamic>>>> getQuestions() async {
    return ApiContractClient.get(
      '/pregnancy/questions',
      parse: (data) {
        if (data is Map && data['questions'] is List) {
          return (data['questions'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
        return <Map<String, dynamic>>[];
      },
    );
  }
}
