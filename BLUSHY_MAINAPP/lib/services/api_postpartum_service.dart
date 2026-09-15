import 'dart:async';
import '../core/storage.dart';
import 'api_contract_client.dart';

class PostpartumTiming {
  final bool isConfigured;
  final String? deliveryDate;
  final int? daysSinceBirth;
  final int? weeksSinceBirth;
  final int? monthsSinceBirth;
  final String? phase;
  final String phaseName;
  final String? phaseRange;
  final String phaseDescription;
  final List<String> primaryFocus;
  final Map<String, dynamic>? currentMilestone;

  PostpartumTiming({
    required this.isConfigured,
    this.deliveryDate,
    this.daysSinceBirth,
    this.weeksSinceBirth,
    this.monthsSinceBirth,
    this.phase,
    required this.phaseName,
    this.phaseRange,
    required this.phaseDescription,
    this.primaryFocus = const [],
    this.currentMilestone,
  });

  factory PostpartumTiming.fromJson(Map<String, dynamic> json) {
    return PostpartumTiming(
      isConfigured: json['isConfigured'] == true,
      deliveryDate: json['deliveryDate']?.toString(),
      daysSinceBirth: (json['daysSinceBirth'] as num?)?.toInt(),
      weeksSinceBirth: (json['weeksSinceBirth'] as num?)?.toInt(),
      monthsSinceBirth: (json['monthsSinceBirth'] as num?)?.toInt(),
      phase: json['phase']?.toString(),
      phaseName: json['phaseName']?.toString() ?? 'Not Calibrated',
      phaseRange: json['phaseRange']?.toString(),
      phaseDescription: json['phaseDescription']?.toString() ?? '',
      primaryFocus: (json['primaryFocus'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      currentMilestone: json['currentMilestone'] is Map<String, dynamic> ? json['currentMilestone'] as Map<String, dynamic> : null,
    );
  }
}

class PostpartumPriority {
  final String id;
  final String category;
  final String icon;
  final String headline;
  final String reason;
  final String actionTag;

  PostpartumPriority({
    required this.id,
    required this.category,
    required this.icon,
    required this.headline,
    required this.reason,
    required this.actionTag,
  });

  factory PostpartumPriority.fromJson(Map<String, dynamic> json) {
    return PostpartumPriority(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'star',
      headline: json['headline']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      actionTag: json['actionTag']?.toString() ?? '',
    );
  }
}

class PostpartumDeltas {
  final bool hasData;
  final List<Map<String, dynamic>> changes;
  final List<String> steady;

  PostpartumDeltas({
    required this.hasData,
    this.changes = const [],
    this.steady = const [],
  });

  factory PostpartumDeltas.fromJson(Map<String, dynamic> json) {
    return PostpartumDeltas(
      hasData: json['hasData'] == true,
      changes: (json['changes'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
      steady: (json['steady'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

class PostpartumOverviewData {
  final Map<String, dynamic> profile;
  final PostpartumTiming timing;
  final Map<String, dynamic> baselineMaturity;
  final List<PostpartumPriority> priorities;
  final PostpartumDeltas deltas;
  final Map<String, dynamic>? todayCheckin;
  final List<Map<String, dynamic>> recentCheckins;
  final List<Map<String, dynamic>> todayBabyEvents;
  final Map<String, dynamic> safetyStatus;
  final Map<String, dynamic> lochiaStages;
  final List<Map<String, dynamic>> canIDoThisYet;
  final List<Map<String, dynamic>> contextualReads;
  final List<Map<String, dynamic>> milestones;
  final bool isLowEnergyMode;

  PostpartumOverviewData({
    required this.profile,
    required this.timing,
    required this.baselineMaturity,
    required this.priorities,
    required this.deltas,
    this.todayCheckin,
    this.recentCheckins = const [],
    this.todayBabyEvents = const [],
    required this.safetyStatus,
    this.lochiaStages = const {},
    this.canIDoThisYet = const [],
    this.contextualReads = const [],
    this.milestones = const [],
    required this.isLowEnergyMode,
  });

  factory PostpartumOverviewData.fromJson(Map<String, dynamic> json) {
    final timing = json['timing'] is Map
        ? PostpartumTiming.fromJson(Map<String, dynamic>.from(json['timing'] as Map))
        : PostpartumTiming(isConfigured: false, phaseName: 'Not Calibrated', phaseDescription: '');

    final deltas = json['deltas'] is Map
        ? PostpartumDeltas.fromJson(Map<String, dynamic>.from(json['deltas'] as Map))
        : PostpartumDeltas(hasData: false);

    final prioritiesList = (json['priorities'] as List?)
        ?.map((p) => PostpartumPriority.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList() ?? [];

    return PostpartumOverviewData(
      profile: json['profile'] is Map ? Map<String, dynamic>.from(json['profile'] as Map) : {},
      timing: timing,
      baselineMaturity: json['baselineMaturity'] is Map ? Map<String, dynamic>.from(json['baselineMaturity'] as Map) : {},
      priorities: prioritiesList,
      deltas: deltas,
      todayCheckin: json['todayCheckin'] is Map ? Map<String, dynamic>.from(json['todayCheckin'] as Map) : null,
      recentCheckins: (json['recentCheckins'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
      todayBabyEvents: (json['todayBabyEvents'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
      safetyStatus: json['safetyStatus'] is Map ? Map<String, dynamic>.from(json['safetyStatus'] as Map) : {'severity': 'low', 'shouldInterrupt': false},
      lochiaStages: json['lochiaStages'] is Map ? Map<String, dynamic>.from(json['lochiaStages'] as Map) : {},
      canIDoThisYet: (json['canIDoThisYet'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
      contextualReads: (json['contextualReads'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
      milestones: (json['milestones'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
      isLowEnergyMode: json['isLowEnergyMode'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile': profile,
      'timing': {
        'isConfigured': timing.isConfigured,
        'deliveryDate': timing.deliveryDate,
        'daysSinceBirth': timing.daysSinceBirth,
        'phase': timing.phase,
        'phaseName': timing.phaseName,
        'phaseDescription': timing.phaseDescription,
      },
      'baselineMaturity': baselineMaturity,
      'priorities': priorities.map((p) => {
        'id': p.id,
        'category': p.category,
        'icon': p.icon,
        'headline': p.headline,
        'reason': p.reason,
        'actionTag': p.actionTag,
      }).toList(),
      'deltas': {
        'hasData': deltas.hasData,
        'changes': deltas.changes,
        'steady': deltas.steady,
      },
      'todayCheckin': todayCheckin,
      'recentCheckins': recentCheckins,
      'todayBabyEvents': todayBabyEvents,
      'safetyStatus': safetyStatus,
      'lochiaStages': lochiaStages,
      'canIDoThisYet': canIDoThisYet,
      'contextualReads': contextualReads,
      'milestones': milestones,
      'isLowEnergyMode': isLowEnergyMode,
    };
  }
}

class PostpartumTodayBriefData {
  final String openingGreeting;
  final String recoveryPoint;
  final String babyPoint;
  final String noticePoint;
  final List<String> promptPills;
  final Map<String, dynamic> transparency;
  final List<PostpartumPriority> priorities;
  final Map<String, dynamic> safetyStatus;

  PostpartumTodayBriefData({
    required this.openingGreeting,
    required this.recoveryPoint,
    required this.babyPoint,
    required this.noticePoint,
    required this.promptPills,
    required this.transparency,
    required this.priorities,
    required this.safetyStatus,
  });

  factory PostpartumTodayBriefData.fromJson(Map<String, dynamic> json) {
    return PostpartumTodayBriefData(
      openingGreeting: json['openingGreeting']?.toString() ?? 'Good morning. Your recovery journey starts today.',
      recoveryPoint: json['recoveryPoint']?.toString() ?? 'Rest and horizontal healing take priority.',
      babyPoint: json['babyPoint']?.toString() ?? 'Newborn rhythms are intuitive and unfolding.',
      noticePoint: json['noticePoint']?.toString() ?? 'Notice how your physical energy responds to rest.',
      promptPills: (json['promptPills'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      transparency: json['transparency'] is Map ? Map<String, dynamic>.from(json['transparency'] as Map) : {},
      priorities: (json['priorities'] as List?)?.map((p) => PostpartumPriority.fromJson(Map<String, dynamic>.from(p as Map))).toList() ?? const [],
      safetyStatus: json['safetyStatus'] is Map ? Map<String, dynamic>.from(json['safetyStatus'] as Map) : {'severity': 'low', 'shouldInterrupt': false},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'openingGreeting': openingGreeting,
      'recoveryPoint': recoveryPoint,
      'babyPoint': babyPoint,
      'noticePoint': noticePoint,
      'promptPills': promptPills,
      'transparency': transparency,
      'priorities': priorities.map((p) => {
        'id': p.id,
        'category': p.category,
        'icon': p.icon,
        'headline': p.headline,
        'reason': p.reason,
        'actionTag': p.actionTag,
      }).toList(),
      'safetyStatus': safetyStatus,
    };
  }
}

class ApiPostpartumService {
  static const String _overviewKey = 'postpartum_overview_cache.json';
  static const String _briefKey = 'postpartum_brief_cache.json';

  /// Fetches complete Postpartum Command Center overview.
  /// Preserves the server's state instead of collapsing it to a nullable, so
  /// the caller can distinguish fresh data, a cached copy shown after a failure
  /// (stale), genuinely no data, and an error or offline request.
  static Future<ApiResult<PostpartumOverviewData>> getOverview() async {
    final res = await ApiContractClient.get<PostpartumOverviewData>(
      '/postpartum/overview',
      parse: (data) => PostpartumOverviewData.fromJson(Map<String, dynamic>.from(data as Map)),
    );

    if (res.data != null) {
      try {
        BlushyStorage.write(_overviewKey, res.data!.toJson());
      } catch (_) {}
      return res;
    }

    final cached = BlushyStorage.read(_overviewKey);
    if (cached.isNotEmpty) {
      try {
        return ApiResult<PostpartumOverviewData>(
          data: PostpartumOverviewData.fromJson(cached),
          state: ApiState.stale,
          lastUpdated: res.lastUpdated,
          source: res.source,
        );
      } catch (_) {}
    }

    return res;
  }

  /// Fetches dynamic Today with Docsy briefing.
  /// Preserves the server's state instead of collapsing it to a nullable, so
  /// the caller can distinguish fresh data, a cached copy shown after a failure
  /// (stale), genuinely no data, and an error or offline request.
  static Future<ApiResult<PostpartumTodayBriefData>> getTodayBrief() async {
    final res = await ApiContractClient.get<PostpartumTodayBriefData>(
      '/postpartum/today-brief',
      parse: (data) => PostpartumTodayBriefData.fromJson(Map<String, dynamic>.from(data as Map)),
    );

    if (res.data != null) {
      try {
        BlushyStorage.write(_briefKey, res.data!.toJson());
      } catch (_) {}
      return res;
    }

    final cached = BlushyStorage.read(_briefKey);
    if (cached.isNotEmpty) {
      try {
        return ApiResult<PostpartumTodayBriefData>(
          data: PostpartumTodayBriefData.fromJson(cached),
          state: ApiState.stale,
          lastUpdated: res.lastUpdated,
          source: res.source,
        );
      } catch (_) {}
    }

    return res;
  }

  /// Updates delivery calibration.
  static Future<bool> calibrate({
    String? deliveryDate,
    String? deliveryType,
    String? feedingMethod,
    bool? lowEnergyMode,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (deliveryDate != null) body['deliveryDate'] = deliveryDate;
      if (deliveryType != null) body['deliveryType'] = deliveryType;
      if (feedingMethod != null) body['feedingMethod'] = feedingMethod;
      if (lowEnergyMode != null) body['lowEnergyMode'] = lowEnergyMode;

      final res = await ApiContractClient.post(
        '/postpartum/calibrate',
        body: body,
        parse: ApiParse.map,
      );
      return res.data != null;
    } catch (_) {
      return false;
    }
  }

  /// Records daily maternal check-in.
  static Future<Map<String, dynamic>?> recordCheckin(Map<String, dynamic> checkinData) async {
    try {
      final res = await ApiContractClient.post(
        '/postpartum/check-in',
        body: checkinData,
        parse: ApiParse.map,
      );
      return res.data;
    } catch (_) {}
    return null;
  }

  /// Logs a baby event (feed session, diaper, sleep, breast comfort).
  static Future<bool> recordBabyEvent({required String type, required Map<String, dynamic> details}) async {
    try {
      final res = await ApiContractClient.post(
        '/postpartum/baby-event',
        body: {'type': type, 'details': details},
        parse: ApiParse.map,
      );
      return res.data != null;
    } catch (_) {
      return false;
    }
  }

  /// Generates a customized "I Need Help" SOS message.
  static Future<String?> generateHelpSOS(List<String> needs, [String recipientName = 'Someone']) async {
    try {
      final res = await ApiContractClient.post(
        '/postpartum/sos',
        body: {'needs': needs, 'recipientName': recipientName},
        parse: ApiParse.map,
      );
      return res.data?['message']?.toString();
    } catch (_) {}
    return null;
  }

  /// Evaluates acute safety concerns.
  static Future<Map<String, dynamic>?> evaluateSafetyTriage(Map<String, dynamic> symptoms) async {
    try {
      final res = await ApiContractClient.post(
        '/postpartum/safety-triage',
        body: symptoms,
        parse: ApiParse.map,
      );
      return res.data;
    } catch (_) {}
    return null;
  }
}
