import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import '../services/auth_storage.dart';
import '../services/api_auth_service.dart';
import '../services/partner_websocket_service.dart';
import '../services/sia_dashboard_service.dart';
import '../services/api_period_service.dart';
import '../services/api_partner_service.dart';
import 'cycle_calculator.dart';
import 'storage.dart';

enum AppEntryState {
  unauthenticated,
  onboardingRequired,
  authenticated
}

enum CycleTrackingPreference { enabled, disabled, unknown }
enum CyclePattern { predictable, variable, unknown }
enum DataConfidence { high, medium, low }
enum LifeContext {
  none,
  pregnancy,
  postpartum,
  breastfeeding,
  perimenopause,
  menopause,
  hormonalContraception,
  other
}

class UserPreferences {
  final bool wantsCycleTracking;
  final bool wantsVoiceFeatures;
  final bool wantsPersonalizedRecommendations;
  final bool wantsSiaMemory;
  final bool wantsNotifications;

  UserPreferences({
    this.wantsCycleTracking = true,
    this.wantsVoiceFeatures = true,
    this.wantsPersonalizedRecommendations = true,
    this.wantsSiaMemory = true,
    this.wantsNotifications = true,
  });
}

class BehavioralSignals {
  final int siaConversationCount;
  final List<String> engagedArticles;
  final int totalLoggedSymptoms;

  BehavioralSignals({
    this.siaConversationCount = 0,
    this.engagedArticles = const [],
    this.totalLoggedSymptoms = 0,
  });
}

class Medication {
  final String name;
  final String? category;
  final String? notes;
  final DateTime? startDate;

  Medication({
    required this.name,
    this.category,
    this.notes,
    this.startDate,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'notes': notes,
    'startDate': startDate?.toIso8601String(),
  };

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
    name: json['name'],
    category: json['category'],
    notes: json['notes'],
    startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
  );
}

class PersonalContext {
  final String? userName;
  final DateTime? dateOfBirth;
  final double? weight;
  final String? lifeStage;
  final Set<String> activeLifeStages;
  final DateTime? dueDate;
  final DateTime? babyBirthDate;
  final CycleTrackingPreference trackingPreference;
  final CyclePattern cyclePattern;
  final DataConfidence confidence;
  final Set<LifeContext> lifeContexts;
  final Set<String> userGoals;
  final Set<String> userSymptoms;
  final Set<String> medicalConditions;
  final UserPreferences preferences;
  final int? cycleLength;
  final int? cycleDay;
  final String? cyclePhase;
  final DateTime? lastPeriodStart;
  final List<Medication> medications;

  PersonalContext({
    this.userName,
    this.dateOfBirth,
    this.weight,
    this.lifeStage,
    this.activeLifeStages = const {},
    this.dueDate,
    this.babyBirthDate,
    required this.trackingPreference,
    required this.cyclePattern,
    required this.confidence,
    required this.lifeContexts,
    required this.userGoals,
    this.userSymptoms = const {},
    this.medicalConditions = const {},
    required this.preferences,
    this.cycleLength,
    this.cycleDay,
    this.cyclePhase,
    this.lastPeriodStart,
    this.medications = const [],
  });

  PersonalContext copyWith({
    String? userName,
    DateTime? dateOfBirth,
    double? weight,
    String? lifeStage,
    Set<String>? activeLifeStages,
    DateTime? dueDate,
    DateTime? babyBirthDate,
    CycleTrackingPreference? trackingPreference,
    CyclePattern? cyclePattern,
    DataConfidence? confidence,
    Set<LifeContext>? lifeContexts,
    Set<String>? userGoals,
    Set<String>? userSymptoms,
    Set<String>? medicalConditions,
    UserPreferences? preferences,
    int? cycleLength,
    int? cycleDay,
    String? cyclePhase,
    DateTime? lastPeriodStart,
    List<Medication>? medications,
  }) {
    return PersonalContext(
      userName: userName ?? this.userName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      weight: weight ?? this.weight,
      lifeStage: lifeStage ?? this.lifeStage,
      activeLifeStages: activeLifeStages ?? this.activeLifeStages,
      dueDate: dueDate ?? this.dueDate,
      babyBirthDate: babyBirthDate ?? this.babyBirthDate,
      trackingPreference: trackingPreference ?? this.trackingPreference,
      cyclePattern: cyclePattern ?? this.cyclePattern,
      confidence: confidence ?? this.confidence,
      lifeContexts: lifeContexts ?? this.lifeContexts,
      userGoals: userGoals ?? this.userGoals,
      userSymptoms: userSymptoms ?? this.userSymptoms,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      preferences: preferences ?? this.preferences,
      cycleLength: cycleLength ?? this.cycleLength,
      cycleDay: cycleDay ?? this.cycleDay,
      cyclePhase: cyclePhase ?? this.cyclePhase,
      lastPeriodStart: lastPeriodStart ?? this.lastPeriodStart,
      medications: medications ?? this.medications,
    );
  }
}



class CurrentWellbeingState {
  final int? energy;          // 1 - 10
  final int? mood;            // 1 - 10
  final int? sleepQuality;    // 1 - 10
  final List<String> symptoms;
  final DateTime? lastCheckIn;
  final DateTime? lastSiaConversation;
  final bool periodActive;

  CurrentWellbeingState({
    this.energy,
    this.mood,
    this.sleepQuality,
    this.symptoms = const [],
    this.lastCheckIn,
    this.lastSiaConversation,
    this.periodActive = false,
  });

  CurrentWellbeingState copyWith({
    int? energy,
    int? mood,
    int? sleepQuality,
    List<String>? symptoms,
    DateTime? lastCheckIn,
    DateTime? lastSiaConversation,
    bool? periodActive,
  }) {
    return CurrentWellbeingState(
      energy: energy ?? this.energy,
      mood: mood ?? this.mood,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      symptoms: symptoms ?? this.symptoms,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      lastSiaConversation: lastSiaConversation ?? this.lastSiaConversation,
      periodActive: periodActive ?? this.periodActive,
    );
  }
}

class SiaInsight {
  final String id;
  final String title;
  final String description;
  final String type; // 'observation' | 'recommendation' | 'reminder'
  final double confidence;

  SiaInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.confidence = 1.0,
  });
}

enum CycleCardMode { predictable, variable, learning, wellbeing, lifeContext }

class ContextResolver {
  static CycleCardMode resolve(PersonalContext context, CurrentWellbeingState wellbeing) {
    if (!context.preferences.wantsCycleTracking || context.trackingPreference == CycleTrackingPreference.disabled) {
      return CycleCardMode.wellbeing;
    }
    if (context.lifeContexts.isNotEmpty && !context.lifeContexts.contains(LifeContext.none)) {
      return CycleCardMode.lifeContext;
    }
    if (context.confidence == DataConfidence.low) {
      return CycleCardMode.learning;
    }
    if (context.cyclePattern == CyclePattern.variable) {
      return CycleCardMode.variable;
    }
    return CycleCardMode.predictable;
  }
}

class CandidateAction {
  final String id;
  final String label;
  final IconData icon;
  int priority;
  final String destination;

  CandidateAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.priority,
    required this.destination,
  });
}

class AdaptiveActionRanker {
  static List<CandidateAction> rankActions(PersonalContext context, CurrentWellbeingState wellbeing) {
    List<CandidateAction> actions = [
      CandidateAction(id: 'a1', label: 'Log Symptoms', icon: Icons.health_and_safety, priority: 5, destination: 'log'),
      CandidateAction(id: 'a2', label: 'Breathing Exercise', icon: Icons.air, priority: 4, destination: 'breathe'),
      CandidateAction(id: 'a3', label: 'Sia Chat', icon: Icons.chat_bubble_outline, priority: 3, destination: 'chat'),
      CandidateAction(id: 'a4', label: 'Hydration', icon: Icons.water_drop_outlined, priority: 2, destination: 'water'),
      CandidateAction(id: 'a5', label: 'Cycle Insights', icon: Icons.auto_graph, priority: 1, destination: 'insights'),
    ];

    if (wellbeing.symptoms.isNotEmpty) {
       actions.firstWhere((a) => a.id == 'a1').priority += 5;
    }
    if (context.cyclePhase == 'Luteal Phase' || wellbeing.energy != null && wellbeing.energy! < 5) {
       actions.firstWhere((a) => a.id == 'a2').priority += 5;
    }
    if (wellbeing.periodActive) {
       actions.firstWhere((a) => a.id == 'a1').priority += 10;
       actions.firstWhere((a) => a.id == 'a4').priority += 5;
    }

    actions.sort((a, b) => b.priority.compareTo(a.priority));
    return actions.take(4).toList();
  }
}

class SiaMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? actionSuggestions;

  SiaMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.actionSuggestions,
  });
}

class JournalEntry {
  final String content;
  final String mood;
  final DateTime timestamp;

  JournalEntry({
    required this.content,
    required this.mood,
    required this.timestamp,
  });
}

class BlushyOSState extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _onboardingCompleted = false;
  int _onboardingStep = 0;
  bool _argumentModeActive = false;
  bool _hasChosenExperience = false;
  String _selectedRole = 'woman';
  final List<JournalEntry> _journals = [];
  final List<SiaMessage> _siaMessages = [];

  bool get isAuthenticated => _isAuthenticated;
  bool get onboardingCompleted => _onboardingCompleted;
  int get onboardingStep => _onboardingStep;
  bool get argumentModeActive => _argumentModeActive;
  bool get hasChosenExperience => _hasChosenExperience;
  String get selectedRole => _selectedRole;
  List<JournalEntry> get journals => List.unmodifiable(_journals);
  List<SiaMessage> get siaMessages => List.unmodifiable(_siaMessages);

  void addJournal(String content, String mood) {
    _journals.add(JournalEntry(
      content: content,
      mood: mood,
      timestamp: DateTime.now(),
    ));
    _saveState();
    notifyListeners();
  }

  void addSiaMessage(String text, {bool isUser = true, List<String>? actionSuggestions}) {
    _siaMessages.add(SiaMessage(
      text: text,
      isUser: isUser,
      timestamp: DateTime.now(),
      actionSuggestions: actionSuggestions,
    ));
    notifyListeners();
  }

  void setSelectedRole(String role) {
    _selectedRole = (role == 'partner' || role == 'man') ? 'partner' : 'woman';
    _hasChosenExperience = true;
    AuthStorage.saveRole(_selectedRole);
    _saveState();
    notifyListeners();
  }

  void resetChosenExperience() {
    _hasChosenExperience = false;
    notifyListeners();
  }

  void setArgumentModeActive(bool val) {
    _argumentModeActive = val;
    _saveState();
    notifyListeners();
  }

  AppEntryState get entryState {
    if (!_isAuthenticated) return AppEntryState.unauthenticated;
    if (!_onboardingCompleted) return AppEntryState.onboardingRequired;
    return AppEntryState.authenticated;
  }

  BlushyOSState() {
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final token = AuthStorage.getToken();
      if (token != null && token.isNotEmpty) {
        _isAuthenticated = true;
        if (AuthStorage.isOnboardingCompleted()) {
          _onboardingCompleted = true;
        }
      }

      final savedRole = AuthStorage.getRole();
      if (savedRole != null && savedRole.isNotEmpty) {
        _selectedRole = (savedRole == 'partner' || savedRole == 'man') ? 'partner' : 'woman';
        if (_isAuthenticated) {
          _hasChosenExperience = true;
        }
      }

      final data = BlushyStorage.read('blushy_prefs.json');
      if (data.isNotEmpty) {
        _isAuthenticated = data['isAuthenticated'] ?? _isAuthenticated;
        _onboardingCompleted = (data['onboardingCompleted'] == true) || AuthStorage.isOnboardingCompleted();
        _onboardingStep = data['onboardingStep'] ?? 0;
        _argumentModeActive = data['argumentModeActive'] ?? false;
        _customAiBriefing = data['customAiBriefing'];
        if (data['journals'] != null && data['journals'] is List) {
          final List<dynamic> rawJournals = data['journals'];
          _journals.clear();
          for (final item in rawJournals) {
            if (item is Map) {
              _journals.add(JournalEntry(
                content: item['content']?.toString() ?? '',
                mood: item['mood']?.toString() ?? '',
                timestamp: item['timestamp'] != null
                    ? DateTime.tryParse(item['timestamp'].toString()) ?? DateTime.now()
                    : DateTime.now(),
              ));
            }
          }
        }

        if (data['personalContext'] != null) {
          final pc = data['personalContext'];
          final List<dynamic> rawMedications = pc['medications'] ?? [];
          final meds = rawMedications.map((m) => Medication.fromJson(m)).toList();
          
          final String? savedLifeStage = pc['lifeStage'];
          final List<dynamic>? rawActiveStages = pc['activeLifeStages'];
          Set<String> activeStages = rawActiveStages != null 
              ? rawActiveStages.map((e) => e.toString()).toSet() 
              : (savedLifeStage != null ? {savedLifeStage} : {});
          
          // Fallback to user_profile.json if activeStages is empty
          if (activeStages.isEmpty) {
            try {
              final profileFile = BlushyStorage.read('user_profile.json');
              final prof = profileFile['profile'] ?? profileFile;
              if (prof is Map) {
                if (prof['activeLifeStages'] is List) {
                  activeStages = (prof['activeLifeStages'] as List).map((e) => e.toString()).toSet();
                } else if (prof['lifeStage'] != null) {
                  activeStages = {prof['lifeStage'].toString()};
                }
              }
            } catch (_) {}
          }
          if (activeStages.isEmpty) {
            activeStages = {'reproductiveYears'};
          }
          
          _personalContext = PersonalContext(
            userName: pc['userName'],
            dateOfBirth: pc['dateOfBirth'] != null ? DateTime.parse(pc['dateOfBirth']) : null,
            weight: pc['weight'] != null ? (pc['weight'] as num).toDouble() : null,
            lifeStage: savedLifeStage ?? activeStages.first,
            activeLifeStages: activeStages,
            trackingPreference: CycleTrackingPreference.values.firstWhere(
              (e) => e.toString() == pc['trackingPreference'],
              orElse: () => CycleTrackingPreference.unknown,
            ),
            cyclePattern: CyclePattern.values.firstWhere(
              (e) => e.toString() == pc['cyclePattern'],
              orElse: () => CyclePattern.unknown,
            ),
            confidence: DataConfidence.values.firstWhere(
              (e) => e.toString() == pc['confidence'],
              orElse: () => DataConfidence.low,
            ),
            lifeContexts: (pc['lifeContexts'] as List<dynamic>?)
                    ?.map((l) => LifeContext.values.firstWhere((e) => e.toString() == l))
                    .toSet() ?? {LifeContext.none},
            userGoals: (pc['userGoals'] as List<dynamic>?)?.map((g) => g.toString()).toSet() ?? {},
            medicalConditions: (pc['medicalConditions'] as List<dynamic>?)?.map((c) => c.toString()).toSet() ?? {},
            preferences: UserPreferences(
              wantsCycleTracking: pc['preferences']?['wantsCycleTracking'] ?? true,
              wantsVoiceFeatures: pc['preferences']?['wantsVoiceFeatures'] ?? true,
              wantsPersonalizedRecommendations: pc['preferences']?['wantsPersonalizedRecommendations'] ?? true,
              wantsSiaMemory: pc['preferences']?['wantsSiaMemory'] ?? true,
              wantsNotifications: pc['preferences']?['wantsNotifications'] ?? true,
            ),
            cycleLength: pc['cycleLength'],
            cycleDay: null, // Will be recalculated below
            cyclePhase: null, // Will be recalculated below
            lastPeriodStart: pc['lastPeriodStart'] != null ? DateTime.parse(pc['lastPeriodStart']) : null,
            medications: meds,
          );

          // Always recalculate cycleDay/cyclePhase from lastPeriodStart
          // so the value is fresh (not stale from yesterday's save)
          final restoredLastPeriod = _personalContext.lastPeriodStart;
          if (restoredLastPeriod != null) {
            final calc = CycleCalculation.compute(
              lastPeriodStart: restoredLastPeriod,
              cycleLength: _personalContext.cycleLength,
            );
            _personalContext = PersonalContext(
              userName: _personalContext.userName,
              dateOfBirth: _personalContext.dateOfBirth,
              weight: _personalContext.weight,
              lifeStage: _personalContext.lifeStage,
              activeLifeStages: _personalContext.activeLifeStages,
              trackingPreference: _personalContext.trackingPreference,
              cyclePattern: _personalContext.cyclePattern,
              confidence: _personalContext.confidence,
              lifeContexts: _personalContext.lifeContexts,
              userGoals: _personalContext.userGoals,
              medicalConditions: _personalContext.medicalConditions,
              preferences: _personalContext.preferences,
              cycleLength: calc.cycleLength,
              cycleDay: calc.currentCycleDay,
              cyclePhase: calc.currentPhase,
              lastPeriodStart: restoredLastPeriod,
              medications: _personalContext.medications,
            );
          }
        }

        if (data['wellbeingState'] != null) {
          final wb = data['wellbeingState'];
          _wellbeingState = CurrentWellbeingState(
            energy: wb['energy'],
            mood: wb['mood'],
            sleepQuality: wb['sleepQuality'],
            symptoms: (wb['symptoms'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? const [],
            lastCheckIn: wb['lastCheckIn'] != null ? DateTime.parse(wb['lastCheckIn']) : null,
            lastSiaConversation: wb['lastSiaConversation'] != null ? DateTime.parse(wb['lastSiaConversation']) : null,
            periodActive: wb['periodActive'] ?? false,
          );
        }

        if (!_isAuthenticated) {
          _hasChosenExperience = false;
        }

        notifyListeners();
      }
    } catch (_) {}

    if (_isAuthenticated) {
      syncStateWithBackend();
    }
  }

  Future<void> syncStateWithBackend() async {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) return;

    try {
      final data = await ApiAuthService().fetchUserData();
      if (data.isNotEmpty) {
        final profile = data['profile'] as Map<String, dynamic>?;
        final onboarding = data['onboarding'] as Map<String, dynamic>?;

        String? userName = _personalContext.userName;
        DateTime? dateOfBirth = _personalContext.dateOfBirth;
        DateTime? lastPeriodStart = _personalContext.lastPeriodStart;
        int cycleLength = _personalContext.cycleLength ?? 28;

        if (profile != null) {
          if (profile['displayName'] != null && (profile['displayName'] as String).isNotEmpty) {
            final disp = profile['displayName'] as String;
            if (disp != 'Blushy User' || userName == null || userName.isEmpty) {
              userName = disp;
            }
          }
          final rawProfilePeriod = profile['cycleStartDate'] ?? profile['cycle_start_date'] ?? profile['lastPeriodStart'] ?? profile['last_period_date'] ?? profile['last_period'];
          if (rawProfilePeriod != null) {
            final parsed = parseFlexibleDate(rawProfilePeriod);
            if (parsed != null) lastPeriodStart = parsed;
          }
          if (profile['onboardingCompleted'] == true) {
            _onboardingCompleted = true;
          }
        }

        String? lifeStage = _personalContext.lifeStage;
        DateTime? dueDate = _personalContext.dueDate;
        DateTime? babyBirthDate = _personalContext.babyBirthDate;
        Set<String> userSymptoms = Set.from(_personalContext.userSymptoms);
        Set<String> userGoals = Set.from(_personalContext.userGoals);
        Set<String> medicalConditions = Set.from(_personalContext.medicalConditions);
        Set<LifeContext> lifeContexts = Set.from(_personalContext.lifeContexts);

        if (onboarding != null && onboarding['onboardingAnswers'] is Map) {
          final answers = onboarding['onboardingAnswers'] as Map<String, dynamic>;
          if (answers.isNotEmpty && answers.length >= 2) {
            _onboardingCompleted = true;
          } else if (profile?['onboardingCompleted'] != true) {
            _onboardingCompleted = false;
          }

          if (answers['life_stage'] != null && answers['life_stage'].toString().isNotEmpty) {
            lifeStage = answers['life_stage'].toString();
          }
          if (answers['due_date'] != null) {
            final parsed = parseFlexibleDate(answers['due_date']);
            if (parsed != null) dueDate = parsed;
          }
          if (answers['baby_birth_date'] != null) {
            final parsed = parseFlexibleDate(answers['baby_birth_date']);
            if (parsed != null) babyBirthDate = parsed;
          }

          if (answers['symptoms'] != null) {
            final sVal = answers['symptoms'];
            if (sVal is List) {
              userSymptoms.addAll(sVal.map((e) => e.toString()));
            } else if (sVal is String) {
              try {
                final List decoded = jsonDecode(sVal);
                userSymptoms.addAll(decoded.map((e) => e.toString()));
              } catch (_) {}
            }
          }

          if (answers['goals'] != null) {
            final gVal = answers['goals'];
            if (gVal is List) {
              userGoals.addAll(gVal.map((e) => e.toString()));
            } else if (gVal is String) {
              try {
                final List decoded = jsonDecode(gVal);
                userGoals.addAll(decoded.map((e) => e.toString()));
              } catch (_) {}
            }
          }

          if (answers['conditions'] != null || answers['medical_conditions'] != null) {
            final cVal = answers['conditions'] ?? answers['medical_conditions'];
            if (cVal is List) {
              medicalConditions.addAll(cVal.map((e) => e.toString()));
            } else if (cVal is String) {
              try {
                final List decoded = jsonDecode(cVal);
                medicalConditions.addAll(decoded.map((e) => e.toString()));
              } catch (_) {}
            }
          }

          if (lifeStage == 'pregnancy') lifeContexts.add(LifeContext.pregnancy);
          if (lifeStage == 'postpartum') lifeContexts.add(LifeContext.postpartum);
          if (lifeStage == 'perimenopause') lifeContexts.add(LifeContext.perimenopause);
          if (lifeStage == 'menopause') lifeContexts.add(LifeContext.menopause);

          if (answers['preferred_name'] != null && (answers['preferred_name'] as String).isNotEmpty) {
            final pref = answers['preferred_name'] as String;
            if (pref != 'Blushy User' || userName == null || userName.isEmpty) {
              userName = pref;
            }
          }
          if (answers['date_of_birth'] != null) {
            final str = answers['date_of_birth'].toString();
            if (str != '2000-01-01' || dateOfBirth == null) {
              final parsed = parseFlexibleDate(str);
              if (parsed != null) dateOfBirth = parsed;
            }
          }

          final rawPeriod = answers['last_period_date'] ?? answers['last_period'] ?? answers['cycle_start_date'] ?? answers['cycle_last_period_start'] ?? answers['last_period_start'] ?? answers['period_start'];
          if (rawPeriod != null) {
            final parsed = parseFlexibleDate(rawPeriod);
            if (parsed != null) lastPeriodStart = parsed;
          }

          final rawLength = answers['cycle_length'] ?? answers['cycleLength'] ?? answers['period_cycle_length'] ?? answers['cycle_usual_length_days'] ?? answers['cycle_frequency_days'];
          if (rawLength != null) {
            final parsed = int.tryParse(rawLength.toString().replaceAll(RegExp(r'[^\d]'), ''));
            if (parsed != null && parsed >= 18 && parsed <= 60) {
              cycleLength = parsed;
            }
          }
        }

        double? weight = _personalContext.weight;
        final rawWeight = profile?['weight'] ?? onboarding?['onboardingAnswers']?['weight_current'] ?? onboarding?['onboardingAnswers']?['weight'];
        if (rawWeight != null) {
          final parsedW = double.tryParse(rawWeight.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
          if (parsedW != null && parsedW > 0) weight = parsedW;
        }

        Set<String> activeLifeStages = Set.from(_personalContext.activeLifeStages);
        if (onboarding != null && onboarding['onboardingAnswers'] is Map) {
          final answersMap = onboarding['onboardingAnswers'] as Map<String, dynamic>;
          if (answersMap['active_life_stages'] != null) {
            final aStages = answersMap['active_life_stages'];
            if (aStages is List) {
              activeLifeStages = aStages.map((e) => e.toString()).toSet();
            } else if (aStages is String) {
              try {
                final List decoded = jsonDecode(aStages);
                activeLifeStages = decoded.map((e) => e.toString()).toSet();
              } catch (_) {}
            }
          }
        }
        if (lifeStage != null && activeLifeStages.isEmpty) {
          activeLifeStages.add(lifeStage);
        }

        DataConfidence confidence = DataConfidence.low;
        if (lastPeriodStart != null || dueDate != null || babyBirthDate != null || (lifeStage != null && lifeStage != 'firstPeriodNotStarted')) {
          confidence = DataConfidence.medium;
          if (lastPeriodStart != null && userSymptoms.isNotEmpty) {
            confidence = DataConfidence.high;
          }
        }

        final cycleCalc = CycleCalculation.compute(
          lastPeriodStart: lastPeriodStart,
          cycleLength: cycleLength,
        );

        _personalContext = PersonalContext(
          userName: userName ?? _personalContext.userName,
          dateOfBirth: dateOfBirth ?? _personalContext.dateOfBirth,
          weight: weight ?? _personalContext.weight,
          lifeStage: lifeStage,
          activeLifeStages: activeLifeStages,
          dueDate: dueDate,
          babyBirthDate: babyBirthDate,
          trackingPreference: _personalContext.trackingPreference,
          cyclePattern: _personalContext.cyclePattern,
          confidence: confidence,
          lifeContexts: lifeContexts,
          userGoals: userGoals,
          userSymptoms: userSymptoms,
          medicalConditions: medicalConditions,
          preferences: _personalContext.preferences,
          cycleLength: cycleCalc.cycleLength,
          cycleDay: lastPeriodStart != null ? cycleCalc.currentCycleDay : null,
          cyclePhase: lastPeriodStart != null ? cycleCalc.currentPhase : null,
          lastPeriodStart: lastPeriodStart,
          medications: _personalContext.medications,
        );

        // Fetch and hydrate real-time daily mood and symptoms from backend
        try {
          final moodResponse = await ApiAuthService().getMyDailyMood();
          if (moodResponse['dailyMood'] is Map) {
            final dm = moodResponse['dailyMood'] as Map<String, dynamic>;
            final moodStr = dm['mood']?.toString();
            final energyStr = dm['energyLevel']?.toString();
            final List<dynamic>? symList = dm['symptoms'] as List<dynamic>?;

            int? moodScore = dm['score'] is int ? dm['score'] as int : _wellbeingState.mood;
            if (moodStr == 'great') {
              moodScore = 9;
            } else if (moodStr == 'calm') {
              moodScore = 8;
            } else if (moodStr == 'okay') {
              moodScore = 6;
            } else if (moodStr == 'low') {
              moodScore = 3;
            } else if (moodStr == 'anxious' || moodStr == 'irritated') {
              moodScore = 4;
            }

            int? energyScore = _wellbeingState.energy;
            if (energyStr == 'high') {
              energyScore = 8;
            } else if (energyStr == 'medium') {
              energyScore = 5;
            } else if (energyStr == 'low') {
              energyScore = 3;
            }

            final List<String> currentSymptoms = symList != null
                ? symList.map((e) => e.toString()).toList()
                : List<String>.from(_wellbeingState.symptoms);

            _wellbeingState = _wellbeingState.copyWith(
              mood: moodScore,
              energy: energyScore,
              symptoms: currentSymptoms,
              lastCheckIn: dm['entryDate'] != null ? parseFlexibleDate(dm['entryDate']) : DateTime.now(),
            );
          }
        } catch (_) {}

        // Fetch and hydrate latest sleep from backend
        try {
          final sleepResponse = await ApiAuthService().getMySleep();
          if (sleepResponse['sleepLog'] is Map) {
            final sl = sleepResponse['sleepLog'] as Map<String, dynamic>;
            final durationMins = sl['durationMinutes'];
            if (durationMins is num && durationMins > 0) {
              final hours = (durationMins / 60).round().clamp(1, 12);
              _wellbeingState = _wellbeingState.copyWith(sleepQuality: hours);
            }
          }
        } catch (_) {}

        // Fetch and hydrate latest period entries & canonical predictions from backend SSOT
        try {
          final pred = await ApiPeriodService().getPredictions();
          if (pred != null && pred.hasData) {
            final parsedStart = parseFlexibleDate(pred.lastPeriodStartDate);
            if (parsedStart != null) lastPeriodStart = parsedStart;

            final predConf = (pred.confidence.toLowerCase().contains('high') || pred.confidence == 'higher_confidence')
                ? DataConfidence.high
                : (pred.confidence.toLowerCase().contains('medium') ? DataConfidence.medium : DataConfidence.low);

            _personalContext = _personalContext.copyWith(
              lastPeriodStart: lastPeriodStart,
              cycleDay: pred.currentCycleDay ?? 0,
              cyclePhase: pred.currentPhase,
              cycleLength: pred.cycleLengthDays,
              confidence: predConf,
            );
          } else {
            final entries = await ApiPeriodService().getPeriodEntries();
            if (entries.isNotEmpty) {
              final latest = entries.first.periodStartDate;
              if (lastPeriodStart == null || latest.isAfter(lastPeriodStart)) {
                lastPeriodStart = latest;
              }
            }
          }
        } catch (_) {}

        // Fetch and hydrate partner connection status from backend
        try {
          final partnerStatus = await ApiPartnerService().getPartnerStatus();
          if (partnerStatus.isNotEmpty) {
            BlushyStorage.write('partner_connection_status.json', partnerStatus);
          }
        } catch (_) {}

        _saveState();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('BlushyBackend: error syncing state: $e');
    }
  }

  static DateTime? parseFlexibleDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;

    final str = val.toString().trim();
    if (str.isEmpty) return null;

    // Date-only YYYY-MM-DD parser (Prevents UTC timezone shifts like 2026-04-03 -> 2026-04-02)
    final dateOnlyMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(str);
    if (dateOnlyMatch != null) {
      final y = int.parse(dateOnlyMatch.group(1)!);
      final m = int.parse(dateOnlyMatch.group(2)!);
      final d = int.parse(dateOnlyMatch.group(3)!);
      return DateTime(y, m, d);
    }

    final parsedIso = DateTime.tryParse(str);
    if (parsedIso != null) {
      return DateTime(parsedIso.year, parsedIso.month, parsedIso.day);
    }

    if (str.contains('/') || str.contains('.')) {
      final parts = str.split(RegExp(r'[/.]'));
      if (parts.length == 3) {
        final p0 = int.tryParse(parts[0]);
        final p1 = int.tryParse(parts[1]);
        final p2 = int.tryParse(parts[2]);
        if (p0 != null && p1 != null && p2 != null) {
          if (p0 > 1000) {
            return DateTime(p0, p1, p2);
          } else if (p2 > 1000) {
            if (p1 > 12) {
              return DateTime(p2, p0, p1);
            } else {
              return DateTime(p2, p1, p0);
            }
          }
        }
      }
    }

    final daysAgoMatch = RegExp(r'(\d+)\s*days?\s*ago', caseSensitive: false).firstMatch(str);
    if (daysAgoMatch != null) {
      final days = int.tryParse(daysAgoMatch.group(1)!);
      if (days != null) {
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
      }
    }

    return null;
  }

  Future<void> _saveState() async {
    try {
      final data = {
        'isAuthenticated': _isAuthenticated,
        'onboardingCompleted': _onboardingCompleted,
        'onboardingStep': _onboardingStep,
        'argumentModeActive': _argumentModeActive,
        'customAiBriefing': _customAiBriefing,
        'journals': _journals.map((j) => {
          'content': j.content,
          'mood': j.mood,
          'timestamp': j.timestamp.toIso8601String(),
        }).toList(),
        'personalContext': {
          'userName': _personalContext.userName,
          'dateOfBirth': _personalContext.dateOfBirth?.toIso8601String(),
          'weight': _personalContext.weight,
          'lifeStage': _personalContext.lifeStage,
          'activeLifeStages': _personalContext.activeLifeStages.toList(),
          'trackingPreference': _personalContext.trackingPreference.toString(),
          'cyclePattern': _personalContext.cyclePattern.toString(),
          'confidence': _personalContext.confidence.toString(),
          'lifeContexts': _personalContext.lifeContexts.map((l) => l.toString()).toList(),
          'userGoals': _personalContext.userGoals.toList(),
          'medicalConditions': _personalContext.medicalConditions.toList(),
          'cycleLength': _personalContext.cycleLength,
          'cycleDay': _personalContext.cycleDay,
          'cyclePhase': _personalContext.cyclePhase,
          'lastPeriodStart': _personalContext.lastPeriodStart?.toIso8601String(),
          'medications': _personalContext.medications.map((m) => m.toJson()).toList(),
          'preferences': {
            'wantsCycleTracking': _personalContext.preferences.wantsCycleTracking,
            'wantsVoiceFeatures': _personalContext.preferences.wantsVoiceFeatures,
            'wantsPersonalizedRecommendations': _personalContext.preferences.wantsPersonalizedRecommendations,
            'wantsSiaMemory': _personalContext.preferences.wantsSiaMemory,
            'wantsNotifications': _personalContext.preferences.wantsNotifications,
          }
        },
        'wellbeingState': {
          'energy': _wellbeingState.energy,
          'mood': _wellbeingState.mood,
          'sleepQuality': _wellbeingState.sleepQuality,
          'symptoms': _wellbeingState.symptoms,
          'lastCheckIn': _wellbeingState.lastCheckIn?.toIso8601String(),
          'lastSiaConversation': _wellbeingState.lastSiaConversation?.toIso8601String(),
          'periodActive': _wellbeingState.periodActive,
        }
      };
      BlushyStorage.write('blushy_prefs.json', data);
    } catch (_) {}
  }


  void setAuthenticated(bool value, {bool? onboardingCompleted}) {
    _isAuthenticated = value;
    if (onboardingCompleted != null) {
      _onboardingCompleted = onboardingCompleted;
    } else if (value && AuthStorage.isOnboardingCompleted()) {
      _onboardingCompleted = true;
    }
    _saveState();
    if (value) {
      syncStateWithBackend();
    } else {
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      PartnerWebSocketService().disconnect();
    } catch (_) {}

    try {
      await ApiAuthService().signOut();
    } catch (_) {}

    SiaDashboardService().clearUserCache();
    AuthStorage.clearSession();
    BlushyStorage.clearUserData();

    _isAuthenticated = false;
    _onboardingCompleted = false;
    _hasChosenExperience = false;
    _onboardingStep = 0;
    _argumentModeActive = false;
    _journals.clear();
    _siaMessages.clear();
    _personalContext = PersonalContext(
      userName: null,
      dateOfBirth: null,
      trackingPreference: CycleTrackingPreference.unknown,
      cyclePattern: CyclePattern.unknown,
      confidence: DataConfidence.low,
      lifeContexts: {LifeContext.none},
      userGoals: {},
      medicalConditions: {},
      preferences: UserPreferences(),
      cycleLength: null,
      cycleDay: null,
      cyclePhase: null,
      lastPeriodStart: null,
      medications: [],
    );
    _wellbeingState = CurrentWellbeingState(
      energy: null,
      mood: null,
      sleepQuality: null,
      symptoms: const [],
      lastCheckIn: null,
      periodActive: false,
    );
    _saveState();
    notifyListeners();
  }

  void setOnboardingCompleted(bool value) {
    _onboardingCompleted = value;
    final session = AuthStorage.getSession();
    final token = AuthStorage.getToken();
    if (token != null) {
      AuthStorage.saveSession(
        token: token,
        refreshToken: session['refreshToken'] as String?,
        userId: session['userId'] as String?,
        email: session['email'] as String?,
        role: session['role'] as String?,
        onboardingCompleted: value,
      );
    }
    _saveState();
    notifyListeners();
  }

  void setOnboardingStep(int step) {
    _onboardingStep = step;
    _saveState();
    notifyListeners();
  }

  // --- Orthogonal Models ---
  PersonalContext _personalContext = PersonalContext(
    userName: null,
    dateOfBirth: null,
    trackingPreference: CycleTrackingPreference.unknown,
    cyclePattern: CyclePattern.unknown,
    confidence: DataConfidence.low,
    lifeContexts: {LifeContext.none},
    userGoals: {},
    medicalConditions: {},
    preferences: UserPreferences(),
    cycleLength: null,
    cycleDay: null,
    cyclePhase: null,
    lastPeriodStart: null,
    medications: [],
  );


  CurrentWellbeingState _wellbeingState = CurrentWellbeingState(
    energy: null,
    mood: null,
    sleepQuality: null,
    symptoms: const [],
    lastCheckIn: null,
    periodActive: false,
  );

  BehavioralSignals _behavioralSignals = BehavioralSignals(
    siaConversationCount: 0,
    engagedArticles: const [],
    totalLoggedSymptoms: 0,
  );

  PersonalContext get personalContext => _personalContext;
  CurrentWellbeingState get wellbeingState => _wellbeingState;
  BehavioralSignals get behavioralSignals => _behavioralSignals;

  void updatePersonalContext(PersonalContext newContext) {
    if (newContext.lastPeriodStart != null) {
      final calc = CycleCalculation.compute(
        lastPeriodStart: newContext.lastPeriodStart,
        cycleLength: newContext.cycleLength,
      );
      _personalContext = PersonalContext(
        userName: newContext.userName,
        dateOfBirth: newContext.dateOfBirth,
        weight: newContext.weight ?? _personalContext.weight,
        lifeStage: newContext.lifeStage ?? _personalContext.lifeStage,
        activeLifeStages: newContext.activeLifeStages.isNotEmpty ? newContext.activeLifeStages : _personalContext.activeLifeStages,
        dueDate: newContext.dueDate ?? _personalContext.dueDate,
        babyBirthDate: newContext.babyBirthDate ?? _personalContext.babyBirthDate,
        trackingPreference: newContext.trackingPreference,
        cyclePattern: newContext.cyclePattern,
        confidence: newContext.confidence,
        lifeContexts: newContext.lifeContexts,
        userGoals: newContext.userGoals,
        medicalConditions: newContext.medicalConditions,
        preferences: newContext.preferences,
        cycleLength: calc.cycleLength,
        cycleDay: calc.currentCycleDay,
        cyclePhase: calc.currentPhase,
        lastPeriodStart: newContext.lastPeriodStart,
        medications: newContext.medications,
      );
    } else {
      _personalContext = newContext;
    }
    _saveState();
    notifyListeners();

    if (_isAuthenticated) {
      final Map<String, dynamic> payload = {
        if (newContext.userName != null && newContext.userName!.isNotEmpty)
          'preferred_name': newContext.userName,
        if (newContext.dateOfBirth != null)
          'date_of_birth': newContext.dateOfBirth!.toIso8601String().split('T').first,
        'life_stage': _personalContext.lifeStage ?? 'reproductiveYears',
        'active_life_stages': _personalContext.activeLifeStages.toList(),
        'tracking_preference': newContext.trackingPreference.name,
        'cycle_pattern': newContext.cyclePattern.name,
        if (newContext.cycleLength != null)
          'cycle_length': newContext.cycleLength.toString(),
        if (newContext.lastPeriodStart != null)
          'last_period': newContext.lastPeriodStart!.toIso8601String().split('T').first,
        if (newContext.lastPeriodStart != null)
          'cycle_start_date': newContext.lastPeriodStart!.toIso8601String().split('T').first,
        if (newContext.lastPeriodStart != null)
          'last_period_date': newContext.lastPeriodStart!.toIso8601String().split('T').first,
        'life_contexts': newContext.lifeContexts.map((e) => e.name).toList(),
        'medical_conditions': newContext.medicalConditions.toList(),
        'medications': newContext.medications.map((m) => m.toJson()).toList(),
      };
      _syncProfileToBackend(payload);
    }
  }

  Timer? _profileSyncTimer;
  String? _lastSyncedProfileJson;

  /// Pushes the profile to the backend, coalescing bursts.
  ///
  /// One user action can touch the context from several widgets, and each call
  /// used to fire its own PUT -- the same body went up three or four times in a
  /// row. Identical consecutive payloads are dropped, and the rest are
  /// debounced so a burst becomes one request.
  void _syncProfileToBackend(Map<String, dynamic> payload) {
    final encoded = jsonEncode(payload);
    if (encoded == _lastSyncedProfileJson) return;
    _lastSyncedProfileJson = encoded;

    _profileSyncTimer?.cancel();
    _profileSyncTimer = Timer(const Duration(milliseconds: 400), () {
      ApiAuthService().saveOnboardingAnswers(payload).catchError((error) {
        // Let an identical retry through: this body never reached the server.
        _lastSyncedProfileJson = null;
        return <String, dynamic>{};
      });
    });
  }

  @override
  void dispose() {
    _profileSyncTimer?.cancel();
    super.dispose();
  }

  void setActiveLifeStages(Set<String> stages) {
    final currentStages = Set<String>.from(stages);
    if (currentStages.isEmpty) {
      currentStages.add(_personalContext.lifeStage ?? 'reproductiveYears');
    }

    try {
      final currentData = BlushyStorage.read('user_profile.json');
      final profile = Map<String, dynamic>.from(currentData['profile'] ?? {});
      profile['activeLifeStages'] = currentStages.toList();
      profile['lifeStage'] = currentStages.first;
      currentData['profile'] = profile;
      BlushyStorage.write('user_profile.json', currentData);
    } catch (_) {}

    _personalContext = PersonalContext(
      userName: _personalContext.userName,
      dateOfBirth: _personalContext.dateOfBirth,
      weight: _personalContext.weight,
      lifeStage: currentStages.first,
      activeLifeStages: currentStages,
      dueDate: _personalContext.dueDate,
      babyBirthDate: _personalContext.babyBirthDate,
      trackingPreference: _personalContext.trackingPreference,
      cyclePattern: _personalContext.cyclePattern,
      confidence: _personalContext.confidence,
      lifeContexts: _personalContext.lifeContexts,
      userGoals: _personalContext.userGoals,
      userSymptoms: _personalContext.userSymptoms,
      medicalConditions: _personalContext.medicalConditions,
      preferences: _personalContext.preferences,
      cycleLength: _personalContext.cycleLength,
      cycleDay: _personalContext.cycleDay,
      cyclePhase: _personalContext.cyclePhase,
      lastPeriodStart: _personalContext.lastPeriodStart,
      medications: _personalContext.medications,
    );
    _saveState();
    notifyListeners();

    if (_isAuthenticated) {
      ApiAuthService().saveOnboardingAnswers({
        'active_life_stages': currentStages.toList(),
        'life_stage': currentStages.first,
      }).catchError((_) => <String, dynamic>{});
    }
  }

  void addLifeStageWithAnswers(String stage, Map<String, dynamic> stageAnswers) {
    final currentStages = Set<String>.from(_personalContext.activeLifeStages);
    currentStages.add(stage);

    try {
      final currentData = BlushyStorage.read('user_profile.json');
      final profile = (currentData['profile'] is Map)
          ? Map<String, dynamic>.from(currentData['profile'])
          : Map<String, dynamic>.from(currentData);
      profile['activeLifeStages'] = currentStages.toList();
      profile['lifeStage'] = stage;

      final Map<String, dynamic> stageAnswersMap = (profile['stage_answers'] is Map)
          ? Map<String, dynamic>.from(profile['stage_answers'])
          : {};
      stageAnswersMap[stage] = Map<String, dynamic>.from(stageAnswers);
      profile['stage_answers'] = stageAnswersMap;
      profile[stage] = Map<String, dynamic>.from(stageAnswers);
      profile.addAll(stageAnswers);

      currentData['profile'] = profile;
      BlushyStorage.write('user_profile.json', currentData);
    } catch (_) {}

    final Set<String> updatedGoals = Set.from(_personalContext.userGoals);
    if (stageAnswers['goals'] != null) {
      final g = stageAnswers['goals'];
      if (g is List) updatedGoals.addAll(g.map((e) => e.toString()));
    }

    final Set<String> updatedSymptoms = Set.from(_personalContext.userSymptoms);
    if (stageAnswers['symptoms'] != null) {
      final s = stageAnswers['symptoms'];
      if (s is List) updatedSymptoms.addAll(s.map((e) => e.toString()));
    }

    final Set<String> updatedConditions = Set.from(_personalContext.medicalConditions);
    if (stageAnswers['conditions'] != null) {
      final c = stageAnswers['conditions'];
      if (c is List) updatedConditions.addAll(c.map((e) => e.toString()));
    }

    DateTime? dueDate = _personalContext.dueDate;
    if (stageAnswers['due_date'] != null) {
      dueDate = parseFlexibleDate(stageAnswers['due_date']);
    }

    DateTime? babyBirthDate = _personalContext.babyBirthDate;
    if (stageAnswers['baby_birth_date'] != null) {
      babyBirthDate = parseFlexibleDate(stageAnswers['baby_birth_date']);
    }

    _personalContext = PersonalContext(
      userName: _personalContext.userName,
      dateOfBirth: _personalContext.dateOfBirth,
      weight: _personalContext.weight,
      lifeStage: stage,
      activeLifeStages: currentStages,
      dueDate: dueDate,
      babyBirthDate: babyBirthDate,
      trackingPreference: _personalContext.trackingPreference,
      cyclePattern: _personalContext.cyclePattern,
      confidence: _personalContext.confidence,
      lifeContexts: _personalContext.lifeContexts,
      userGoals: updatedGoals,
      userSymptoms: updatedSymptoms,
      medicalConditions: updatedConditions,
      preferences: _personalContext.preferences,
      cycleLength: _personalContext.cycleLength,
      cycleDay: _personalContext.cycleDay,
      cyclePhase: _personalContext.cyclePhase,
      lastPeriodStart: _personalContext.lastPeriodStart,
      medications: _personalContext.medications,
    );

    _saveState();
    notifyListeners();

    if (_isAuthenticated) {
      final Map<String, dynamic> payload = {
        'life_stage': stage,
        'active_life_stages': currentStages.toList(),
        ...stageAnswers,
      };
      ApiAuthService().saveOnboardingAnswers(payload).catchError((_) => <String, dynamic>{});
    }
  }

  void updateWellbeingState(CurrentWellbeingState newState) {
    _wellbeingState = newState;
    _saveState();
    _persistWellbeingToStorageAndBackend(newState);
    notifyListeners();
  }

  void _persistWellbeingToStorageAndBackend(CurrentWellbeingState wb) {
    try {
      final checkinData = BlushyStorage.read('daily_checkin.json');
      final Map<String, dynamic> checkinMap = Map<String, dynamic>.from(checkinData);

      String? feelingStr;
      if (wb.mood != null) {
        if (wb.mood! >= 8) {
          feelingStr = 'Happy';
        } else if (wb.mood! >= 6) {
          feelingStr = 'Okay';
        } else if (wb.mood! >= 4) {
          feelingStr = 'Calm';
        } else {
          feelingStr = 'Low';
        }
        checkinMap['feeling'] = feelingStr;
        BlushyStorage.write('logged_feeling.json', {'feeling': feelingStr});
      }

      String? energyStr;
      if (wb.energy != null) {
        if (wb.energy! >= 7) {
          energyStr = 'High';
        } else if (wb.energy! >= 4) {
          energyStr = 'Medium';
        } else {
          energyStr = 'Low';
        }
        checkinMap['energy'] = energyStr;
        BlushyStorage.write('logged_energy.json', {'energy': energyStr});
      }

      if (wb.sleepQuality != null) {
        checkinMap['sleep'] = '${wb.sleepQuality} hours';
        BlushyStorage.write('logged_sleep.json', {'sleep': '${wb.sleepQuality} hours'});
      }

      if (wb.symptoms.isNotEmpty) {
        checkinMap['symptoms'] = wb.symptoms;
        BlushyStorage.write('logged_symptoms.json', {'symptoms': wb.symptoms});
      }

      checkinMap['last_updated'] = DateTime.now().toIso8601String();
      BlushyStorage.write('daily_checkin.json', checkinMap);

      // Async backend persistence to MongoDB
      if (feelingStr != null || wb.symptoms.isNotEmpty || energyStr != null) {
        ApiAuthService().saveDailyMood(
          mood: feelingStr ?? 'okay',
          score: wb.mood ?? 5,
          energyLevel: energyStr?.toLowerCase(),
          symptoms: wb.symptoms,
        ).catchError((_) => false);
      }

      if (wb.sleepQuality != null) {
        final hours = wb.sleepQuality!;
        if (hours >= 1 && hours <= 16) {
          final durationMinutes = hours * 60;
          final qualityRating = hours >= 7 ? 'good' : (hours >= 5 ? 'fair' : 'poor');
          ApiAuthService().saveSleepLog(
            durationMinutes: durationMinutes,
            sleepQuality: qualityRating,
          ).catchError((_) => false);
        } else {
          debugPrint('BlushyState: Sleep hours $hours is outside valid range (1-16h). Skipping persistence.');
        }
      }

      final onboardingPatch = <String, dynamic>{};
      if (feelingStr != null) onboardingPatch['checkin_feeling'] = feelingStr;
      if (energyStr != null) onboardingPatch['checkin_energy'] = energyStr;
      if (wb.sleepQuality != null) onboardingPatch['checkin_sleep'] = '${wb.sleepQuality} hours';
      if (wb.symptoms.isNotEmpty) onboardingPatch['checkin_symptoms'] = wb.symptoms;

      if (onboardingPatch.isNotEmpty) {
        ApiAuthService().saveOnboardingAnswers(onboardingPatch).catchError((_) => <String, dynamic>{});
      }
    } catch (e) {
      debugPrint('BlushyState: Error persisting wellbeing: $e');
    }
  }

  void updateBehavioralSignals(BehavioralSignals newSignals) {
    _behavioralSignals = newSignals;
    notifyListeners();
  }

  String? _customAiBriefing;

  // AI Briefing Dynamic Update
  String get dynamicAiBriefingSummary {
    if (_customAiBriefing != null) return _customAiBriefing!;
    final name = _personalContext.userName ?? "there";
    if (_wellbeingState.periodActive) {
      return "$name, your period is active. Focus on rest and hydration today.";
    }
    if (_personalContext.lifeContexts.contains(LifeContext.pregnancy)) {
      return "Hello $name, taking care of your changing body is key right now. Sia is adapting to your pregnancy context.";
    }
    if (_personalContext.cyclePhase == 'Luteal Phase' && _wellbeingState.symptoms.contains('fatigue')) {
      return "$name, Sia noticed your logged fatigue matches Luteal Phase changes. Prioritizing rest and setting boundaries could help today.";
    }
    if (_wellbeingState.symptoms.isNotEmpty) {
      final symptom = _wellbeingState.symptoms.join(', ');
      return "Sia noticed you logged $symptom. Focus on gentle movement and recovery today.";
    }
    return "Hello $name, Sia is here and ready to support you. Let's look at what matters to you today.";
  }

  void updateDynamicAiBriefing(String briefing) {
    _customAiBriefing = briefing;
    _saveState();
    notifyListeners();
  }

  
  // Developer context simulation methods
  void setTrackingPreference(CycleTrackingPreference pref) {
    _personalContext = PersonalContext(
      userName: _personalContext.userName,
      trackingPreference: pref,
      cyclePattern: _personalContext.cyclePattern,
      confidence: _personalContext.confidence,
      lifeContexts: _personalContext.lifeContexts,
      userGoals: _personalContext.userGoals,
      preferences: _personalContext.preferences,
      cycleLength: _personalContext.cycleLength,
      cycleDay: _personalContext.cycleDay,
      cyclePhase: _personalContext.cyclePhase,
      lastPeriodStart: _personalContext.lastPeriodStart,
      medications: _personalContext.medications,
    );
    _saveState();
    notifyListeners();
  }

  void setCyclePattern(CyclePattern pattern) {
    _personalContext = PersonalContext(
      userName: _personalContext.userName,
      trackingPreference: _personalContext.trackingPreference,
      cyclePattern: pattern,
      confidence: _personalContext.confidence,
      lifeContexts: _personalContext.lifeContexts,
      userGoals: _personalContext.userGoals,
      preferences: _personalContext.preferences,
      cycleLength: _personalContext.cycleLength,
      cycleDay: _personalContext.cycleDay,
      cyclePhase: _personalContext.cyclePhase,
      lastPeriodStart: _personalContext.lastPeriodStart,
      medications: _personalContext.medications,
    );
    _saveState();
    notifyListeners();
  }

  void setDataConfidence(DataConfidence conf) {
    _personalContext = PersonalContext(
      userName: _personalContext.userName,
      trackingPreference: _personalContext.trackingPreference,
      cyclePattern: _personalContext.cyclePattern,
      confidence: conf,
      lifeContexts: _personalContext.lifeContexts,
      userGoals: _personalContext.userGoals,
      preferences: _personalContext.preferences,
      cycleLength: _personalContext.cycleLength,
      cycleDay: _personalContext.cycleDay,
      cyclePhase: _personalContext.cyclePhase,
      lastPeriodStart: _personalContext.lastPeriodStart,
      medications: _personalContext.medications,
    );
    _saveState();
    notifyListeners();
  }

  void toggleLifeContext(LifeContext lc) {
    final newContexts = Set<LifeContext>.from(_personalContext.lifeContexts);
    if (newContexts.contains(lc)) {
      newContexts.remove(lc);
    } else {
      newContexts.add(lc);
      if (lc != LifeContext.none) newContexts.remove(LifeContext.none);
      if (lc == LifeContext.none) {
        newContexts.clear(); 
        newContexts.add(LifeContext.none);
      }
    }
    if (newContexts.isEmpty) newContexts.add(LifeContext.none);
    
    _personalContext = PersonalContext(
      userName: _personalContext.userName,
      trackingPreference: _personalContext.trackingPreference,
      cyclePattern: _personalContext.cyclePattern,
      confidence: _personalContext.confidence,
      lifeContexts: newContexts,
      userGoals: _personalContext.userGoals,
      preferences: _personalContext.preferences,
      cycleLength: _personalContext.cycleLength,
      cycleDay: _personalContext.cycleDay,
      cyclePhase: _personalContext.cyclePhase,
      lastPeriodStart: _personalContext.lastPeriodStart,
      medications: _personalContext.medications,
    );
    _saveState();
    notifyListeners();
  }

  void toggleSymptom(String symptom) {
    final newSymptoms = List<String>.from(_wellbeingState.symptoms);
    if (newSymptoms.contains(symptom)) {
      newSymptoms.remove(symptom);
    } else {
      newSymptoms.add(symptom);
    }
    _wellbeingState = CurrentWellbeingState(
      energy: _wellbeingState.energy,
      mood: _wellbeingState.mood,
      sleepQuality: _wellbeingState.sleepQuality,
      symptoms: newSymptoms,
      lastCheckIn: _wellbeingState.lastCheckIn,
      lastSiaConversation: _wellbeingState.lastSiaConversation,
      periodActive: _wellbeingState.periodActive,
    );
    _saveState();
    notifyListeners();
  }

  void setPeriodActive(bool active) {
    _wellbeingState = CurrentWellbeingState(
      energy: _wellbeingState.energy,
      mood: _wellbeingState.mood,
      sleepQuality: _wellbeingState.sleepQuality,
      symptoms: _wellbeingState.symptoms,
      lastCheckIn: _wellbeingState.lastCheckIn,
      lastSiaConversation: _wellbeingState.lastSiaConversation,
      periodActive: active,
    );
    _saveState();
    notifyListeners();
  }

  // Legacy variables for backward compatibility if needed in UI
  String get cyclePhase => _personalContext.cyclePhase ?? 'Unknown';
  int get cycleDay => _personalContext.cycleDay ?? 0;
  
  // Active navigation view state
  int currentViewIndex = 0; // 0: Today, 1: Journey, 2: Explore, 3: Sia

  void updateWellbeing({int? energy, int? mood, int? sleepQuality, List<String>? symptoms, bool? periodActive}) {
    _wellbeingState = CurrentWellbeingState(
      energy: energy ?? _wellbeingState.energy,
      mood: mood ?? _wellbeingState.mood,
      sleepQuality: sleepQuality ?? _wellbeingState.sleepQuality,
      symptoms: symptoms ?? _wellbeingState.symptoms,
      lastCheckIn: DateTime.now(),
      lastSiaConversation: _wellbeingState.lastSiaConversation,
      periodActive: periodActive ?? _wellbeingState.periodActive,
    );
    _saveState();
    _persistWellbeingToStorageAndBackend(_wellbeingState);
    notifyListeners();
  }

  void setViewIndex(int index) {
    currentViewIndex = index;
    notifyListeners();
  }
}


class BlushyOSProvider extends InheritedNotifier<BlushyOSState> {
  const BlushyOSProvider({
    super.key,
    required BlushyOSState super.notifier,
    required super.child,
  });

  static BlushyOSState of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<BlushyOSProvider>();
    assert(provider != null, "No BlushyOSProvider found in context");
    return provider!.notifier!;
  }
}
