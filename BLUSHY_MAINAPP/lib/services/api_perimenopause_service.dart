import 'dart:async';
import '../core/storage.dart';
import 'api_contract_client.dart';

class PerimenopauseConfidence {
  final String whatYouLogged;
  final String whatWereSeeing;
  final String whatThisMightMean;
  final String whatYouCanDo;
  final String confidenceLevel;

  PerimenopauseConfidence({
    required this.whatYouLogged,
    required this.whatWereSeeing,
    required this.whatThisMightMean,
    required this.whatYouCanDo,
    required this.confidenceLevel,
  });

  factory PerimenopauseConfidence.fromJson(Map<String, dynamic> json) {
    return PerimenopauseConfidence(
      whatYouLogged: json['whatYouLogged']?.toString() ?? 'You checked in with steady indicators.',
      whatWereSeeing: json['whatWereSeeing']?.toString() ?? 'Recent daily logs show steady rhythms.',
      whatThisMightMean: json['whatThisMightMean']?.toString() ?? 'Hormonal swings involve natural waves.',
      whatYouCanDo: json['whatYouCanDo']?.toString() ?? 'Continue listening to your body’s signals.',
      confidenceLevel: json['confidenceLevel']?.toString() ?? 'Baseline Steady Observation',
    );
  }

  Map<String, dynamic> toJson() => {
    'whatYouLogged': whatYouLogged,
    'whatWereSeeing': whatWereSeeing,
    'whatThisMightMean': whatThisMightMean,
    'whatYouCanDo': whatYouCanDo,
    'confidenceLevel': confidenceLevel,
  };
}

class PerimenopauseAction {
  final String id;
  final String headline;
  final String reason;
  final String difficulty;

  PerimenopauseAction({
    required this.id,
    required this.headline,
    required this.reason,
    required this.difficulty,
  });

  factory PerimenopauseAction.fromJson(Map<String, dynamic> json) {
    return PerimenopauseAction(
      id: json['id']?.toString() ?? '',
      headline: json['headline']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      difficulty: json['difficulty']?.toString() ?? 'Easy',
    );
  }
}

class PerimenopausePathway {
  final String title;
  final String icon;
  final String colorHex;
  final String bgHex;
  final List<PerimenopauseAction> actions;

  PerimenopausePathway({
    required this.title,
    required this.icon,
    required this.colorHex,
    required this.bgHex,
    required this.actions,
  });

  factory PerimenopausePathway.fromJson(Map<String, dynamic> json) {
    return PerimenopausePathway(
      title: json['title']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'nightlight_round',
      colorHex: json['colorHex']?.toString() ?? '0xFF7209B7',
      bgHex: json['bgHex']?.toString() ?? '0xFFF3E8FF',
      actions: (json['actions'] as List?)
              ?.map((a) => PerimenopauseAction.fromJson(Map<String, dynamic>.from(a as Map)))
              .toList() ??
          const [],
    );
  }
}

class PerimenopauseConnection {
  final String id;
  final String title;
  final String description;
  final String rationale;
  final String actionPrompt;

  PerimenopauseConnection({
    required this.id,
    required this.title,
    required this.description,
    required this.rationale,
    required this.actionPrompt,
  });

  factory PerimenopauseConnection.fromJson(Map<String, dynamic> json) {
    return PerimenopauseConnection(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      rationale: json['rationale']?.toString() ?? '',
      actionPrompt: json['actionPrompt']?.toString() ?? '',
    );
  }
}

class PerimenopauseArticle {
  final String id;
  final String title;
  final String readTime;
  final String topic;
  final String summary;
  final String badge;
  final String colorHex;
  final String bgHex;

  PerimenopauseArticle({
    required this.id,
    required this.title,
    required this.readTime,
    required this.topic,
    required this.summary,
    required this.badge,
    required this.colorHex,
    required this.bgHex,
  });

  factory PerimenopauseArticle.fromJson(Map<String, dynamic> json) {
    return PerimenopauseArticle(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      readTime: json['readTime']?.toString() ?? '4 min read',
      topic: json['topic']?.toString() ?? 'Understanding',
      summary: json['summary']?.toString() ?? '',
      badge: json['badge']?.toString() ?? 'Guide',
      colorHex: json['colorHex']?.toString() ?? '0xFF0D9488',
      bgHex: json['bgHex']?.toString() ?? '0xFFCCFBF1',
    );
  }
}

class PerimenopauseStoryItem {
  final String date;
  final String title;
  final String description;
  final String status;

  PerimenopauseStoryItem({
    required this.date,
    required this.title,
    required this.description,
    required this.status,
  });

  factory PerimenopauseStoryItem.fromJson(Map<String, dynamic> json) {
    return PerimenopauseStoryItem(
      date: json['date']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'completed',
    );
  }
}

class PerimenopauseOverviewData {
  final Map<String, dynamic> profile;
  final List<String> sectionOrder;
  final Map<String, dynamic> transitionPhase;
  final List<int> cycleHistory;
  final Map<String, dynamic> todayCheckin;
  final PerimenopauseConfidence confidence;
  final Map<String, dynamic> deltas;
  final List<PerimenopauseConnection> connections;
  final Map<String, dynamic> goodDays;
  final Map<String, PerimenopausePathway> actionPathways;
  final List<Map<String, dynamic>> clinicianTopics;
  final List<PerimenopauseArticle> contextualArticles;
  final List<Map<String, dynamic>> treatments;
  final List<Map<String, dynamic>> questions;
  final List<PerimenopauseStoryItem> story;
  final List<Map<String, dynamic>> safetyAlerts;

  PerimenopauseOverviewData({
    required this.profile,
    required this.sectionOrder,
    required this.transitionPhase,
    required this.cycleHistory,
    required this.todayCheckin,
    required this.confidence,
    required this.deltas,
    required this.connections,
    required this.goodDays,
    required this.actionPathways,
    required this.clinicianTopics,
    required this.contextualArticles,
    required this.treatments,
    required this.questions,
    required this.story,
    required this.safetyAlerts,
  });

  factory PerimenopauseOverviewData.fromJson(Map<String, dynamic> json) {
    final pathwaysRaw = json['actionPathways'] is Map ? json['actionPathways'] as Map : {};
    final pathways = <String, PerimenopausePathway>{};
    pathwaysRaw.forEach((k, v) {
      if (v is Map) {
        pathways[k.toString()] = PerimenopausePathway.fromJson(Map<String, dynamic>.from(v));
      }
    });

    return PerimenopauseOverviewData(
      profile: json['profile'] is Map ? Map<String, dynamic>.from(json['profile'] as Map) : {},
      sectionOrder: (json['sectionOrder'] as List?)?.map((e) => e.toString()).toList() ??
          const [
            'editorial_greeting',
            'today_with_docsy',
            'what_are_you_noticing',
            'what_changed_connections',
            'my_changing_cycle',
            'what_can_i_do',
            'focus_selector',
            'baseline_good_days',
            'treatment_intelligence',
            'tell_blushy_natural_note',
            'prepare_care',
            'intimate_health',
            'my_story',
            'learn_relevant',
            'ai_transparency',
          ],
      transitionPhase: json['transitionPhase'] is Map ? Map<String, dynamic>.from(json['transitionPhase'] as Map) : {},
      cycleHistory: (json['cycleHistory'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [31, 42, 27, 56],
      todayCheckin: json['todayCheckin'] is Map ? Map<String, dynamic>.from(json['todayCheckin'] as Map) : {},
      confidence: json['confidence'] is Map
          ? PerimenopauseConfidence.fromJson(Map<String, dynamic>.from(json['confidence'] as Map))
          : PerimenopauseConfidence(
              whatYouLogged: 'You checked in with steady indicators.',
              whatWereSeeing: 'Recent logs show steady rhythms.',
              whatThisMightMean: 'Hormonal swings involve natural waves.',
              whatYouCanDo: 'Continue listening to your body’s signals.',
              confidenceLevel: 'Steady Observation',
            ),
      deltas: json['deltas'] is Map ? Map<String, dynamic>.from(json['deltas'] as Map) : {},
      connections: (json['connections'] as List?)
              ?.map((c) => PerimenopauseConnection.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList() ??
          const [],
      goodDays: json['goodDays'] is Map ? Map<String, dynamic>.from(json['goodDays'] as Map) : {},
      actionPathways: pathways,
      clinicianTopics: (json['clinicianTopics'] as List?)?.map((t) => Map<String, dynamic>.from(t as Map)).toList() ?? const [],
      contextualArticles: (json['contextualArticles'] as List?)
              ?.map((a) => PerimenopauseArticle.fromJson(Map<String, dynamic>.from(a as Map)))
              .toList() ??
          const [],
      treatments: (json['treatments'] as List?)?.map((t) => Map<String, dynamic>.from(t as Map)).toList() ?? const [],
      questions: (json['questions'] as List?)?.map((q) => Map<String, dynamic>.from(q as Map)).toList() ?? const [],
      story: (json['story'] as List?)
              ?.map((s) => PerimenopauseStoryItem.fromJson(Map<String, dynamic>.from(s as Map)))
              .toList() ??
          const [],
      safetyAlerts: (json['safetyAlerts'] as List?)?.map((a) => Map<String, dynamic>.from(a as Map)).toList() ?? const [],
    );
  }
}

class PerimenopauseTodayBriefData {
  final String openingGreeting;
  final String whyToday;
  final String recoveryPoint;
  final String noticePoint;
  final List<String> promptPills;
  final PerimenopauseConfidence? confidence;

  PerimenopauseTodayBriefData({
    required this.openingGreeting,
    required this.whyToday,
    required this.recoveryPoint,
    required this.noticePoint,
    required this.promptPills,
    this.confidence,
  });

  factory PerimenopauseTodayBriefData.fromJson(Map<String, dynamic> json) {
    return PerimenopauseTodayBriefData(
      openingGreeting: json['openingGreeting']?.toString() ??
          'Your body is moving through its midlife transition rhythm. Give yourself credit for how you are navigating it.',
      whyToday: json['whyToday']?.toString() ?? 'Surfaced today based on your steady check-in and balanced daily energy logs.',
      recoveryPoint: json['recoveryPoint']?.toString() ?? 'Take a 10-minute walk in natural morning sunlight to anchor your circadian rhythm.',
      noticePoint: json['noticePoint']?.toString() ?? 'Notice the steady equilibrium in your body today — not every day requires fixing.',
      promptPills: (json['promptPills'] as List?)?.map((e) => e.toString()).toList() ??
          [
            'What should I expect next in my transition?',
            'How can I protect my bone density in midlife?',
            'Should I discuss HRT with my doctor?',
            'Tell Docsy more about my symptoms',
          ],
      confidence: json['confidence'] is Map
          ? PerimenopauseConfidence.fromJson(Map<String, dynamic>.from(json['confidence'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'openingGreeting': openingGreeting,
    'whyToday': whyToday,
    'recoveryPoint': recoveryPoint,
    'noticePoint': noticePoint,
    'promptPills': promptPills,
    'confidence': confidence?.toJson(),
  };
}

class ApiPerimenopauseService {
  static const String _overviewKey = 'perimenopause_overview_cache.json';
  static const String _briefKey = 'perimenopause_brief_cache.json';

  /// Fetches the complete dynamic Perimenopause Overview payload.
  /// Preserves the server's state instead of collapsing it to a nullable, so
  /// the caller can distinguish fresh data, a cached copy shown after a failure
  /// (stale), genuinely no data, and an error or offline request.
  static Future<ApiResult<PerimenopauseOverviewData>> getOverview() async {
    final res = await ApiContractClient.get<PerimenopauseOverviewData>(
      '/perimenopause/overview',
      parse: (data) => PerimenopauseOverviewData.fromJson(Map<String, dynamic>.from(data as Map)),
    );

    if (res.data != null) {
      return res;
    }

    final cached = BlushyStorage.read(_overviewKey);
    if (cached.isNotEmpty) {
      try {
        return ApiResult<PerimenopauseOverviewData>(
          data: PerimenopauseOverviewData.fromJson(cached),
          state: ApiState.stale,
          lastUpdated: res.lastUpdated,
          source: res.source,
        );
      } catch (_) {}
    }

    return res;
  }

  /// Fetches the dynamic Today with Docsy briefing.
  /// Preserves the server's state instead of collapsing it to a nullable, so
  /// the caller can distinguish fresh data, a cached copy shown after a failure
  /// (stale), genuinely no data, and an error or offline request.
  static Future<ApiResult<PerimenopauseTodayBriefData>> getTodayBrief() async {
    final res = await ApiContractClient.get<PerimenopauseTodayBriefData>(
      '/perimenopause/today-brief',
      parse: (data) => PerimenopauseTodayBriefData.fromJson(Map<String, dynamic>.from(data as Map)),
    );

    if (res.data != null) {
      return res;
    }

    final cached = BlushyStorage.read(_briefKey);
    if (cached.isNotEmpty) {
      try {
        return ApiResult<PerimenopauseTodayBriefData>(
          data: PerimenopauseTodayBriefData.fromJson(cached),
          state: ApiState.stale,
          lastUpdated: res.lastUpdated,
          source: res.source,
        );
      } catch (_) {}
    }

    return res;
  }

  /// Records daily check-in with severity + impact.
  static Future<bool> recordCheckin(Map<String, dynamic> checkinData) async {
    try {
      final res = await ApiContractClient.post(
        '/perimenopause/checkin',
        body: checkinData,
        parse: ApiParse.map,
      );
      return res.data != null;
    } catch (_) {
      return false;
    }
  }

  /// Initial calibration ("Tell Blushy Once").
  static Future<bool> calibrate(Map<String, dynamic> data) async {
    try {
      final res = await ApiContractClient.post(
        '/perimenopause/calibrate',
        body: data,
        parse: ApiParse.map,
      );
      return res.data != null;
    } catch (_) {
      return false;
    }
  }

  /// Updates current focus area.
  static Future<bool> setFocus(String focus) async {
    try {
      final res = await ApiContractClient.post(
        '/perimenopause/focus',
        body: {'focus': focus},
        parse: ApiParse.map,
      );
      return res.data != null;
    } catch (_) {
      return false;
    }
  }

  /// Updates active life mode.
  static Future<bool> setLifeMode(String lifeMode) async {
    try {
      final res = await ApiContractClient.post(
        '/perimenopause/life-mode',
        body: {'lifeMode': lifeMode},
        parse: ApiParse.map,
      );
      return res.data != null;
    } catch (_) {
      return false;
    }
  }

  /// Adds a question to the clinician notebook.
  static Future<bool> addQuestion(String text) async {
    try {
      final res = await ApiContractClient.post(
        '/perimenopause/questions',
        body: {'text': text},
        parse: ApiParse.map,
      );
      return res.data != null;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a question from the clinician notebook.
  static Future<bool> deleteQuestion(String id) async {
    try {
      await ApiContractClient.post('/perimenopause/questions/$id', parse: ApiParse.map);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Saves or updates a treatment item.
  static Future<bool> saveTreatment(Map<String, dynamic> treatment) async {
    try {
      final res = await ApiContractClient.post(
        '/perimenopause/treatment',
        body: treatment,
        parse: ApiParse.map,
      );
      return res.data != null;
    } catch (_) {
      return false;
    }
  }

  /// Natural language note parser.
  static Future<Map<String, dynamic>?> parseNaturalNote(String text) async {
    try {
      final res = await ApiContractClient.post(
        '/perimenopause/parse-note',
        body: {'text': text},
        parse: ApiParse.map,
      );
      return res.data;
    } catch (_) {
      return null;
    }
  }

  /// Fetches exportable clinician brief.
  static Future<Map<String, dynamic>?> getClinicianBrief() async {
    try {
      final res = await ApiContractClient.get(
        '/perimenopause/clinician-brief',
        parse: ApiParse.map,
      );
      return res.data;
    } catch (_) {
      return null;
    }
  }

  /// Logs a period interval.
  static Future<bool> recordCycleInterval(int days) async {
    try {
      final res = await ApiContractClient.post(
        '/perimenopause/cycle-interval',
        body: {'days': days},
        parse: ApiParse.map,
      );
      return res.data != null;
    } catch (_) {
      return false;
    }
  }
}
