/// Which stage is "current", and how the server's view of it is reconciled
/// with the app's list of active stages.
///
/// Three things used to disagree about the current stage: the home showed
/// whichever active stage ranked highest, the account list marked whichever
/// was stored first, and a restart took whatever the server had. They agree
/// now: the stage she chose last, as long as it is still active.
library;

import 'stage_conflict_engine.dart';

/// The app's key for a stage, whatever the server or an older build called it.
///
/// The server names stages `cycle_tracking`, `hormonal_health`, `ttc`; the app
/// keys them `reproductiveYears`, `hormonalHealth`, `tryingToConceive`. After
/// a restart the synced stage arrived in the server's words and never matched
/// the app's list, so the list kept the old stage beside it.
String appStageKey(String raw) {
  final squashed = raw.replaceAll('_', '').replaceAll('-', '').replaceAll(' ', '').toLowerCase();
  const byName = {
    'cycletracking': 'reproductiveYears',
    'reproductiveyears': 'reproductiveYears',
    'reproductive': 'reproductiveYears',
    'livingwithmycycle': 'reproductiveYears',
    'cycle': 'reproductiveYears',
    'hormonalhealth': 'hormonalHealth',
    'pcos': 'hormonalHealth',
    'ttc': 'tryingToConceive',
    'tryingtoconceive': 'tryingToConceive',
    'fertility': 'tryingToConceive',
    'firstperiod': 'firstPeriodStarted',
    'firstperiodstarted': 'firstPeriodStarted',
    'started': 'firstPeriodStarted',
    'firstperiodnotstarted': 'firstPeriodNotStarted',
    'notstarted': 'firstPeriodNotStarted',
    'puberty': 'firstPeriodNotStarted',
    'pregnancy': 'pregnancy',
    'pregnant': 'pregnancy',
    'postpartum': 'postpartum',
    'postnatal': 'postpartum',
    'perimenopause': 'perimenopause',
    'menopause': 'menopause',
    'postmenopause': 'menopause',
    'everydaywellness': 'everydayWellness',
    'wellness': 'everydayWellness',
    'exploring': 'everydayWellness',
    'justexploring': 'everydayWellness',
  };
  return byName[squashed] ?? raw;
}

bool _same(String a, String b) => appStageKey(a) == appStageKey(b);

/// The stage the home shows and the account list marks.
///
/// [lastChosen] wins while it is still active. Everyday Wellness is the one
/// exception: it adds to a stage rather than replacing it, so choosing it
/// beside a cycle stage keeps the cycle home. With nothing chosen, or a
/// choice no longer active, the ranking in [StageConflictEngine] decides.
String? currentStageOf(Iterable<String> active, String? lastChosen) {
  final stages = active.where((s) => s.trim().isNotEmpty).toList();
  if (stages.isEmpty) return lastChosen;
  if (lastChosen != null && lastChosen.trim().isNotEmpty) {
    final match = stages.where((s) => _same(s, lastChosen)).toList();
    if (match.isNotEmpty) {
      final isWellness = appStageKey(lastChosen) == 'everydayWellness';
      if (!isWellness || stages.length == 1) return match.first;
    }
  }
  return StageConflictEngine.dominantStage(stages);
}

/// The active list brought into line with the stage the server holds.
///
/// If [serverLifeStage] is already active, the list is returned as it is.
/// Otherwise the stage is added as the latest choice and any active stage it
/// cannot sit beside is removed, so a restart lands on the same page the
/// change did rather than on the stage it replaced.
Set<String> reconcileActiveStages(Iterable<String> active, String? serverLifeStage) {
  final stages = <String>[];
  for (final s in active) {
    if (s.trim().isNotEmpty && !stages.any((x) => _same(x, s))) stages.add(s);
  }
  if (serverLifeStage == null || serverLifeStage.trim().isEmpty) return stages.toSet();
  final key = appStageKey(serverLifeStage);
  if (stages.any((s) => _same(s, key))) return stages.toSet();

  final conflict = StageConflictEngine.checkConflict(
    currentActiveStages: stages.map(appStageKey).toSet(),
    targetStage: key,
  );
  final kept = stages.where((s) => !conflict.conflictingActiveStages.contains(appStageKey(s))).toList();
  return {...kept, key};
}
