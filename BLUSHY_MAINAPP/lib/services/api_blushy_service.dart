import '../models/blushy_models.dart';
import 'api_contract_client.dart';

/// Typed client for the spec-aligned `/api/v1` surface.
///
/// Grouped by the screen area each set of calls serves, so a widget imports one
/// service and gets everything that screen needs. Every method returns an
/// [ApiResult], which carries the card state, the data source and the
/// calculation version alongside the payload.

/* ================================================================== *
 * Life stage (spec sections 3, 4, 23)
 * ================================================================== */

class LifeStageApi {
  const LifeStageApi._();

  static Future<ApiResult<LifeStageState>> current() {
    return ApiContractClient.get('/life-stage', parse: LifeStageState.fromJson);
  }

  /// The ten life journeys, each with only the questions its branch needs.
  static Future<ApiResult<List<LifeJourney>>> journeys() {
    return ApiContractClient.get(
      '/life-stage/journeys',
      parse: (data) => ApiParse.list(data).map(LifeJourney.fromJson).toList(),
    );
  }

  static Future<ApiResult<List<BranchQuestion>>> branchQuestions(String stage) {
    return ApiContractClient.get(
      '/life-stage/journeys/$stage/questions',
      parse: (data) => ApiParse.list(ApiParse.map(data)['questions']).map(BranchQuestion.fromJson).toList(),
    );
  }

  /// Moves to another branch.
  ///
  /// Returns `errorCode: 'CONFIRMATION_REQUIRED'` for the sensitive transitions
  /// the spec says must never happen silently, and `'MISSING_BRANCH_CONTEXT'`
  /// when the target branch still needs an answer before it can render.
  static Future<ApiResult<LifeStageState>> transition({
    required String toStage,
    bool confirmed = false,
    Map<String, dynamic> context = const {},
    String? reason,
  }) {
    return ApiContractClient.post(
      '/life-stage/transition',
      body: {'toStage': toStage, 'confirmed': confirmed, 'context': context, 'reason': ?reason},
      parse: (data) => LifeStageState.fromJson(ApiParse.map(data)['stage']),
    );
  }

  static Future<ApiResult<LifeStageState>> saveContext(Map<String, dynamic> context) {
    return ApiContractClient.put('/life-stage/context', body: {'context': context}, parse: LifeStageState.fromJson);
  }

  /// Pregnancy exit or loss. Always requires explicit confirmation, and
  /// permanently stops pregnancy week content afterwards.
  static Future<ApiResult<Map<String, dynamic>>> endPregnancy({
    required String outcome,
    String? endDate,
    bool confirmed = false,
  }) {
    return ApiContractClient.post(
      '/life-stage/pregnancy/end',
      body: {'outcome': outcome, 'confirmed': confirmed, 'endDate': ?endDate},
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<List<Map<String, dynamic>>>> history() {
    return ApiContractClient.get('/life-stage/history', parse: ApiParse.list);
  }

  /// Fertility tracking stays separate from ordinary cycle tracking until the
  /// user opts in (spec section 5).
  static Future<ApiResult<LifeStageState>> setTtcOptIn(bool optedIn) {
    return ApiContractClient.put('/life-stage/ttc-opt-in', body: {'optedIn': optedIn}, parse: LifeStageState.fromJson);
  }
}

/* ================================================================== *
 * Home (spec section 5)
 * ================================================================== */

class HomeApi {
  const HomeApi._();

  static Future<ApiResult<HomeScreenModel>> load({String? timezone, String? mode}) {
    return ApiContractClient.get(
      '/home',
      query: {
        'timezone': ?timezone,
        'mode': ?mode,
      },
      parse: HomeScreenModel.fromJson,
    );
  }
}

/* ================================================================== *
 * Cycle (spec sections 5, 6)
 * ================================================================== */

class CycleApi {
  const CycleApi._();

  static Future<ApiResult<CycleState>> current({String? timezone, String? referenceDate}) {
    return ApiContractClient.get(
      '/cycle',
      query: {
        'timezone': ?timezone,
        'referenceDate': ?referenceDate,
      },
      parse: CycleState.fromJson,
    );
  }

  /// Logs or corrects a period start.
  ///
  /// The response carries the recalculated cycle state, so the Hero and every
  /// dependent card update from one round trip (spec section 28).
  /// `clientEventId` makes the write idempotent for the offline queue.
  static Future<ApiResult<CycleLogResult>> logPeriod({
    required DateTime startDate,
    DateTime? endDate,
    String? flow,
    String? clientEventId,
  }) {
    return ApiContractClient.post(
      '/cycle/periods',
      idempotencyKey: clientEventId,
      body: {
        'startDate': ApiParse.dateOnly(startDate),
        if (endDate != null) 'endDate': ApiParse.dateOnly(endDate),
        'flow': ?flow,
        'clientEventId': ?clientEventId,
      },
      parse: CycleLogResult.fromJson,
    );
  }

  static Future<ApiResult<List<Map<String, dynamic>>>> history({int limit = 50}) {
    return ApiContractClient.get('/cycle/periods', query: {'limit': '$limit'}, parse: ApiParse.list);
  }

  /// Deleting a period recalculates every card derived from it.
  static Future<ApiResult<CycleLogResult>> deletePeriod(String entryId) {
    return ApiContractClient.delete('/cycle/periods/$entryId', parse: CycleLogResult.fromJson);
  }
}

class CycleLogResult {
  final CycleState? cycle;
  final HealthEvent? event;
  final int invalidatedInsights;

  const CycleLogResult({this.cycle, this.event, this.invalidatedInsights = 0});

  factory CycleLogResult.fromJson(dynamic raw) {
    final json = ApiParse.map(raw);
    final recalculation = ApiParse.map(json['recalculation']);
    return CycleLogResult(
      cycle: json['cycle'] == null ? null : CycleState.fromJson(json['cycle']),
      event: json['event'] == null ? null : HealthEvent.fromJson(ApiParse.map(json['event'])),
      invalidatedInsights: ApiParse.intOrNull(recalculation['invalidated']) ?? 0,
    );
  }
}

/* ================================================================== *
 * Health events and timeline (spec sections 6, 7, 11, 25)
 * ================================================================== */

class EventsApi {
  const EventsApi._();

  /// Logs one check-in. The response is the canonical saved record, which the
  /// card should use to replace its optimistic state (spec section 7).
  ///
  /// When a red flag rule fires, `safety` is populated and the caller must show
  /// the safety flow instead of ordinary wellness content.
  static Future<ApiResult<EventLogResult>> log({
    required String eventType,
    required Map<String, dynamic> payload,
    DateTime? timestamp,
    String source = 'manual',
    String? clientEventId,
  }) {
    return ApiContractClient.post(
      '/events',
      idempotencyKey: clientEventId,
      body: {
        'eventType': eventType,
        'payload': payload,
        'source': source,
        if (timestamp != null) 'timestamp': timestamp.toIso8601String(),
        'clientEventId': ?clientEventId,
      },
      parse: EventLogResult.fromJson,
    );
  }

  static Future<ApiResult<List<HealthEvent>>> list({
    List<String>? eventTypes,
    DateTime? from,
    DateTime? to,
    int limit = 100,
    int skip = 0,
  }) {
    return ApiContractClient.get(
      '/events',
      query: {
        if (eventTypes != null && eventTypes.isNotEmpty) 'eventTypes': eventTypes.join(','),
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
        'limit': '$limit',
        'skip': '$skip',
      },
      parse: (data) => ApiParse.list(data).map(HealthEvent.fromJson).toList(),
    );
  }

  static Future<ApiResult<HealthEvent>> edit(String eventId, Map<String, dynamic> payload, {DateTime? timestamp}) {
    return ApiContractClient.patch(
      '/events/$eventId',
      body: {'payload': payload, if (timestamp != null) 'timestamp': timestamp.toIso8601String()},
      parse: (data) => HealthEvent.fromJson(ApiParse.map(ApiParse.map(data)['event'])),
    );
  }

  /// Deleting an event invalidates every insight built from it and cancels any
  /// reminder that pointed at it.
  static Future<ApiResult<Map<String, dynamic>>> delete(String eventId) {
    return ApiContractClient.delete('/events/$eventId', parse: ApiParse.map);
  }

  static Future<ApiResult<Timeline>> timeline({
    DateTime? from,
    DateTime? to,
    List<String>? eventTypes,
    int limit = 50,
    int skip = 0,
  }) {
    return ApiContractClient.get(
      '/events/timeline',
      query: {
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
        if (eventTypes != null && eventTypes.isNotEmpty) 'eventTypes': eventTypes.join(','),
        'limit': '$limit',
        'skip': '$skip',
      },
      parse: Timeline.fromJson,
    );
  }

  /// Flushes a queue of writes made while offline. Every item needs its own
  /// `clientEventId` so replaying the queue cannot create duplicates.
  static Future<ApiResult<Map<String, dynamic>>> sync(List<Map<String, dynamic>> events) {
    return ApiContractClient.post('/events/sync', body: {'events': events}, parse: ApiParse.map);
  }
}

class EventLogResult {
  final HealthEvent? event;
  final bool deduplicated;
  final List<String> invalidates;
  final SafetyFlow? safety;

  const EventLogResult({this.event, this.deduplicated = false, this.invalidates = const [], this.safety});

  bool get hasSafetyEscalation => safety != null && safety!.steps.isNotEmpty;

  factory EventLogResult.fromJson(dynamic raw) {
    final json = ApiParse.map(raw);
    return EventLogResult(
      event: json['event'] == null ? null : HealthEvent.fromJson(ApiParse.map(json['event'])),
      deduplicated: json['deduplicated'] == true,
      invalidates: (json['invalidates'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      safety: json['safety'] == null ? null : SafetyFlow.fromJson(json['safety']),
    );
  }
}

/* ================================================================== *
 * Patterns and care plan (spec sections 8, 10)
 * ================================================================== */

class PatternsApi {
  const PatternsApi._();

  static Future<ApiResult<List<Insight>>> load({bool refresh = false, int limit = 10}) {
    return ApiContractClient.get(
      '/patterns',
      query: {'refresh': '$refresh', 'limit': '$limit'},
      parse: (data) => ApiParse.list(data).map(Insight.fromJson).toList(),
    );
  }

  static Future<ApiResult<List<Insight>>> refresh() {
    return ApiContractClient.post(
      '/patterns/refresh',
      parse: (data) => ApiParse.list(data).map(Insight.fromJson).toList(),
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> dismiss(String insightId) {
    return ApiContractClient.post('/patterns/$insightId/dismiss', parse: ApiParse.map);
  }

  /// Helpful / not helpful. A "not helpful" answer stops that insight being
  /// served again until its evidence materially changes.
  static Future<ApiResult<Map<String, dynamic>>> feedback(String insightId, {required bool helpful, String? note}) {
    return ApiContractClient.post(
      '/patterns/$insightId/feedback',
      body: {'helpful': helpful, 'note': ?note},
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> markViewed(String insightId) {
    return ApiContractClient.post('/patterns/$insightId/view', parse: ApiParse.map);
  }
}

class CarePlanApi {
  const CarePlanApi._();

  /// Returns `state: restricted` with `suppressed: true` while a safety
  /// escalation or a concerning screening result is active.
  static Future<ApiResult<CarePlan>> load({String? mode}) {
    return ApiContractClient.get(
      '/care-plan',
      query: {'mode': ?mode},
      parse: CarePlan.fromJson,
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> complete(String actionId) {
    return ApiContractClient.post('/care-plan/$actionId/complete', parse: ApiParse.map);
  }

  static Future<ApiResult<Map<String, dynamic>>> dismiss(String actionId) {
    return ApiContractClient.post('/care-plan/$actionId/dismiss', parse: ApiParse.map);
  }
}

/* ================================================================== *
 * Branch modules (spec sections 13, 15, 16)
 * ================================================================== */

class BranchApi {
  const BranchApi._();

  static Future<ApiResult<Map<String, dynamic>>> pregnancy() {
    return ApiContractClient.get('/pregnancy', parse: ApiParse.map);
  }

  static Future<ApiResult<Map<String, dynamic>>> postpartum() {
    return ApiContractClient.get('/postpartum', parse: ApiParse.map);
  }

  /// Fertility indicators. Never returns a conception probability.
  static Future<ApiResult<Map<String, dynamic>>> fertility() {
    return ApiContractClient.get('/fertility', parse: ApiParse.map);
  }

  /// Condition profile: only what the user reported being diagnosed with,
  /// plus reviewed education and their own logged observations. Never returns
  /// estimated hormone levels (spec section 14).
  static Future<ApiResult<Map<String, dynamic>>> conditions() {
    return ApiContractClient.get('/conditions', parse: ApiParse.map);
  }

  static Future<ApiResult<Map<String, dynamic>>> saveConditions(
    List<String> conditions, {
    String diagnosedBy = 'self_reported',
  }) {
    return ApiContractClient.put(
      '/conditions',
      body: {'conditions': conditions, 'diagnosedBy': diagnosedBy},
      parse: ApiParse.map,
    );
  }
}

/* ================================================================== *
 * Reflections (spec section 12)
 * ================================================================== */

class ReflectionsApi {
  const ReflectionsApi._();

  static Future<ApiResult<Map<String, dynamic>>> current({String? periodKey}) {
    return ApiContractClient.get(
      '/reflections/current',
      query: {'periodKey': ?periodKey},
      parse: ApiParse.map,
    );
  }

  /// Responses are private by default and are never shared with a partner
  /// unless `sharedWithPartner` is set explicitly.
  static Future<ApiResult<Map<String, dynamic>>> save({
    String? periodKey,
    String? state,
    String? response,
    bool sharedWithPartner = false,
  }) {
    return ApiContractClient.put(
      '/reflections',
      body: {
        'periodKey': ?periodKey,
        'state': ?state,
        'response': ?response,
        'sharedWithPartner': sharedWithPartner,
      },
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<List<Map<String, dynamic>>>> history() {
    return ApiContractClient.get('/reflections', parse: ApiParse.list);
  }
}

/* ================================================================== *
 * Safety, screening and doctor companion (spec sections 15, 16, 18)
 * ================================================================== */

class SafetyApi {
  const SafetyApi._();

  static Future<ApiResult<SafetyFlow>> state() {
    return ApiContractClient.get('/safety/state', parse: SafetyFlow.fromJson);
  }

  /// Screens free text before it is sent, so a red flag in a message or journal
  /// entry surfaces the safety flow rather than a wellness reply.
  static Future<ApiResult<SafetyFlow>> checkText(String text, {String surface = 'text_check'}) {
    return ApiContractClient.post(
      '/safety/check-text',
      body: {'text': text, 'surface': surface},
      parse: SafetyFlow.fromJson,
    );
  }

  /// Location-aware emergency resources. Works without a session, because
  /// safety guidance cannot depend on being signed in.
  static Future<ApiResult<Map<String, dynamic>>> emergencyResources({String? region}) {
    return ApiContractClient.get(
      '/safety/emergency-resources',
      query: {'region': ?region},
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<List<Map<String, dynamic>>>> instruments() {
    return ApiContractClient.get('/safety/screening/instruments', parse: ApiParse.list);
  }

  /// Returns `itemsAvailable: false` when the licensed instrument wording has
  /// not been loaded. The questionnaire must not be shown with paraphrased
  /// wording, so the caller should render an unavailable state.
  static Future<ApiResult<Map<String, dynamic>>> instrumentItems(String instrumentId) {
    return ApiContractClient.get('/safety/screening/instruments/$instrumentId/items', parse: ApiParse.map);
  }

  static Future<ApiResult<ScreeningSubmission>> submitScreening({
    required String instrumentId,
    required List<int> responses,
    int? checkpointDay,
  }) {
    return ApiContractClient.post(
      '/safety/screening/submit',
      body: {
        'instrumentId': instrumentId,
        'responses': responses,
        'checkpointDay': ?checkpointDay,
      },
      parse: ScreeningSubmission.fromJson,
    );
  }

  static Future<ApiResult<List<ScreeningResult>>> screeningHistory({String? instrumentId}) {
    return ApiContractClient.get(
      '/safety/screening/history',
      query: {'instrumentId': ?instrumentId},
      parse: (data) => ApiParse.list(data).map(ScreeningResult.fromJson).toList(),
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> moodCheckInStatus() {
    return ApiContractClient.get('/safety/screening/mood-check-in', parse: ApiParse.map);
  }
}

class ScreeningSubmission {
  final ScreeningResult? result;
  final Map<String, dynamic>? supportFlow;

  const ScreeningSubmission({this.result, this.supportFlow});

  /// A concerning result routes to professional support resources rather than
  /// generic wellness tips (spec section 16).
  bool get requiresSupport => supportFlow != null && supportFlow!['required'] == true;

  factory ScreeningSubmission.fromJson(dynamic raw) {
    final json = ApiParse.map(raw);
    return ScreeningSubmission(
      result: json['result'] == null ? null : ScreeningResult.fromJson(ApiParse.map(json['result'])),
      supportFlow: json['supportFlow'] == null ? null : ApiParse.map(json['supportFlow']),
    );
  }
}

class DoctorCompanionApi {
  const DoctorCompanionApi._();

  /// Builds a draft summary over a date range. Nothing is stored until the
  /// user saves it, after removing anything they do not want to share.
  static Future<ApiResult<Map<String, dynamic>>> preview({
    DateTime? from,
    DateTime? to,
    bool includeInsights = true,
    bool includeScreenings = false,
  }) {
    return ApiContractClient.get(
      '/safety/doctor-summary/preview',
      query: {
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
        'includeInsights': '$includeInsights',
        'includeScreenings': '$includeScreenings',
      },
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> save({
    required String from,
    required String to,
    required List<Map<String, dynamic>> sections,
    List<String> questions = const [],
    String? title,
  }) {
    return ApiContractClient.post(
      '/safety/doctor-summary',
      body: {'from': from, 'to': to, 'sections': sections, 'questions': questions, 'title': ?title},
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<List<Map<String, dynamic>>>> list() {
    return ApiContractClient.get('/safety/doctor-summary', parse: ApiParse.list);
  }

  static Future<ApiResult<Map<String, dynamic>>> get(String summaryId) {
    return ApiContractClient.get('/safety/doctor-summary/$summaryId', parse: ApiParse.map);
  }

  static Future<ApiResult<Map<String, dynamic>>> delete(String summaryId) {
    return ApiContractClient.delete('/safety/doctor-summary/$summaryId', parse: ApiParse.map);
  }
}

/* ================================================================== *
 * Partner (spec sections 9, 10, 11, 19, 20, 21)
 * ================================================================== */

class PartnerApi {
  const PartnerApi._();

  /// The full permission matrix with labels and examples, for the Partner Mode
  /// settings screen.
  static Future<ApiResult<List<PartnerPermission>>> permissionMatrix() {
    return ApiContractClient.get(
      '/partner/permission-matrix',
      parse: (data) => ApiParse.list(data).map(PartnerPermission.fromJson).toList(),
    );
  }

  /// What is currently shared. Only the person sharing can read this.
  static Future<ApiResult<PartnerSharingState>> sharingState(String connectionId) {
    return ApiContractClient.get('/partner/connections/$connectionId/sharing', parse: PartnerSharingState.fromJson);
  }

  /// Changes propagate immediately: the partner loses access on their very next
  /// request, and the change is written to an audit trail.
  static Future<ApiResult<Map<String, dynamic>>> updatePermissions(
    String connectionId,
    Map<String, bool> permissions,
  ) {
    return ApiContractClient.patch(
      '/partner/connections/$connectionId/sharing',
      body: {'permissions': permissions},
      parse: ApiParse.map,
    );
  }

  /// A partner asks to be shown something that is currently off.
  ///
  /// Asking shares nothing. The person whose data it is stays the only one who
  /// can approve, and they are notified in app.
  static Future<ApiResult<Map<String, dynamic>>> requestPermission(
    String connectionId,
    String permissionKey, {
    String? message,
  }) {
    return ApiContractClient.post(
      '/partner/connections/$connectionId/sharing/requests',
      body: {
        'permissionKey': permissionKey,
        if (message != null && message.isNotEmpty) 'message': message,
      },
      parse: ApiParse.map,
    );
  }

  /// Requests on a connection. Both sides can read them: the owner to answer,
  /// the partner to see what they already asked for.
  static Future<ApiResult<List<Map<String, dynamic>>>> permissionRequests(
    String connectionId, {
    String? states,
  }) {
    return ApiContractClient.get(
      '/partner/connections/$connectionId/sharing/requests',
      query: states == null ? null : {'states': states},
      parse: (data) => ApiParse.list(data).map(ApiParse.map).toList(),
    );
  }

  /// The owner answers. Approving is what actually turns the permission on.
  static Future<ApiResult<Map<String, dynamic>>> respondToPermissionRequest(
    String requestId, {
    required bool approve,
  }) {
    return ApiContractClient.post(
      '/partner/sharing/requests/$requestId/respond',
      body: {'approve': approve},
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> withdrawPermissionRequest(String requestId) {
    return ApiContractClient.post(
      '/partner/sharing/requests/$requestId/withdraw',
      parse: ApiParse.map,
    );
  }

  /// The garden a couple tends together. It belongs to the connection, so both
  /// people see the same one.
  static Future<ApiResult<Map<String, dynamic>>> garden(String connectionId) {
    return ApiContractClient.get(
      '/partner/connections/$connectionId/garden',
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> growGarden(
    String connectionId, {
    int flowers = 0,
    int trees = 0,
    bool addPond = false,
  }) {
    return ApiContractClient.post(
      '/partner/connections/$connectionId/garden/grow',
      body: {'flowers': flowers, 'trees': trees, 'addPond': addPond},
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<List<Map<String, dynamic>>>> permissionHistory(String connectionId) {
    return ApiContractClient.get('/partner/connections/$connectionId/sharing/history', parse: ApiParse.list);
  }

  /// Partner Home. Works with nothing shared: the partner still gets general
  /// education and support.
  static Future<ApiResult<PartnerHomeModel>> home(String connectionId) {
    return ApiContractClient.get('/partner/connections/$connectionId/home', parse: PartnerHomeModel.fromJson);
  }

  /// The permission-filtered context. This is exactly what Partner Dr. Docsy sees.
  static Future<ApiResult<Map<String, dynamic>>> context(String connectionId) {
    return ApiContractClient.get('/partner/connections/$connectionId/context', parse: ApiParse.map);
  }

  /// The "Us" surface: only explicitly shared objects.
  static Future<ApiResult<Map<String, dynamic>>> us(String connectionId) {
    return ApiContractClient.get('/partner/connections/$connectionId/us', parse: ApiParse.map);
  }

  static Future<ApiResult<List<Map<String, dynamic>>>> supportRequestTypes() {
    return ApiContractClient.get('/partner/support-request-types', parse: ApiParse.list);
  }

  static Future<ApiResult<SupportRequest>> createSupportRequest(
    String connectionId, {
    required String type,
    String? message,
    int? expiresInHours,
  }) {
    return ApiContractClient.post(
      '/partner/connections/$connectionId/support-requests',
      body: {
        'type': type,
        'message': ?message,
        'expiresInHours': ?expiresInHours,
      },
      parse: (data) => SupportRequest.fromJson(ApiParse.map(data)),
    );
  }

  static Future<ApiResult<List<SupportRequest>>> supportRequests(String connectionId, {List<String>? states}) {
    return ApiContractClient.get(
      '/partner/connections/$connectionId/support-requests',
      query: {if (states != null && states.isNotEmpty) 'states': states.join(',')},
      parse: (data) => ApiParse.list(data).map(SupportRequest.fromJson).toList(),
    );
  }

  /// `acknowledged` and `completed` are the partner's to set; `revoked` is the
  /// requester's. The server enforces this.
  static Future<ApiResult<SupportRequest>> updateSupportRequest(String requestId, String state) {
    return ApiContractClient.patch(
      '/partner/support-requests/$requestId',
      body: {'state': state},
      parse: (data) => SupportRequest.fromJson(ApiParse.map(data)),
    );
  }
}

/* ================================================================== *
 * Content library (spec sections 13, 17, 23)
 * ================================================================== */

class ContentApi {
  const ContentApi._();

  /// Defaults to the caller's own life stage and audience, so Partner Learn
  /// automatically receives partner-tagged content.
  static Future<ApiResult<List<LibraryItem>>> browse({
    String? lifeStage,
    String? topic,
    String? audience,
    String? contentType,
    String? search,
    int limit = 20,
    int skip = 0,
  }) {
    return ApiContractClient.get(
      '/content',
      query: {
        'lifeStage': ?lifeStage,
        'topic': ?topic,
        'audience': ?audience,
        'contentType': ?contentType,
        'search': ?search,
        'limit': '$limit',
        'skip': '$skip',
      },
      parse: (data) => ApiParse.list(data).map(LibraryItem.fromJson).toList(),
    );
  }

  static Future<ApiResult<LibraryItem>> item(String contentId) {
    return ApiContractClient.get('/content/$contentId', parse: (data) => LibraryItem.fromJson(ApiParse.map(data)));
  }

  static Future<ApiResult<Map<String, dynamic>>> saveProgress(
    String contentId, {
    int? progressPercent,
    int? positionSeconds,
    bool? completed,
  }) {
    return ApiContractClient.put(
      '/content/$contentId/progress',
      body: {
        'progressPercent': ?progressPercent,
        'positionSeconds': ?positionSeconds,
        'completed': ?completed,
      },
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> setBookmark(String contentId, bool bookmarked) {
    return ApiContractClient.put(
      '/content/$contentId/bookmark',
      body: {'bookmarked': bookmarked},
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<List<LibraryItem>>> saved() {
    return ApiContractClient.get('/content/saved', parse: (data) => ApiParse.list(data).map(LibraryItem.fromJson).toList());
  }

  static Future<ApiResult<List<LibraryItem>>> recommendations() {
    return ApiContractClient.get(
      '/content/recommendations',
      parse: (data) => ApiParse.list(data).map(LibraryItem.fromJson).toList(),
    );
  }

  static Future<ApiResult<List<Map<String, dynamic>>>> completed() {
    return ApiContractClient.get('/content/completed', parse: ApiParse.list);
  }
}

/* ================================================================== *
 * Notifications and analytics (spec sections 19, 24, 26)
 * ================================================================== */

class NotificationsApi {
  const NotificationsApi._();

  static Future<ApiResult<List<Map<String, dynamic>>>> categories() {
    return ApiContractClient.get('/notifications/categories', parse: ApiParse.list);
  }

  static Future<ApiResult<NotificationPreferences>> preferences() {
    return ApiContractClient.get('/notifications/preferences', parse: NotificationPreferences.fromJson);
  }

  static Future<ApiResult<NotificationPreferences>> updatePreferences(Map<String, dynamic> patch) {
    return ApiContractClient.patch('/notifications/preferences', body: patch, parse: NotificationPreferences.fromJson);
  }

  static Future<ApiResult<List<BlushyNotification>>> list({bool unreadOnly = false, int limit = 50}) {
    return ApiContractClient.get(
      '/notifications',
      query: {'unreadOnly': '$unreadOnly', 'limit': '$limit'},
      parse: (data) => ApiParse.list(data).map(BlushyNotification.fromJson).toList(),
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> markRead(List<String> notificationIds) {
    return ApiContractClient.post('/notifications/read', body: {'notificationIds': notificationIds}, parse: ApiParse.map);
  }

  /// Every reminder is tied to an entity so it is cancelled automatically when
  /// its source is deleted.
  static Future<ApiResult<Map<String, dynamic>>> createReminder({
    required String category,
    required String entityType,
    required String entityId,
    String? title,
    String? body,
    DateTime? scheduledFor,
    String? deepLink,
  }) {
    return ApiContractClient.post(
      '/notifications/reminders',
      body: {
        'category': category,
        'entityType': entityType,
        'entityId': entityId,
        'title': ?title,
        'body': ?body,
        if (scheduledFor != null) 'scheduledFor': scheduledFor.toIso8601String(),
        'deepLink': ?deepLink,
      },
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> cancelReminder(String entityType, String entityId) {
    return ApiContractClient.delete('/notifications/reminders/$entityType/$entityId', parse: ApiParse.map);
  }

  /// Registers this device for push. Re-registering the same token is safe:
  /// the server keys on (user, token) rather than accumulating rows.
  static Future<ApiResult<Map<String, dynamic>>> registerDevice({
    required String token,
    required String platform,
    String? appVersion,
  }) {
    return ApiContractClient.post(
      '/notifications/devices',
      body: {
        'token': token,
        'platform': platform,
        'appVersion': ?appVersion,
      },
      parse: ApiParse.map,
    );
  }

  /// Called on sign-out, so notifications for one account never arrive on a
  /// device someone else has since signed into.
  static Future<ApiResult<Map<String, dynamic>>> unregisterDevice(String token) {
    return ApiContractClient.delete(
      '/notifications/devices',
      body: {'token': token},
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<List<Map<String, dynamic>>>> devices() {
    return ApiContractClient.get('/notifications/devices', parse: ApiParse.list);
  }
}

/* ================================================================== *
 * Community moderation (spec sections 12, 22)
 * ================================================================== */

class ModerationApi {
  const ModerationApi._();

  /// Report reasons, moderator actions and the sensitive topic list.
  static Future<ApiResult<Map<String, dynamic>>> config() {
    return ApiContractClient.get('/moderation/config', parse: ApiParse.map);
  }

  /// Reports a post. The response acknowledges receipt without revealing what
  /// the outcome will be, so reporting cannot be used to probe moderation.
  static Future<ApiResult<Map<String, dynamic>>> report(String postId, String reason) {
    return ApiContractClient.post(
      '/moderation/posts/$postId/report',
      body: {'reason': reason},
      parse: ApiParse.map,
    );
  }

  /// Blocking is mutual: neither side sees the other afterwards.
  static Future<ApiResult<Map<String, dynamic>>> block(String userId) {
    return ApiContractClient.post('/moderation/blocks/$userId', parse: ApiParse.map);
  }

  static Future<ApiResult<Map<String, dynamic>>> unblock(String userId) {
    return ApiContractClient.delete('/moderation/blocks/$userId', parse: ApiParse.map);
  }

  static Future<ApiResult<List<String>>> blocked() {
    return ApiContractClient.get(
      '/moderation/blocks',
      parse: (data) => (data as List? ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

class AnalyticsApi {
  const AnalyticsApi._();

  /// Only the defined event names are accepted, and any property outside the
  /// allowlist is dropped server side. Raw journal text and Dr. Docsy conversations
  /// can never reach analytics (spec section 26).
  static Future<ApiResult<Map<String, dynamic>>> track(String eventName, {Map<String, dynamic>? properties}) {
    return ApiContractClient.post(
      '/notifications/analytics/track',
      body: {'eventName': eventName, 'properties': properties ?? const {}},
      parse: ApiParse.map,
    );
  }
}

/// Time capsules: something written now, opened later.
///
/// A sealed capsule's body is withheld by the server until its date, so the
/// seal is a property of the data rather than something the app agrees to
/// respect.
class CapsulesApi {
  const CapsulesApi._();

  static Future<ApiResult<List<Map<String, dynamic>>>> list() {
    return ApiContractClient.get(
      '/capsules',
      parse: (data) => ApiParse.list(data).map(ApiParse.map).toList(),
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> create({
    required String title,
    required String body,
    DateTime? deliverAt,
  }) {
    return ApiContractClient.post(
      '/capsules',
      body: {
        'title': title,
        'body': body,
        if (deliverAt != null) 'deliverAt': deliverAt.toIso8601String(),
      },
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> open(String capsuleId) {
    return ApiContractClient.post('/capsules/$capsuleId/open', parse: ApiParse.map);
  }

  static Future<ApiResult<Map<String, dynamic>>> remove(String capsuleId) {
    return ApiContractClient.delete('/capsules/$capsuleId', parse: ApiParse.map);
  }
}

/// Digital bouquets: made, kept on the account, and given.
///
/// They used to live in SharedPreferences on one device, so a reinstall lost
/// them and "Send Digital Flowers" sent nothing anywhere.
class BouquetsApi {
  const BouquetsApi._();

  static Future<ApiResult<List<Map<String, dynamic>>>> list({bool received = false}) {
    return ApiContractClient.get(
      '/bouquets',
      query: received ? {'received': 'true'} : null,
      parse: (data) => ApiParse.list(data).map(ApiParse.map).toList(),
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> create({
    required String creator,
    required List<String> flowers,
    required int greeneryIndex,
    required int seed,
    required String mode,
    required String message,
    required String wrappingPaper,
    required int ribbonColorIndex,
  }) {
    return ApiContractClient.post(
      '/bouquets',
      body: {
        'creator': creator,
        'flowers': flowers,
        'greeneryIndex': greeneryIndex,
        'seed': seed,
        'mode': mode,
        'message': message,
        'wrappingPaper': wrappingPaper,
        'ribbonColorIndex': ribbonColorIndex,
      },
      parse: ApiParse.map,
    );
  }

  /// The recipient is taken from the connection server-side, so a bouquet
  /// cannot be pushed at an arbitrary account.
  static Future<ApiResult<Map<String, dynamic>>> send(
    String bouquetId, {
    required String connectionId,
  }) {
    return ApiContractClient.post(
      '/bouquets/$bouquetId/send',
      body: {'connectionId': connectionId},
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> open(String bouquetId) {
    return ApiContractClient.post('/bouquets/$bouquetId/open', parse: ApiParse.map);
  }

  static Future<ApiResult<Map<String, dynamic>>> remove(String bouquetId) {
    return ApiContractClient.delete('/bouquets/$bouquetId', parse: ApiParse.map);
  }
}

/// Guided recovery sessions.
///
/// Served from the reviewed content pipeline, so a session awaiting clinical
/// review does not appear at all. An empty list is a real answer.
class RecoveryApi {
  const RecoveryApi._();

  static Future<ApiResult<List<Map<String, dynamic>>>> sessions() {
    return ApiContractClient.get(
      '/recovery/sessions',
      parse: (data) => ApiParse.list(data).map(ApiParse.map).toList(),
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> complete(
    String sessionId, {
    int secondsListened = 0,
  }) {
    return ApiContractClient.post(
      '/recovery/sessions/$sessionId/complete',
      body: {'secondsListened': secondsListened},
      parse: ApiParse.map,
    );
  }
}

/// Clinical content review.
///
/// The backend has carried a full review API from the start -- queue, status
/// changes, audit trail -- but nothing in the app called it, so a reviewer had
/// no way to actually review anything without curl.
///
/// Every route is admin gated server-side; these calls simply fail for anyone
/// without the role.
class ContentReviewApi {
  const ContentReviewApi._();

  /// Articles awaiting review, plus approved ones whose review has come due.
  static Future<ApiResult<Map<String, dynamic>>> queue() {
    return ApiContractClient.get('/content/admin/review-queue', parse: ApiParse.map);
  }

  /// Approving requires a reviewer name. The server refuses without one and
  /// writes it to the audit trail, which is the record of who stood behind
  /// this text.
  static Future<ApiResult<Map<String, dynamic>>> setStatus(
    String contentId, {
    required String status,
    String? reviewer,
    String? reviewDate,
  }) {
    return ApiContractClient.post(
      '/content/admin/$contentId/status',
      body: {
        'status': status,
        if (reviewer != null && reviewer.isNotEmpty) 'reviewer': reviewer,
        if (reviewDate != null && reviewDate.isNotEmpty) 'reviewDate': reviewDate,
      },
      parse: ApiParse.map,
    );
  }

  /// Lets a reviewer correct the text, or attach a real source, before
  /// approving it.
  static Future<ApiResult<Map<String, dynamic>>> update(
    String contentId, {
    String? title,
    String? body,
    String? summary,
    String? source,
  }) {
    return ApiContractClient.patch(
      '/content/admin/$contentId',
      body: {
        'title': ?title,
        'body': ?body,
        'summary': ?summary,
        'source': ?source,
      },
      parse: ApiParse.map,
    );
  }

  static Future<ApiResult<List<Map<String, dynamic>>>> audit(String contentId) {
    return ApiContractClient.get(
      '/content/admin/$contentId/audit',
      parse: (data) => ApiParse.list(data).map(ApiParse.map).toList(),
    );
  }
}
