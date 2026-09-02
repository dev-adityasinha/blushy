import 'package:flutter/foundation.dart';

import '../services/api_contract_client.dart';

/// Typed models for the spec-aligned `/api/v1` surface.
///
/// Each mirrors a contract the backend documents, so a card can read named
/// fields instead of digging through maps, and so the provenance of every
/// displayed value (`source`, `version`, `sourceEventIds`) travels with it.

/* ------------------------------------------------------------------ *
 * Life stage
 * ------------------------------------------------------------------ */

@immutable
class LifeStageState {
  final String? lifeStage;
  final Map<String, dynamic> branchContext;
  final Map<String, dynamic> capabilities;
  final List<HomeModuleRef> modules;
  final List<AllowedTransition> allowedTransitions;
  final List<BranchQuestion> requiredContext;
  final bool pregnancyContentBlocked;
  final bool ttcOptedIn;
  final String? configVersion;

  const LifeStageState({
    this.lifeStage,
    this.branchContext = const {},
    this.capabilities = const {},
    this.modules = const [],
    this.allowedTransitions = const [],
    this.requiredContext = const [],
    this.pregnancyContentBlocked = false,
    this.ttcOptedIn = false,
    this.configVersion,
  });

  bool get onboardingRequired => lifeStage == null;
  bool get usesCycleLanguage => capabilities['cycleLanguage'] == true;
  bool get supportsCycleTracking => capabilities['cycleTracking'] == true;
  bool get supportsPredictions => capabilities['cyclePredictions'] == true;
  bool get isPregnancy => capabilities['pregnancy'] == true;
  bool get isPostpartum => capabilities['postpartum'] == true;

  factory LifeStageState.fromJson(dynamic raw) {
    final json = ApiParse.map(raw);
    return LifeStageState(
      lifeStage: json['lifeStage']?.toString(),
      branchContext: ApiParse.map(json['branchContext']),
      capabilities: ApiParse.map(json['capabilities']),
      modules: ApiParse.list(json['modules']).map(HomeModuleRef.fromJson).toList(),
      allowedTransitions: ApiParse.list(json['allowedTransitions']).map(AllowedTransition.fromJson).toList(),
      requiredContext: ApiParse.list(json['requiredContext']).map(BranchQuestion.fromJson).toList(),
      pregnancyContentBlocked: json['pregnancyContentBlocked'] == true,
      ttcOptedIn: json['ttcOptedIn'] == true,
      configVersion: json['configVersion']?.toString(),
    );
  }
}

@immutable
class HomeModuleRef {
  final String moduleId;
  final int order;

  const HomeModuleRef({required this.moduleId, required this.order});

  factory HomeModuleRef.fromJson(Map<String, dynamic> json) => HomeModuleRef(
        moduleId: json['moduleId']?.toString() ?? '',
        order: ApiParse.intOrNull(json['order']) ?? 0,
      );
}

@immutable
class AllowedTransition {
  final String from;
  final String to;
  final bool requiresConfirmation;
  final String? reason;

  const AllowedTransition({
    required this.from,
    required this.to,
    required this.requiresConfirmation,
    this.reason,
  });

  factory AllowedTransition.fromJson(Map<String, dynamic> json) => AllowedTransition(
        from: json['from']?.toString() ?? '',
        to: json['to']?.toString() ?? '',
        requiresConfirmation: json['requiresConfirmation'] == true,
        reason: json['reason']?.toString(),
      );
}

@immutable
class LifeJourney {
  final String id;
  final String label;
  final List<BranchQuestion> requiredContext;

  const LifeJourney({required this.id, required this.label, this.requiredContext = const []});

  factory LifeJourney.fromJson(Map<String, dynamic> json) => LifeJourney(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        requiredContext: ApiParse.list(json['requiredContext']).map(BranchQuestion.fromJson).toList(),
      );
}

@immutable
class BranchQuestion {
  final String key;
  final String label;
  final String type;
  final bool required;
  final List<String> options;

  const BranchQuestion({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const [],
  });

  factory BranchQuestion.fromJson(Map<String, dynamic> json) => BranchQuestion(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        type: json['type']?.toString() ?? 'text',
        required: json['required'] == true,
        options: (json['options'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

/* ------------------------------------------------------------------ *
 * Home
 * ------------------------------------------------------------------ */

/// One Home module with its own contract state, so a single failing module
/// never breaks the screen (spec section 4).
@immutable
class HomeModule {
  final String moduleId;
  final int order;
  final ApiState state;
  final dynamic data;
  final String? source;
  final String? version;
  final String? errorCode;
  final DateTime? lastUpdated;

  const HomeModule({
    required this.moduleId,
    required this.order,
    required this.state,
    this.data,
    this.source,
    this.version,
    this.errorCode,
    this.lastUpdated,
  });

  bool get isReady => state == ApiState.ready;
  bool get isRestricted => state == ApiState.restricted;
  bool get isInsufficientData => state == ApiState.insufficientData;

  Map<String, dynamic> get asMap => ApiParse.map(data);
  List<Map<String, dynamic>> get asList => ApiParse.list(data);

  factory HomeModule.fromJson(Map<String, dynamic> json) {
    ApiState parse(String? raw) {
      switch (raw) {
        case 'ready':
          return ApiState.ready;
        case 'empty':
          return ApiState.empty;
        case 'insufficient_data':
          return ApiState.insufficientData;
        case 'restricted':
          return ApiState.restricted;
        case 'error':
          return ApiState.error;
        default:
          return ApiState.empty;
      }
    }

    return HomeModule(
      moduleId: json['moduleId']?.toString() ?? '',
      order: ApiParse.intOrNull(json['order']) ?? 0,
      state: parse(json['state']?.toString()),
      data: json['data'],
      source: json['source']?.toString(),
      version: json['version']?.toString(),
      errorCode: json['errorCode']?.toString(),
      lastUpdated: ApiParse.date(json['lastUpdated']),
    );
  }
}

@immutable
class HomeScreenModel {
  final String? lifeStage;
  final Map<String, dynamic> capabilities;
  final bool onboardingRequired;
  final bool safetyActive;
  final List<HomeModule> modules;

  const HomeScreenModel({
    this.lifeStage,
    this.capabilities = const {},
    this.onboardingRequired = false,
    this.safetyActive = false,
    this.modules = const [],
  });

  HomeModule? module(String moduleId) {
    for (final module in modules) {
      if (module.moduleId == moduleId) return module;
    }
    return null;
  }

  factory HomeScreenModel.fromJson(dynamic raw) {
    final json = ApiParse.map(raw);
    final modules = ApiParse.list(json['modules']).map(HomeModule.fromJson).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return HomeScreenModel(
      lifeStage: json['lifeStage']?.toString(),
      capabilities: ApiParse.map(json['capabilities']),
      onboardingRequired: json['onboardingRequired'] == true,
      safetyActive: json['safetyActive'] == true,
      modules: modules,
    );
  }
}

/* ------------------------------------------------------------------ *
 * Cycle
 * ------------------------------------------------------------------ */

@immutable
class CycleState {
  final String? lifeStage;
  final bool cycleTrackingAvailable;
  final bool hasData;
  final String? trackingState;
  final int? currentCycleDay;
  final String? phase;
  final String? cycleStartDate;
  final bool isCurrentPeriod;
  final bool isOverdue;
  final int? daysOverdue;
  final String? nextPeriodStartDate;
  final String? predictionEarliest;
  final String? predictionLatest;
  final int? daysUntilNextPeriod;
  final String? estimatedOvulationDate;
  final String? fertileWindowStart;
  final String? fertileWindowEnd;
  final String? confidenceLevel;
  final String? sufficiencyLabel;
  final String? sufficiencyMessage;
  final String? calculationVersion;
  final String? disclaimer;
  final String? lateNotice;
  final String? restrictedReason;
  final String? restrictedMessage;

  const CycleState({
    this.lifeStage,
    this.cycleTrackingAvailable = true,
    this.hasData = false,
    this.trackingState,
    this.currentCycleDay,
    this.phase,
    this.cycleStartDate,
    this.isCurrentPeriod = false,
    this.isOverdue = false,
    this.daysOverdue,
    this.nextPeriodStartDate,
    this.predictionEarliest,
    this.predictionLatest,
    this.daysUntilNextPeriod,
    this.estimatedOvulationDate,
    this.fertileWindowStart,
    this.fertileWindowEnd,
    this.confidenceLevel,
    this.sufficiencyLabel,
    this.sufficiencyMessage,
    this.calculationVersion,
    this.disclaimer,
    this.lateNotice,
    this.restrictedReason,
    this.restrictedMessage,
  });

  /// The predicted date is always an estimate, never a confirmed date
  /// (spec section 6).
  bool get hasPrediction => nextPeriodStartDate != null;

  factory CycleState.fromJson(dynamic raw) {
    final json = ApiParse.map(raw);
    final current = ApiParse.map(json['currentCycle']);
    final prediction = ApiParse.map(json['prediction']);
    final range = ApiParse.map(prediction['predictionRange']);
    final sufficiency = ApiParse.map(json['dataSufficiency']);

    return CycleState(
      lifeStage: json['lifeStage']?.toString(),
      cycleTrackingAvailable: json['cycleTrackingAvailable'] != false,
      hasData: json['hasData'] == true,
      trackingState: json['trackingState']?.toString(),
      currentCycleDay: ApiParse.intOrNull(current['currentCycleDay']),
      phase: current['phase']?.toString(),
      cycleStartDate: current['cycleStartDate']?.toString(),
      isCurrentPeriod: current['isCurrentPeriod'] == true,
      isOverdue: current['isOverdue'] == true,
      daysOverdue: ApiParse.intOrNull(current['daysOverdue']),
      nextPeriodStartDate: prediction['nextPeriodStartDate']?.toString(),
      predictionEarliest: range['earliestDate']?.toString(),
      predictionLatest: range['latestDate']?.toString(),
      daysUntilNextPeriod: ApiParse.intOrNull(prediction['daysUntilNextPeriod']),
      estimatedOvulationDate: prediction['estimatedOvulationDate']?.toString(),
      fertileWindowStart: prediction['fertileWindowStart']?.toString(),
      fertileWindowEnd: prediction['fertileWindowEnd']?.toString(),
      confidenceLevel: sufficiency['confidenceLevel']?.toString(),
      sufficiencyLabel: sufficiency['displayLabel']?.toString(),
      sufficiencyMessage: sufficiency['message']?.toString(),
      calculationVersion: json['calculationVersion']?.toString(),
      disclaimer: prediction['disclaimer']?.toString(),
      lateNotice: json['lateNotice']?.toString(),
      restrictedReason: json['reason']?.toString(),
      restrictedMessage: json['message']?.toString(),
    );
  }

  /// The same shape [CycleState.fromJson] reads, so a stored cycle is restored
  /// by the parser that already exists rather than a second one written to
  /// match it -- two parsers over one shape is how they drift apart.
  ///
  /// This is written to storage after every successful fetch so the card can
  /// open on the last known day instead of "Loading…". The cycle it describes
  /// is a few hours stale at worst, and is replaced as soon as the request it
  /// sits in front of returns.
  Map<String, dynamic> toJson() => {
        'lifeStage': lifeStage,
        'cycleTrackingAvailable': cycleTrackingAvailable,
        'hasData': hasData,
        'trackingState': trackingState,
        'calculationVersion': calculationVersion,
        'lateNotice': lateNotice,
        'reason': restrictedReason,
        'message': restrictedMessage,
        'currentCycle': {
          'currentCycleDay': currentCycleDay,
          'phase': phase,
          'cycleStartDate': cycleStartDate,
          'isCurrentPeriod': isCurrentPeriod,
          'isOverdue': isOverdue,
          'daysOverdue': daysOverdue,
        },
        'prediction': {
          'nextPeriodStartDate': nextPeriodStartDate,
          'daysUntilNextPeriod': daysUntilNextPeriod,
          'estimatedOvulationDate': estimatedOvulationDate,
          'fertileWindowStart': fertileWindowStart,
          'fertileWindowEnd': fertileWindowEnd,
          'disclaimer': disclaimer,
          'predictionRange': {
            'earliestDate': predictionEarliest,
            'latestDate': predictionLatest,
          },
        },
        'dataSufficiency': {
          'confidenceLevel': confidenceLevel,
          'displayLabel': sufficiencyLabel,
          'message': sufficiencyMessage,
        },
      };
}

/* ------------------------------------------------------------------ *
 * Insights and care plan
 * ------------------------------------------------------------------ */

@immutable
class Insight {
  final String id;
  final String type;
  final String title;
  final String description;
  final List<String> sourceEventIds;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double? confidence;
  final String? strength;
  final String status;
  final DateTime? generatedAt;
  final String? modelVersion;
  final String? engineVersion;
  final String source;
  final String? actionId;
  final int? observationCount;

  const Insight({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.sourceEventIds = const [],
    this.periodStart,
    this.periodEnd,
    this.confidence,
    this.strength,
    this.status = 'active',
    this.generatedAt,
    this.modelVersion,
    this.engineVersion,
    this.source = 'rule',
    this.actionId,
    this.observationCount,
  });

  /// Insights describe correlation only; nothing here is a causal or medical
  /// claim (spec section 8).
  bool get isObservationOnly => true;

  factory Insight.fromJson(Map<String, dynamic> json) => Insight(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        sourceEventIds: (json['sourceEventIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        periodStart: ApiParse.date(json['periodStart']),
        periodEnd: ApiParse.date(json['periodEnd']),
        confidence: ApiParse.doubleOrNull(json['confidence']),
        strength: json['strength']?.toString(),
        status: json['status']?.toString() ?? 'active',
        generatedAt: ApiParse.date(json['generatedAt']),
        modelVersion: json['modelVersion']?.toString(),
        engineVersion: json['engineVersion']?.toString(),
        source: json['source']?.toString() ?? 'rule',
        actionId: json['actionId']?.toString(),
        observationCount: ApiParse.intOrNull(json['observationCount']),
      );
}

@immutable
class CareAction {
  final String id;
  final String title;
  final String description;
  final String? reason;
  final String category;
  final String priority;
  final String source;
  final String? contentId;
  final String cta;
  final String completionState;
  final DateTime? validUntil;

  const CareAction({
    required this.id,
    required this.title,
    required this.description,
    this.reason,
    required this.category,
    this.priority = 'normal',
    this.source = 'rule',
    this.contentId,
    this.cta = 'Start',
    this.completionState = 'not_started',
    this.validUntil,
  });

  bool get isHighPriority => priority == 'high';
  bool get isCompleted => completionState == 'completed';

  factory CareAction.fromJson(Map<String, dynamic> json) => CareAction(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        reason: json['reason']?.toString(),
        category: json['category']?.toString() ?? 'general',
        priority: json['priority']?.toString() ?? 'normal',
        source: json['source']?.toString() ?? 'rule',
        contentId: json['contentId']?.toString(),
        cta: json['cta']?.toString() ?? 'Start',
        completionState: json['completionState']?.toString() ?? 'not_started',
        validUntil: ApiParse.date(json['validUntil']),
      );
}

@immutable
class CarePlan {
  final List<CareAction> actions;
  final String adaptiveMode;
  final bool suppressed;
  final String? suppressionReason;
  final Map<String, dynamic> energyBudget;
  final String? lifeScene;

  const CarePlan({
    this.actions = const [],
    this.adaptiveMode = 'standard',
    this.suppressed = false,
    this.suppressionReason,
    this.energyBudget = const {},
    this.lifeScene,
  });

  factory CarePlan.fromJson(dynamic raw) {
    final json = ApiParse.map(raw);
    return CarePlan(
      actions: ApiParse.list(json['actions']).map(CareAction.fromJson).toList(),
      adaptiveMode: json['adaptiveMode']?.toString() ?? 'standard',
      suppressed: json['suppressed'] == true,
      suppressionReason: json['suppressionReason']?.toString(),
      energyBudget: ApiParse.map(json['energyBudget']),
      lifeScene: json['lifeScene']?.toString(),
    );
  }
}

/* ------------------------------------------------------------------ *
 * Events and timeline
 * ------------------------------------------------------------------ */

@immutable
class HealthEvent {
  final String eventId;
  final String eventType;
  final DateTime timestamp;
  final String source;
  final int schemaVersion;
  final Map<String, dynamic> payload;
  final bool userConfirmed;
  final String displayText;

  const HealthEvent({
    required this.eventId,
    required this.eventType,
    required this.timestamp,
    required this.source,
    this.schemaVersion = 1,
    this.payload = const {},
    this.userConfirmed = true,
    this.displayText = '',
  });

  /// AI-derived events are never treated as user confirmed (spec section 6).
  bool get isAiDerived => source == 'ai_derived';

  factory HealthEvent.fromJson(Map<String, dynamic> json) => HealthEvent(
        eventId: json['eventId']?.toString() ?? '',
        eventType: json['eventType']?.toString() ?? '',
        timestamp: ApiParse.date(json['timestamp']) ?? DateTime.now(),
        source: json['source']?.toString() ?? 'manual',
        schemaVersion: ApiParse.intOrNull(json['schemaVersion']) ?? 1,
        payload: ApiParse.map(json['payload']),
        userConfirmed: json['userConfirmed'] != false,
        displayText: json['displayText']?.toString() ?? '',
      );
}

@immutable
class TimelineEntry {
  final String eventId;
  final String eventType;
  final DateTime date;
  final String displayText;
  final String source;
  final bool editable;
  final Map<String, dynamic> detail;

  const TimelineEntry({
    required this.eventId,
    required this.eventType,
    required this.date,
    required this.displayText,
    this.source = 'manual',
    this.editable = true,
    this.detail = const {},
  });

  factory TimelineEntry.fromJson(Map<String, dynamic> json) => TimelineEntry(
        eventId: json['eventId']?.toString() ?? '',
        eventType: json['eventType']?.toString() ?? '',
        date: ApiParse.date(json['date']) ?? DateTime.now(),
        displayText: json['displayText']?.toString() ?? '',
        source: json['source']?.toString() ?? 'manual',
        editable: json['editable'] != false,
        detail: ApiParse.map(json['detail']),
      );
}

@immutable
class Timeline {
  final List<TimelineEntry> entries;
  final String historyType;
  final int total;
  final bool hasMore;

  const Timeline({
    this.entries = const [],
    this.historyType = 'cycle_and_wellness',
    this.total = 0,
    this.hasMore = false,
  });

  /// Menopause uses wellness and symptom history rather than cycle history
  /// (spec section 11).
  bool get usesCycleHistory => historyType == 'cycle_and_wellness';

  factory Timeline.fromJson(dynamic raw) {
    final json = ApiParse.map(raw);
    final pagination = ApiParse.map(json['pagination']);
    return Timeline(
      entries: ApiParse.list(json['entries']).map(TimelineEntry.fromJson).toList(),
      historyType: json['historyType']?.toString() ?? 'cycle_and_wellness',
      total: ApiParse.intOrNull(pagination['total']) ?? 0,
      hasMore: pagination['hasMore'] == true,
    );
  }
}

/* ------------------------------------------------------------------ *
 * Safety
 * ------------------------------------------------------------------ */

@immutable
class SafetyStep {
  final String ruleId;
  final String title;
  final String instruction;
  final String level;
  final String? source;
  final String? reviewer;
  final String? reviewDate;
  final Map<String, dynamic>? article;

  const SafetyStep({
    required this.ruleId,
    required this.title,
    required this.instruction,
    required this.level,
    this.source,
    this.reviewer,
    this.reviewDate,
    this.article,
  });

  bool get isEmergency => level == 'emergency';

  factory SafetyStep.fromJson(Map<String, dynamic> json) => SafetyStep(
        ruleId: json['ruleId']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        instruction: json['instruction']?.toString() ?? '',
        level: json['level']?.toString() ?? 'monitor',
        source: json['source']?.toString(),
        reviewer: json['reviewer']?.toString(),
        reviewDate: json['reviewDate']?.toString(),
        article: json['article'] is Map ? ApiParse.map(json['article']) : null,
      );
}

@immutable
class EmergencyResource {
  final String id;
  final String name;
  final String? contact;
  final String type;
  final String? note;

  const EmergencyResource({
    required this.id,
    required this.name,
    this.contact,
    required this.type,
    this.note,
  });

  factory EmergencyResource.fromJson(Map<String, dynamic> json) => EmergencyResource(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        contact: json['contact']?.toString(),
        type: json['type']?.toString() ?? 'emergency',
        note: json['note']?.toString(),
      );
}

@immutable
class SafetyFlow {
  final bool triggered;
  final String? level;
  final bool suppressWellnessContent;
  final List<SafetyStep> steps;
  final String? region;
  final String? emergencyNumber;
  final List<EmergencyResource> resources;

  const SafetyFlow({
    this.triggered = false,
    this.level,
    this.suppressWellnessContent = false,
    this.steps = const [],
    this.region,
    this.emergencyNumber,
    this.resources = const [],
  });

  bool get isEmergency => level == 'emergency';

  factory SafetyFlow.fromJson(dynamic raw) {
    final json = ApiParse.map(raw);
    final flow = json.containsKey('flow') ? ApiParse.map(json['flow']) : json;
    final resources = ApiParse.map(flow['emergencyResources']);

    return SafetyFlow(
      triggered: json['triggered'] == true || flow['steps'] != null,
      level: (json['level'] ?? flow['level'])?.toString(),
      suppressWellnessContent: (json['suppressWellnessContent'] ?? flow['suppressWellnessContent']) == true,
      steps: ApiParse.list(flow['steps']).map(SafetyStep.fromJson).toList(),
      region: (json['region'] ?? flow['region'] ?? resources['region'])?.toString(),
      emergencyNumber: resources['emergencyNumber']?.toString(),
      resources: ApiParse.list(resources['resources']).map(EmergencyResource.fromJson).toList(),
    );
  }
}

@immutable
class ScreeningResult {
  final String screeningId;
  final String instrumentId;
  final String instrumentName;
  final String instrumentVersion;
  final int totalScore;
  final int maxScore;
  final String outcome;
  final bool crisisItemPositive;
  final bool requiresProfessionalSupport;
  final String? disclaimer;
  final DateTime? completedAt;

  const ScreeningResult({
    required this.screeningId,
    required this.instrumentId,
    required this.instrumentName,
    required this.instrumentVersion,
    required this.totalScore,
    required this.maxScore,
    required this.outcome,
    this.crisisItemPositive = false,
    this.requiresProfessionalSupport = false,
    this.disclaimer,
    this.completedAt,
  });

  /// A screening result is never a diagnosis (spec section 16).
  bool get isDiagnosis => false;

  factory ScreeningResult.fromJson(Map<String, dynamic> json) => ScreeningResult(
        screeningId: json['screeningId']?.toString() ?? '',
        instrumentId: json['instrumentId']?.toString() ?? '',
        instrumentName: json['instrumentName']?.toString() ?? '',
        instrumentVersion: json['instrumentVersion']?.toString() ?? '',
        totalScore: ApiParse.intOrNull(json['totalScore']) ?? 0,
        maxScore: ApiParse.intOrNull(json['maxScore']) ?? 0,
        outcome: json['outcome']?.toString() ?? 'below_threshold',
        crisisItemPositive: json['crisisItemPositive'] == true,
        requiresProfessionalSupport: json['requiresProfessionalSupport'] == true,
        disclaimer: json['disclaimer']?.toString(),
        completedAt: ApiParse.date(json['completedAt']),
      );
}

/* ------------------------------------------------------------------ *
 * Partner
 * ------------------------------------------------------------------ */

@immutable
class PartnerPermission {
  final String key;
  final String label;
  final String? example;
  final bool enabled;
  final bool alwaysOn;

  /// The grant keys this category unlocks.
  ///
  /// Returned by the permission matrix endpoint. Reading them from the server
  /// avoids a local key table, which drifts silently: a category whose grants
  /// changed would just start reporting itself as not shared.
  final List<String> grants;

  const PartnerPermission({
    required this.key,
    required this.label,
    this.example,
    this.enabled = false,
    this.alwaysOn = false,
    this.grants = const [],
  });

  factory PartnerPermission.fromJson(Map<String, dynamic> json) => PartnerPermission(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        example: json['example']?.toString(),
        enabled: json['enabled'] == true,
        alwaysOn: json['alwaysOn'] == true,
        grants: (json['grants'] as List?)?.map((g) => g.toString()).toList() ?? const [],
      );
}

@immutable
class PartnerSharingState {
  final String connectionId;
  final String connectionState;
  final List<PartnerPermission> permissions;

  const PartnerSharingState({
    required this.connectionId,
    required this.connectionState,
    this.permissions = const [],
  });

  bool get isActive => connectionState == 'accepted';

  /// What is currently shared, so the woman can always see it
  /// (spec section 10).
  List<PartnerPermission> get enabled => permissions.where((p) => p.enabled).toList();

  factory PartnerSharingState.fromJson(dynamic raw) {
    final json = ApiParse.map(raw);
    return PartnerSharingState(
      connectionId: json['connectionId']?.toString() ?? '',
      connectionState: json['connectionState']?.toString() ?? 'revoked',
      permissions: ApiParse.list(json['permissions']).map(PartnerPermission.fromJson).toList(),
    );
  }
}

@immutable
class SharedSection {
  final String key;
  final bool enabled;
  final List<Map<String, dynamic>> items;

  const SharedSection({required this.key, required this.enabled, this.items = const []});

  factory SharedSection.fromJson(Map<String, dynamic> json) => SharedSection(
        key: json['key']?.toString() ?? '',
        enabled: json['enabled'] == true,
        items: ApiParse.list(json['items']),
      );
}

@immutable
class PartnerHomeModel {
  final String prompt;
  final String? partnerPreferredName;
  final String? lifeStageContext;
  final Map<String, dynamic> permittedContext;
  final List<String> allowedGrants;
  final List<SupportRequest> supportRequests;
  final List<SharedSection> sharedSections;
  final bool nothingShared;
  final bool relationshipActive;

  const PartnerHomeModel({
    this.prompt = 'How can I show up today?',
    this.partnerPreferredName,
    this.lifeStageContext,
    this.permittedContext = const {},
    this.allowedGrants = const [],
    this.supportRequests = const [],
    this.sharedSections = const [],
    this.nothingShared = true,
    this.relationshipActive = false,
  });

  factory PartnerHomeModel.fromJson(dynamic raw) {
    final json = ApiParse.map(raw);
    final greeting = ApiParse.map(json['greeting']);
    return PartnerHomeModel(
      prompt: greeting['prompt']?.toString() ?? 'How can I show up today?',
      partnerPreferredName: greeting['partnerPreferredName']?.toString(),
      lifeStageContext: json['lifeStageContext']?.toString(),
      permittedContext: ApiParse.map(json['permittedContext']),
      allowedGrants: (json['allowedGrants'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      supportRequests: ApiParse.list(json['supportRequests']).map(SupportRequest.fromJson).toList(),
      sharedSections: ApiParse.list(json['sharedSections']).map(SharedSection.fromJson).toList(),
      nothingShared: json['nothingShared'] != false,
      relationshipActive: json['relationshipActive'] == true,
    );
  }
}

@immutable
class SupportRequest {
  final String requestId;
  final String type;
  final String? label;
  final String message;
  final String state;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? acknowledgedAt;
  final DateTime? completedAt;

  const SupportRequest({
    required this.requestId,
    required this.type,
    this.label,
    required this.message,
    required this.state,
    this.createdAt,
    this.expiresAt,
    this.acknowledgedAt,
    this.completedAt,
  });

  bool get isPending => state == 'pending';
  bool get isActionable => state == 'pending' || state == 'acknowledged';

  factory SupportRequest.fromJson(Map<String, dynamic> json) => SupportRequest(
        requestId: json['requestId']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        label: json['label']?.toString(),
        message: json['message']?.toString() ?? '',
        state: json['state']?.toString() ?? 'pending',
        createdAt: ApiParse.date(json['createdAt']),
        expiresAt: ApiParse.date(json['expiresAt']),
        acknowledgedAt: ApiParse.date(json['acknowledgedAt']),
        completedAt: ApiParse.date(json['completedAt']),
      );
}

/* ------------------------------------------------------------------ *
 * Content library
 * ------------------------------------------------------------------ */

@immutable
class LibraryItem {
  final String contentId;
  final String title;
  final String body;
  final String? summary;
  final String? source;
  final String? reviewer;
  final String? reviewDate;
  final String version;
  final List<String> lifeStages;
  final List<String> topics;
  final String audience;
  final String contentType;
  final int? readingTimeMinutes;
  final String? mediaUrl;
  final int progressPercent;
  final bool completed;
  final bool bookmarked;

  const LibraryItem({
    required this.contentId,
    required this.title,
    required this.body,
    this.summary,
    this.source,
    this.reviewer,
    this.reviewDate,
    this.version = '1.0.0',
    this.lifeStages = const [],
    this.topics = const [],
    this.audience = 'female_user',
    this.contentType = 'article',
    this.readingTimeMinutes,
    this.mediaUrl,
    this.progressPercent = 0,
    this.completed = false,
    this.bookmarked = false,
  });

  /// Clinical content always carries its source and version (spec section 17).
  bool get hasClinicalProvenance => source != null && source!.isNotEmpty;

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    final progress = ApiParse.map(json['progress']);
    return LibraryItem(
      contentId: json['contentId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      summary: json['summary']?.toString(),
      source: json['source']?.toString(),
      reviewer: json['reviewer']?.toString(),
      reviewDate: json['reviewDate']?.toString(),
      version: json['version']?.toString() ?? '1.0.0',
      lifeStages: (json['lifeStages'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      topics: (json['topics'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      audience: json['audience']?.toString() ?? 'female_user',
      contentType: json['contentType']?.toString() ?? 'article',
      readingTimeMinutes: ApiParse.intOrNull(json['readingTimeMinutes']),
      mediaUrl: json['mediaUrl']?.toString(),
      progressPercent: ApiParse.intOrNull(progress['progressPercent']) ?? 0,
      completed: progress['completed'] == true,
      bookmarked: progress['bookmarked'] == true,
    );
  }
}

/* ------------------------------------------------------------------ *
 * Notifications
 * ------------------------------------------------------------------ */

@immutable
class NotificationPreferences {
  final Map<String, bool> categories;
  final bool quietHoursEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;
  final bool hideSensitiveOnLockScreen;
  final String? timezone;

  const NotificationPreferences({
    this.categories = const {},
    this.quietHoursEnabled = false,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '07:00',
    this.hideSensitiveOnLockScreen = true,
    this.timezone,
  });

  factory NotificationPreferences.fromJson(dynamic raw) {
    final json = ApiParse.map(raw);
    final quiet = ApiParse.map(json['quietHours']);
    final categories = <String, bool>{};
    ApiParse.map(json['categories']).forEach((key, value) {
      categories[key] = value == true;
    });

    return NotificationPreferences(
      categories: categories,
      quietHoursEnabled: quiet['enabled'] == true,
      quietHoursStart: quiet['start']?.toString() ?? '22:00',
      quietHoursEnd: quiet['end']?.toString() ?? '07:00',
      hideSensitiveOnLockScreen: json['hideSensitiveOnLockScreen'] != false,
      timezone: json['timezone']?.toString(),
    );
  }

  Map<String, dynamic> toPatch() => {
        'categories': categories,
        'quietHours': {'enabled': quietHoursEnabled, 'start': quietHoursStart, 'end': quietHoursEnd},
        'hideSensitiveOnLockScreen': hideSensitiveOnLockScreen,
        if (timezone != null) 'timezone': timezone,
      };
}

@immutable
class BlushyNotification {
  final String notificationId;
  final String category;
  final String title;
  final String? body;
  final String? entityType;
  final String? entityId;
  final DateTime? scheduledFor;
  final DateTime? readAt;
  final String status;

  const BlushyNotification({
    required this.notificationId,
    required this.category,
    required this.title,
    this.body,
    this.entityType,
    this.entityId,
    this.scheduledFor,
    this.readAt,
    this.status = 'scheduled',
  });

  bool get isUnread => readAt == null;

  factory BlushyNotification.fromJson(Map<String, dynamic> json) => BlushyNotification(
        notificationId: json['notificationId']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString(),
        entityType: json['entityType']?.toString(),
        entityId: json['entityId']?.toString(),
        scheduledFor: ApiParse.date(json['scheduledFor']),
        readAt: ApiParse.date(json['readAt']),
        status: json['status']?.toString() ?? 'scheduled',
      );
}
