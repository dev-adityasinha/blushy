/// One vocabulary for her life stage on the partner side.
///
/// There were two, and nothing translated between them. The server normalises
/// every stage onto snake_case keys -- `first_period`, `cycle_tracking`,
/// `hormonal_health`, `ttc`, `pregnancy`, `postpartum`, `perimenopause`,
/// `menopause` -- while `StageConfig` on the client switches on camelCase ones
/// (`firstPeriodStarted`, `livingWithMyCycle`, `tryingToConceive`). A stage
/// that arrived from the server therefore matched no case at all and fell
/// through to the default, silently, on every account.
///
/// This accepts either spelling, plus both legacy alias sets, mirroring
/// `normalizeLifeStage` in `backend/src/domain/lifeStages.js`. When the two
/// sides disagree again, they disagree here, in one place, with a test on it.
library;

enum PartnerStage {
  firstPeriod,
  cycleTracking,
  hormonalHealth,
  ttc,
  pregnancy,
  postpartum,
  perimenopause,
  menopause,
  everydayWellness,

  /// She has not chosen a stage, or has not shared her onboarding. Both look
  /// the same from here on purpose: which of the two it is belongs to her.
  unknown;

  /// The canonical server key, as stored and as sent.
  String get serverKey => switch (this) {
        PartnerStage.firstPeriod => 'first_period',
        PartnerStage.cycleTracking => 'cycle_tracking',
        PartnerStage.hormonalHealth => 'hormonal_health',
        PartnerStage.ttc => 'ttc',
        PartnerStage.pregnancy => 'pregnancy',
        PartnerStage.postpartum => 'postpartum',
        PartnerStage.perimenopause => 'perimenopause',
        PartnerStage.menopause => 'menopause',
        PartnerStage.everydayWellness => 'everyday_wellness',
        PartnerStage.unknown => '',
      };

  /// The key `StageConfig.forStage` switches on, so the existing stage config
  /// keeps resolving whichever spelling arrived.
  String get configKey => switch (this) {
        PartnerStage.firstPeriod => 'firstPeriodStarted',
        PartnerStage.cycleTracking => 'livingWithMyCycle',
        PartnerStage.hormonalHealth => 'hormonalHealth',
        PartnerStage.ttc => 'tryingToConceive',
        PartnerStage.pregnancy => 'pregnancy',
        PartnerStage.postpartum => 'postpartum',
        PartnerStage.perimenopause => 'perimenopause',
        PartnerStage.menopause => 'menopause',
        PartnerStage.everydayWellness => 'livingWithMyCycle',
        PartnerStage.unknown => 'livingWithMyCycle',
      };

  bool get isKnown => this != PartnerStage.unknown;

  static const Map<String, PartnerStage> _canonical = {
    'first_period': PartnerStage.firstPeriod,
    'cycle_tracking': PartnerStage.cycleTracking,
    'hormonal_health': PartnerStage.hormonalHealth,
    'ttc': PartnerStage.ttc,
    'pregnancy': PartnerStage.pregnancy,
    'postpartum': PartnerStage.postpartum,
    'perimenopause': PartnerStage.perimenopause,
    'menopause': PartnerStage.menopause,
    'everyday_wellness': PartnerStage.everydayWellness,
    // A real chosen stage meaning "just looking around". For partner-facing
    // content it reads the same as everyday wellness; it is not "unknown",
    // which means she has told us nothing.
    'exploring': PartnerStage.everydayWellness,
  };

  /// Every older spelling, with separators removed. Kept in step with
  /// `LEGACY_STAGE_ALIASES` on the server.
  static const Map<String, PartnerStage> _aliases = {
    'firstperiodnotstarted': PartnerStage.firstPeriod,
    'firstperiodstarted': PartnerStage.firstPeriod,
    'firstperiod': PartnerStage.firstPeriod,
    'livingwithmycycle': PartnerStage.cycleTracking,
    'cycle': PartnerStage.cycleTracking,
    'cycletracking': PartnerStage.cycleTracking,
    'reproductive': PartnerStage.cycleTracking,
    'reproductiveyears': PartnerStage.cycleTracking,
    'hormonalhealth': PartnerStage.hormonalHealth,
    'pcos': PartnerStage.hormonalHealth,
    'pmdd': PartnerStage.hormonalHealth,
    'endometriosis': PartnerStage.hormonalHealth,
    'tryingtoconceive': PartnerStage.ttc,
    'fertility': PartnerStage.ttc,
    'pregnant': PartnerStage.pregnancy,
    'postnatal': PartnerStage.postpartum,
    'newmotherhood': PartnerStage.postpartum,
    'perimenopausal': PartnerStage.perimenopause,
    'midlife': PartnerStage.perimenopause,
    'menopausal': PartnerStage.menopause,
    'postmenopause': PartnerStage.menopause,
    'everydaywellness': PartnerStage.everydayWellness,
    'wellness': PartnerStage.everydayWellness,
    'justexploring': PartnerStage.everydayWellness,
    'explore': PartnerStage.everydayWellness,
  };

  /// Resolves whatever arrived. Anything unrecognised is [unknown] rather than
  /// a default stage: guessing a stage is a claim about her body.
  static PartnerStage from(Object? raw) {
    if (raw is! String) return PartnerStage.unknown;
    final lower = raw.trim().toLowerCase();
    if (lower.isEmpty) return PartnerStage.unknown;

    final collapsed = lower.replaceAll(RegExp(r'[\s-]+'), '_');
    final direct = _canonical[collapsed];
    if (direct != null) return direct;

    final squashed = lower.replaceAll(RegExp(r'[\s_-]+'), '');
    return _aliases[squashed] ?? PartnerStage.unknown;
  }

  /// Her stage from the partner payloads, in the order they can be trusted.
  ///
  /// `permittedContext.lifeStage` is the permission-filtered value from the
  /// partner-safe endpoint; `lifeStage` is the same stage on the older
  /// shared-data payload, behind her `shareOnboarding` switch. Neither is ever
  /// read off `partnerUser`, which does not carry it -- that path is what made
  /// the old code fall back to "everydayWellness" for everybody.
  static PartnerStage resolve({
    Map<String, dynamic>? permittedContext,
    String? lifeStageContext,
    Map<String, dynamic>? sharedData,
  }) {
    for (final candidate in [
      permittedContext?['lifeStage'],
      lifeStageContext,
      sharedData?['lifeStage'],
    ]) {
      final stage = PartnerStage.from(candidate);
      if (stage.isKnown) return stage;
    }
    return PartnerStage.unknown;
  }
}
