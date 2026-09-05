import 'package:flutter/material.dart';

class StageConflictRule {
  final List<String> incompatibleWith;
  final String clinicalDefinition;
  final String userFacingMessage;
  final String reason;

  const StageConflictRule({
    required this.incompatibleWith,
    required this.clinicalDefinition,
    required this.userFacingMessage,
    required this.reason,
  });
}

const Map<String, StageConflictRule> kStageConflictRules = {
  'firstPeriodNotStarted': StageConflictRule(
    clinicalDefinition: "Individual has not yet experienced menarche (first menstrual cycle).",
    incompatibleWith: [
      'firstPeriodStarted',
      'reproductiveYears',
      'tryingToConceive',
      'pregnancy',
      'postpartum',
      'perimenopause',
      'menopause',
    ],
    userFacingMessage: "This track is designed for preparing for your first period before it starts. Activating an active cycle or maternity track will transition your profile.",
    reason: "Pre-menarche (before first period) cannot run alongside active cycle, fertility, maternity, or menopause tracks.",
  ),

  'firstPeriodStarted': StageConflictRule(
    clinicalDefinition: "Early post-menarche phase focusing on adolescent cycle regularity and body confidence.",
    incompatibleWith: [
      'firstPeriodNotStarted',
      'pregnancy',
      'postpartum',
      'perimenopause',
      'menopause',
      'reproductiveYears',
      'hormonalHealth',
      'tryingToConceive',
    ],
    userFacingMessage: "First Period (Started) focuses on early teenage puberty cycles. Activating maternity or menopause tracks will transition your profile.",
    reason: "First Period (Started) focuses on early teenage puberty cycles.",
  ),

  'reproductiveYears': StageConflictRule(
    clinicalDefinition: "Active reproductive menstrual ovulatory cycles.",
    incompatibleWith: [
      'firstPeriodNotStarted',
      'menopause',
      'pregnancy',
      'postpartum',
      'firstPeriodStarted',
    ],
    userFacingMessage: "Living with My Cycle tracks active ovulatory phases. Activating pre-menarche or post-menopause tracks will transition your profile.",
    reason: "Reproductive cycle tracking requires active menstrual cycles.",
  ),

  'tryingToConceive': StageConflictRule(
    clinicalDefinition: "Active conception planning, ovulation timing, LH tests & BBT tracking.",
    incompatibleWith: [
      'firstPeriodNotStarted',
      'pregnancy',
      'postpartum',
      'menopause',
    ],
    userFacingMessage: "Trying to Conceive tracks fertile windows. Activating pregnancy or post-menopause tracks will transition your profile.",
    reason: "Active conception tracking is incompatible with ongoing pregnancy or post-menopause.",
  ),

  'pregnancy': StageConflictRule(
    clinicalDefinition: "Active intrauterine gestation (Trimesters 1, 2, or 3).",
    incompatibleWith: [
      'firstPeriodNotStarted',
      'tryingToConceive',
      'menopause',
      'postpartum',
      'firstPeriodStarted',
      'reproductiveYears',
      'hormonalHealth',
      'perimenopause',
    ],
    userFacingMessage: "Congratulations on your pregnancy! Activating the Pregnancy track will complete your Trying to Conceive tracking and pause standard cycle predictions.",
    reason: "Active pregnancy pauses cycle tracking and conception timelines.",
  ),

  'postpartum': StageConflictRule(
    clinicalDefinition: "Period following childbirth (0–12 months postpartum) focusing on maternal recovery, lactation, and lochia/bleeding recovery.",
    incompatibleWith: [
      'firstPeriodNotStarted',
      'pregnancy',
      'menopause',
      'firstPeriodStarted',
      'reproductiveYears',
      'hormonalHealth',
      'perimenopause',
    ],
    userFacingMessage: "Postpartum begins following delivery, replacing active pregnancy tracking with fourth-trimester recovery and newborn feeding care.",
    reason: "Postpartum begins after delivery, replacing active pregnancy tracking.",
  ),

  'perimenopause': StageConflictRule(
    clinicalDefinition: "Menopausal transition phase marked by fluctuating cycle lengths and vasomotor shifts.",
    incompatibleWith: [
      'firstPeriodNotStarted',
      'firstPeriodStarted',
      'menopause',
      'pregnancy',
      'postpartum',
    ],
    userFacingMessage: "Perimenopause tracks transitional cycle rhythm shifts. It cannot co-exist with pre-puberty or complete post-menopause tracks.",
    reason: "Perimenopause represents the active transition phase prior to complete menopause.",
  ),

  'menopause': StageConflictRule(
    clinicalDefinition: "12 consecutive months of amenorrhea not attributed to other pathological or physiological causes.",
    incompatibleWith: [
      'firstPeriodNotStarted',
      'firstPeriodStarted',
      'reproductiveYears',
      'tryingToConceive',
      'pregnancy',
      'postpartum',
    ],
    userFacingMessage: "Menopause marks the transition past reproductive cycles. Standard cycle predictions and fertility tools are paused in favor of healthy ageing and bone wellness.",
    reason: "Menopause marks the post-reproductive phase.",
  ),
};

class StageConflictResult {
  final bool hasConflict;
  final String targetStage;
  final List<String> conflictingActiveStages;
  final String title;
  final String clinicalDefinition;
  final String userFacingMessage;
  final String reason;

  const StageConflictResult({
    required this.hasConflict,
    required this.targetStage,
    this.conflictingActiveStages = const [],
    this.title = '',
    this.clinicalDefinition = '',
    this.userFacingMessage = '',
    this.reason = '',
  });
}

class StageConflictEngine {
  /// The stages in the order that decides what the home tracks when more
  /// than one is active. Pregnancy outranks everything: nothing about a
  /// cycle applies while it runs. Then the stages with no cycle, then the
  /// ones that track one, most specific first. Everyday wellness is last:
  /// it adds to a stage and never replaces one.
  static const List<String> stagePriority = [
    'pregnancy',
    'postpartum',
    'menopause',
    'perimenopause',
    'tryingToConceive',
    'hormonalHealth',
    'reproductiveYears',
    'firstPeriodStarted',
    'firstPeriodNotStarted',
    'everydayWellness',
  ];

  /// The stage that decides the home and the symptom groups.
  ///
  /// With several stages active this used to be whichever came first in the
  /// set -- insertion order, in practice the oldest choice -- so a woman who
  /// added pregnancy kept a cycle home. Keys are matched loosely, the way
  /// the dashboard matches them, so `trying_to_conceive` finds its place.
  static String? dominantStage(Iterable<String> stages) {
    String squash(String k) => k.replaceAll('_', '').replaceAll(' ', '').toLowerCase();
    final active = stages.where((s) => s.trim().isNotEmpty).toList();
    if (active.isEmpty) return null;
    for (final ranked in stagePriority) {
      for (final s in active) {
        if (squash(s) == squash(ranked)) return s;
      }
    }
    return active.first;
  }

  static String getStageTitle(String key) {
    switch (key) {
      case 'firstPeriodNotStarted':
        return 'First Period (Not Started)';
      case 'firstPeriodStarted':
        return 'First Period (Started)';
      case 'reproductiveYears':
        return 'Living With My Cycle';
      case 'hormonalHealth':
        return 'Hormonal Health';
      case 'tryingToConceive':
        return 'Trying to Conceive';
      case 'pregnancy':
        return 'Pregnancy';
      case 'postpartum':
        return 'Postpartum';
      case 'perimenopause':
        return 'Perimenopause';
      case 'menopause':
        return 'Menopause';
      default:
        return 'Everyday Wellness';
    }
  }

  static IconData getStageIcon(String key) {
    switch (key) {
      case 'firstPeriodNotStarted':
        return Icons.spa_outlined;
      case 'firstPeriodStarted':
        return Icons.water_drop_outlined;
      case 'reproductiveYears':
        return Icons.favorite_border_rounded;
      case 'hormonalHealth':
        return Icons.healing_outlined;
      case 'tryingToConceive':
        return Icons.egg_outlined;
      case 'pregnancy':
        return Icons.child_care_rounded;
      case 'postpartum':
        return Icons.family_restroom_rounded;
      case 'perimenopause':
        return Icons.nightlight_round;
      case 'menopause':
        return Icons.wb_sunny_outlined;
      default:
        return Icons.eco_outlined;
    }
  }

  /// Checks if adding [targetStage] conflicts with any of [currentActiveStages].
  static StageConflictResult checkConflict({
    required Set<String> currentActiveStages,
    required String targetStage,
  }) {
    // If target stage has no rules (e.g. Hormonal Health or Everyday Wellness), it combines freely
    final targetRule = kStageConflictRules[targetStage];

    final List<String> conflicting = [];
    String clinicalDef = targetRule?.clinicalDefinition ?? '';
    String userMsg = targetRule?.userFacingMessage ?? '';
    String reason = targetRule?.reason ?? '';

    // 1. Check if target stage is incompatible with any active stage
    if (targetRule != null) {
      for (final active in currentActiveStages) {
        if (targetRule.incompatibleWith.contains(active)) {
          conflicting.add(active);
        }
      }
    }

    // 2. Also check if any active stage's rule prohibits target stage
    for (final active in currentActiveStages) {
      final activeRule = kStageConflictRules[active];
      if (activeRule != null && activeRule.incompatibleWith.contains(targetStage)) {
        if (!conflicting.contains(active)) {
          conflicting.add(active);
        }
        if (clinicalDef.isEmpty) clinicalDef = activeRule.clinicalDefinition;
        if (userMsg.isEmpty) userMsg = activeRule.userFacingMessage;
        if (reason.isEmpty) reason = activeRule.reason;
      }
    }

    if (conflicting.isNotEmpty) {
      return StageConflictResult(
        hasConflict: true,
        targetStage: targetStage,
        conflictingActiveStages: conflicting,
        title: "Transition to ${getStageTitle(targetStage)}?",
        clinicalDefinition: clinicalDef,
        userFacingMessage: userMsg.isNotEmpty
            ? userMsg
            : "Activating ${getStageTitle(targetStage)} will replace ${conflicting.map(getStageTitle).join(', ')} to keep your health tracking accurate.",
        reason: reason,
      );
    }

    return StageConflictResult(
      hasConflict: false,
      targetStage: targetStage,
    );
  }
}
