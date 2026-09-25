import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/state.dart';
import '../../../core/storage.dart';
import '../../../models/blushy_models.dart';
import '../../../services/api_blushy_service.dart';
import '../../../theme/scale.dart';
import '../../../services/api_auth_service.dart';
import '../../../services/api_contract_client.dart';
import '../../../services/auth_storage.dart';
import '../../../services/offline_event_queue.dart';
import '../../../shared/section_heading.dart';
import '../../../theme/colors.dart';
import '../checkin_event_mapper.dart';
import '../checkin_vocabulary.dart';
import '../symptom_categories.dart';
import '../symptom_category_preference.dart';
import 'metric_trend_chart.dart';
import 'numeric_metric_sheet.dart';
import 'symptom_log_sheet.dart';

/// The way in to today's symptom log, as a section of its own.
///
/// This used to live inside everyday_wellness_dashboard.dart, which
/// `home_screen._buildStageDashboard` only reaches for a multi-stage or
/// unrecognised stage. Every recognised stage renders its own dashboard file,
/// and none of those nine referenced [SymptomLogSheet] at all -- so the
/// stage-gated sheet, with its separate groups for pregnancy, menopause and the
/// rest, was unreachable from the stage it was written for.
///
/// Sharing it is what makes one implementation serve ten screens. The groups
/// still differ per stage, because [SymptomCategories.forStage] decides them
/// from [stageKey].
///
/// The host can reopen the sheet from elsewhere on the page through a
/// `GlobalKey<LogSymptomsSectionState>` and [LogSymptomsSectionState.openSheet].
class LogSymptomsSection extends StatefulWidget {
  const LogSymptomsSection({
    super.key,
    required this.stageKey,
    this.showHeading = true,
    this.onMetricsEdited,
    this.onSaved,
    this.onSafety,
  });

  /// Decides which groups the sheet offers. See [SymptomCategories.forStage].
  final String stageKey;

  /// Whether to render the uppercase "LOG SYMPTOMS" section heading.
  final bool showHeading;

  /// Told which `daily_*` keys the user has just edited by hand, so a host that
  /// merges server answers can avoid overwriting them.
  final void Function(String key)? onMetricsEdited;

  /// Today's stored check-in after a save, with the metrics that were written
  /// and the single-answer metrics that were cleared. A host holding in-memory
  /// mirrors of these picks uses it to keep them in step.
  final void Function(
    Map<String, dynamic> checkin,
    Map<String, List<String>> byMetric,
    Set<String> cleared,
  )? onSaved;

  /// A reviewed red flag tripped by what was just logged.
  final void Function(SafetyFlow? safety)? onSafety;

  @override
  State<LogSymptomsSection> createState() => LogSymptomsSectionState();
}

class LogSymptomsSectionState extends State<LogSymptomsSection> {
  /// Recent readings per numeric metric, for the trend the sheet shows.
  final Map<String, List<MetricReading>> _metricHistory = {};

  /// Everything logged today, as the sheet's own keys.
  ///
  /// The flat symptom list, plus each single-answer metric's stored pick --
  /// energy "Low", pain "Severe" -- each qualified with its group, so the
  /// sheet reopens with them selected and "Low" lands on the right chip.
  Set<String> get _loggedSymptoms {
    final checkin = BlushyStorage.read('daily_checkin.json');
    final out = <String>{};

    final raw = checkin['symptom'];
    if (raw is List) {
      out.addAll(raw.map((e) => SymptomKey.normalise(e.toString())));
    }

    for (final category in SymptomCategories.all) {
      if (category.multiSelect) continue;
      final pick = checkin[category.metric];
      if (pick is String && category.options.contains(pick)) {
        out.add(SymptomKey.qualify(category.id, pick));
      }
    }
    return out;
  }

  /// The same, as bare words.
  Set<String> get _loggedLabels => _loggedSymptoms.map(SymptomKey.label).toSet();

  /// Today's value for a numeric metric, or null.
  double? _numericValue(String key) {
    final raw = BlushyStorage.read('daily_checkin.json')[key];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  /// Loads the last month of readings so the sheet opens with a trend.
  ///
  /// Best-effort: the sheet is useful without it, so a failure leaves the
  /// chart empty rather than blocking entry.
  Future<void> _loadMetricHistory(NumericMetric metric) async {
    final result = await EventsApi.list(
      eventTypes: [metric.eventType],
      from: DateTime.now().subtract(const Duration(days: 30)),
      limit: 60,
    );
    if (!mounted || !result.isReady || result.data == null) return;

    final readings = <MetricReading>[];
    // The API returns newest first; a trend line reads the other way.
    for (final event in result.data!.reversed) {
      final raw = event.payload[metric.payloadKey];
      if (raw is num) {
        readings.add(
          MetricReading(day: event.timestamp, value: raw.toDouble()),
        );
      }
    }
    if (!mounted) return;
    setState(() => _metricHistory[metric.key] = readings);
  }

  void _persistNumericMetric(NumericMetric metric, double value) {
    final checkin = Map<String, dynamic>.from(
      BlushyStorage.read('daily_checkin.json'),
    );
    checkin[metric.key] = value;
    checkin['date'] = DateTime.now().toIso8601String();
    BlushyStorage.write('daily_checkin.json', checkin);

    _recordNumericEvent(metric, value);
    widget.onMetricsEdited?.call('daily_${metric.key}');

    ApiAuthService()
        .saveOnboardingAnswers({
          'daily_${metric.key}': value,
          'daily_checkin': checkin,
        })
        .catchError((_) => <String, dynamic>{});
  }

  Future<void> _recordNumericEvent(NumericMetric metric, double value) async {
    final clientEventId = CheckinEventMapper.idempotencyKey(
      userId: AuthStorage.getUserId() ?? 'anon',
      metric: metric.key,
      day: DateTime.now(),
    );
    final payload = {metric.payloadKey: value};

    final result = await EventsApi.log(
      eventType: metric.eventType,
      payload: payload,
      clientEventId: clientEventId,
    );

    if (result.state == ApiState.offline || result.state == ApiState.error) {
      await OfflineEventQueue.instance.enqueue(
        eventType: metric.eventType,
        payload: payload,
        clientEventId: clientEventId,
      );
    }
  }

  /// Opens the entry sheet for one numeric metric.
  Future<void> _openNumericMetric(NumericMetric metric) async {
    // Fetched on open rather than on build: the chart is only ever seen here,
    // and every dashboard would otherwise pay for two requests it may not use.
    unawaited(_loadMetricHistory(metric));
    await NumericMetricSheet.show(
      context,
      metric: metric,
      initialValue: _numericValue(metric.key),
      history: _metricHistory[metric.key] ?? const [],
      onSave: (value) => _persistNumericMetric(metric, value),
    );
    if (mounted) setState(() {});
  }

  /// Removes today's events of the given types: from the offline queue if
  /// they never left the device, and from the server if they did.
  ///
  /// The server's delete is soft and drops the event from every listing, so
  /// the sparkline, the patterns and Docsy's context stop seeing it -- the
  /// same as if it had not been logged. With no connection the delete is
  /// queued and runs on the next flush, ahead of any queued logs.
  Future<void> _deleteLoggedEvents(Set<String> eventTypes) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    for (final type in eventTypes) {
      await OfflineEventQueue.instance.removeWhere(eventType: type, day: now);
    }

    final listed = await EventsApi.list(
      eventTypes: eventTypes.toList(),
      from: startOfDay,
      to: endOfDay,
      limit: 100,
    );
    if (!listed.isReady || listed.data == null) {
      // No connection: the removal waits in the queue and runs on the next
      // flush, against only the events stamped before now.
      for (final type in eventTypes) {
        await OfflineEventQueue.instance.enqueueDelete(
          eventType: type,
          day: now,
          before: now,
        );
      }
      return;
    }
    for (final event in listed.data!) {
      final result = await EventsApi.delete(event.eventId);
      if (!result.isReady) {
        // Lost the connection part way: queue the rest rather than leave
        // half the day deleted.
        await OfflineEventQueue.instance.enqueueDelete(
          eventType: event.eventType,
          day: now,
          before: now,
        );
      }
    }
  }

  /// What was logged on an earlier day, for the sheet's back arrow.
  ///
  /// Today lives on the device; an earlier day exists only as stored events,
  /// so it is fetched and turned back into the words she tapped. An empty set
  /// is a real answer -- the sheet says nothing was logged rather than showing
  /// an empty form that looks like it failed to load.
  Future<Set<String>> _loadLoggedDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final result = await EventsApi.list(
      eventTypes: const [
        'mood_logged',
        'symptom_logged',
        'energy_logged',
        'sleep_logged',
        'stress_logged',
        'hydration_logged',
        'pain_logged',
        'flow_logged',
        'activity_logged',
        'cervical_mucus_logged',
        'lh_test_logged',
        'sexual_activity_logged',
        'pregnancy_test_logged',
        'feeding_logged',
        'hot_flash_logged',
        'recovery_metric_logged',
        'medication_logged',
      ],
      from: start,
      to: end,
      limit: 200,
    );

    if (!result.isReady || result.data == null) return <String>{};

    final keys = <String>{};
    for (final event in result.data!) {
      final mapped = CheckinEventMapper.reverse(event.eventType, event.payload);
      if (mapped == null) continue;
      // Back to the group that recorded it, by metric and word together, so
      // yesterday's "Low" lands on the chip it was tapped on.
      final owner = SymptomCategories.all.cast<SymptomCategory?>().firstWhere(
        (c) => c != null && c.metric == mapped.key && c.options.contains(mapped.value),
        orElse: () => null,
      );
      keys.add(owner == null
          ? mapped.value
          : SymptomKey.qualify(owner.id, mapped.value));
    }
    return keys;
  }

  /// Opens the one logging surface.
  ///
  /// Reached from the "Log Today's Symptoms" button in Today's Cycle. There
  /// was briefly a second button under the check-in as well; two entry points
  /// to one sheet is one too many.
  Future<void> openSheet() async {
    await SymptomLogSheet.show(
      context,
      initialSelection: _loggedSymptoms,
      onSave: _persistCheckinSymptoms,
      // Weight and basal temperature are rows on the same sheet, saved on the
      // same confirm rather than through a second dialog.
      initialNumeric: {
        for (final id in const ['weight', 'bbt'])
          if (_numericValue(id) != null) id: _numericValue(id)!,
      },
      onSaveNumeric: (readings) {
        readings.forEach((id, value) {
          _persistNumericMetric(
            id == 'bbt' ? NumericMetric.bbt : NumericMetric.weight,
            value,
          );
        });
      },
      // The steppers enter today's reading; this opens its history.
      onOpenTrend: (id) => _openNumericMetric(
        id == 'bbt' ? NumericMetric.bbt : NumericMetric.weight,
      ),
      // Decides which groups she is offered at all.
      stage: widget.stageKey,
      onLoadDay: _loadLoggedDay,
    );
    if (mounted) setState(() {});
  }

  /// Stores everything she picked on the symptoms sheet.
  ///
  /// The whole selection is one list, but the options in it do not share a
  /// metric: a flow level is `flow_logged`, a mucus observation is
  /// `cervical_mucus_logged`, an ovulation result is `lh_test_logged`, and a
  /// blood clot is a symptom even though it sits under the flow heading. Each
  /// option is routed by [SymptomCategory.metricFor] rather than all of them
  /// being posted as symptoms, which would have put a fertility reading and a
  /// flow level into the timeline as words.
  ///
  /// Separate from [_persistCheckinAnswer] because the selection is a list:
  /// these co-occur, and the single-value path would let each one erase the
  /// last. Symptoms used to ride the mood selector for exactly that reason,
  /// which meant "happy but cramping" could not be recorded.
  void _persistCheckinSymptoms(Set<String> incoming) {
    // A category switched off is not collected. Filtered here as well as in
    // the sheet because this is the last point before the request.
    final selected = SymptomCategoryPreference.filter(incoming);

    final checkin = Map<String, dynamic>.from(
      BlushyStorage.read('daily_checkin.json'),
    );

    // Each selection is `categoryId/label`, so the group is read from the
    // key rather than guessed from the word. Guessing was the bug: "Medium"
    // belongs to energy and to flow, and the guess always said energy, so a
    // flow of Medium was stored as an energy of Medium and the flow row
    // stayed "Not Logged Today".
    //
    // Stored under each option's own metric as well as in the flat list.
    // Today's Cycle reads `checkin['pain']`, `checkin['flow']` and the rest,
    // and so do the three restore paths.
    final byMetric = <String, List<String>>{};
    final categoryOf = <String, SymptomCategory>{};
    for (final key in selected) {
      final category = SymptomKey.category(key);
      final label = SymptomKey.label(key);
      final metric = category?.metricFor(label) ??
          (CheckinVocabulary.isUnrecorded('symptom', label) ? 'symptom' : null);
      if (metric == null) continue;
      byMetric.putIfAbsent(metric, () => <String>[]).add(label);
      if (category != null) categoryOf.putIfAbsent(metric, () => category);
    }
    byMetric.forEach((metric, labels) {
      final multi = categoryOf[metric]?.multiSelect ?? true;
      // One answer a day stores the answer; a multi-select stores the set.
      checkin[metric] = multi ? labels : labels.first;
      if (metric == 'mood') checkin['feeling'] = labels.first;
    });
    checkin['symptom'] = byMetric['symptom'] ?? const <String>[];

    // A one-answer pick she took off the sheet is cleared, not kept. Only
    // groups she was actually offered can be cleared this way: a group her
    // switches hide is not on the sheet, so its absence says nothing.
    final cleared = <String>{};
    // The stored event type for each cleared metric, so its event can go
    // with it. Read off the mapper with one of the group's own options
    // rather than kept as a second table of types.
    final clearedTypes = <String, String>{};
    for (final category in SymptomCategoryPreference.enabledFor(
      widget.stageKey,
    )) {
      if (category.multiSelect || category.isNumeric) continue;
      final metric = category.metric;
      if (byMetric.containsKey(metric) || !checkin.containsKey(metric)) continue;
      checkin.remove(metric);
      if (metric == 'mood') checkin.remove('feeling');
      cleared.add(metric);
      final type = category.options.isEmpty
          ? null
          : CheckinEventMapper.map(metric, category.options.first)?.eventType;
      if (type != null) clearedTypes[metric] = type;
    }
    if (clearedTypes.isNotEmpty) {
      unawaited(_deleteLoggedEvents(clearedTypes.values.toSet()));
    }

    checkin['date'] = DateTime.now().toIso8601String();
    BlushyStorage.write('daily_checkin.json', checkin);

    // App state, not only storage. `BlushyOSState.wellbeingState` is what
    // Docsy is handed as `context['symptoms']`, and this sheet never touched
    // it -- so whatever she logged here was invisible to the one screen that
    // exists to talk about it. Everything she picked goes in, not just the
    // 'symptom' group: a mood or a pain level is as much a logged signal as
    // a headache.
    final logged = <String>[
      for (final labels in byMetric.values) ...labels,
    ]..removeWhere((label) => label.trim().isEmpty);
    BlushyOSProvider.of(context).updateWellbeing(symptoms: logged);

    // The rows read the in-memory field before storage (`_livingPain ??
    // savedPain`), and the inline check-in sets both. This path set only
    // storage, so a field restored at startup from an earlier check-in kept
    // masking whatever was just saved here: the row said "Mild" for the rest
    // of the session while storage and the server both said "Severe".
    // The host dashboard keeps in-memory mirrors of today's picks and
    // reads those before storage, so it is told what changed.
    widget.onSaved?.call(checkin, byMetric, cleared);
    if (mounted) setState(() {});

    for (final key in selected) {
      final category = SymptomKey.category(key);
      final label = SymptomKey.label(key);
      final metric = category?.metricFor(label);
      // "Everything is fine" is stored above but deliberately not sent; see
      // CheckinVocabulary.unrecorded.
      if (metric == null || CheckinVocabulary.isUnrecorded(metric, label)) {
        continue;
      }
      // The variant keeps one idempotency key per option per day. Without it
      // every option on the sheet would collide on its metric's key and the
      // server would keep whichever arrived first.
      _recordCheckinEvent(metric, label, variant: label);
    }

    widget.onMetricsEdited?.call('daily_symptom');
    for (final metric in byMetric.keys) {
      widget.onMetricsEdited?.call('daily_$metric');
    }
    for (final metric in cleared) {
      widget.onMetricsEdited?.call('daily_$metric');
    }

    ApiAuthService()
        .saveOnboardingAnswers({
          // Sent with every save so the server's copy cannot fall behind the
          // switches, whichever device she changed them on.
          ...SymptomCategoryPreference.exclusionsForSync(),
          'daily_symptom': byMetric['symptom'] ?? const <String>[],
          for (final entry in byMetric.entries)
            'daily_${entry.key}': entry.value.length == 1
                ? entry.value.first
                : entry.value,
          // A cleared pick is sent as empty. The server merges answers by
          // key, so a key not sent keeps its old value there -- and on the
          // next start the device, having no value, would take the server's
          // and the cleared pick would come back. Empty is what the client
          // reads as "nothing to apply".
          for (final metric in cleared) 'daily_$metric': '',
          // Dated, as the inline check-in dates its saves, so the server's
          // copy can be compared with the device's rather than assumed
          // newer.
          'daily_logged_at': checkin['date'],
          // The whole day, cleared keys absent, so the server's copy of the
          // day matches the device's.
          'daily_checkin': checkin,
        })
        .catchError((_) => <String, dynamic>{});
  }

  /// Posts one check-in event. Failures are non-fatal: the local write has
  /// already happened, and the offline queue can replay from there.
  ///
  /// The bucket-to-event mapping lives in [CheckinEventMapper] so it can be
  /// tested without building this widget.
  Future<void> _recordCheckinEvent(
    String metric,
    String rawValue, {
    String? variant,
  }) async {
    final mapped = CheckinEventMapper.map(metric, rawValue);
    if (mapped == null) return;

    final clientEventId = CheckinEventMapper.idempotencyKey(
      userId: AuthStorage.getUserId() ?? 'anon',
      metric: metric,
      day: DateTime.now(),
      variant: variant,
    );

    final result = await EventsApi.log(
      eventType: mapped.eventType,
      payload: mapped.payload,
      clientEventId: clientEventId,
    );

    // A write that could not reach the server is queued rather than lost, and
    // replays with the same id so it cannot be recorded twice (spec §25).
    if (result.state == ApiState.offline || result.state == ApiState.error) {
      await OfflineEventQueue.instance.enqueue(
        eventType: mapped.eventType,
        payload: mapped.payload,
        clientEventId: clientEventId,
      );
      return;
    }

    // This one got through, so the connection is back. The queue was only
    // drained on resume and on a dashboard rebuild, so a backlog built up
    // offline could sit unsent for as long as she stayed in the app.
    unawaited(OfflineEventQueue.instance.flush());

    // A symptom or pain entry can trip a red flag rule; surface the reviewed
    // guidance rather than letting the ordinary confirmation stand.
    if (mounted && result.data?.hasSafetyEscalation == true) {
      widget.onSafety?.call(result.data!.safety);
    }
  }

  /// What is already down for today, named rather than counted.
  ///
  /// Capped: this is a reminder of what is recorded, not the record itself --
  /// the sheet reopens with every one of them still selected.
  String _loggedSummaryLine(Set<String> logged) {
    const maxNamed = 4;
    final names = logged.toList()..sort();
    if (names.length <= maxNamed) {
      return names.join(', ');
    }
    return '${names.take(maxNamed).join(', ')} +${names.length - maxNamed} more';
  }

  /// Symptom logging, as its own section.
  ///
  /// Deliberately not part of CHECK IN. The check-in is the follow-up
  /// questions today's entries earned; this is the way in to make those
  /// entries. They were merged before, and the merge had a cost that was easy
  /// to miss: the button sat inside the check-in's *empty* state, so the only
  /// way to open the sheet vanished the moment anything was logged.
  /// Correcting a mis-tapped symptom then meant hunting for a row in RECENTLY
  /// to tap.
  ///
  /// Always present, therefore -- logging a second symptom an hour later, or
  /// fixing the first, is the ordinary case rather than the exception.
  ///
  /// Which groups the sheet offers is decided by the life stage, through
  /// [SymptomCategories.forStage] and the key from [_resolveStageKey], so this
  /// one section asks a different set of questions in each stage without
  /// needing a variant per stage.
  @override
  Widget build(BuildContext context) {
    final logged = _loggedLabels;
    final hasLogged = logged.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeading) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SectionHeading("LOG SYMPTOMS"),
          ),
          const SizedBox(height: BlushySpace.xs),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasLogged ? 'Logged today' : 'Nothing logged yet today.',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BlushyColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasLogged
                    ? _loggedSummaryLine(logged)
                    : 'Log what you are feeling today. What you are asked '
                        'about follows your stage.',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  height: 1.4,
                  color: BlushyColors.secondaryText,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: openSheet,
                  style: FilledButton.styleFrom(
                    backgroundColor: BlushyColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    hasLogged ? "Edit today's symptoms" : "Log today's symptoms",
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
