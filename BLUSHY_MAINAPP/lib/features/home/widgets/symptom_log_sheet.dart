import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart' hide BlushyColors;
import '../../../theme/colors.dart';
import '../symptom_categories.dart';
import 'numeric_metric_sheet.dart' show NumericMetric;
import '../symptom_category_preference.dart';

/// Where symptoms are logged, kept off the daily check-in.
///
/// The check-in is one tap per metric and answers "how are you". Symptoms are
/// a different act: several at once, not every day. Putting them on the
/// check-in is what produced the bug this sheet exists to fix -- 'Cramps' and
/// 'Tired' were mood options, so logging a symptom recorded no mood and
/// overwrote whichever mood had been picked.
///
/// The groups shown depend on the life stage: see [SymptomCategories]. A
/// pregnancy user is not offered an ovulation test, and a menopause user is
/// not offered a menstrual flow selector.
class SymptomLogSheet extends StatefulWidget {
  const SymptomLogSheet({
    super.key,
    required this.initialSelection,
    required this.onSave,
    this.onSaveNumeric,
    this.onOpenTrend,
    this.initialNumeric = const {},
    this.stage,
    this.onLoadDay,
  });

  /// What is already logged for today, so re-opening shows it selected.
  final Set<String> initialSelection;

  final void Function(Set<String> selected) onSave;

  /// Called with the readings she changed, keyed by numeric id.
  final void Function(Map<String, double> readings)? onSaveNumeric;

  /// Opens the full history for one reading. The steppers here are for
  /// entering today's; the trend behind it is worth its own view.
  final void Function(String numericId)? onOpenTrend;

  /// Today's readings, so the rows open on what is already logged.
  final Map<String, double> initialNumeric;

  /// Her life stage, which decides the groups. Null shows the wellness set.
  final String? stage;

  /// Loads what was logged on an earlier day, for the back arrow.
  ///
  /// Today comes from the device; an earlier day only exists as stored events,
  /// so it has to be fetched. Null means the sheet cannot look back, and the
  /// arrows are hidden rather than shown doing nothing.
  final Future<Set<String>> Function(DateTime day)? onLoadDay;

  /// A glyph per option, keyed `categoryId/label`.
  ///
  /// Keyed by category and not by label alone: five words appear in more
  /// than one group. 'Medium' is a flow level and an energy level, 'Low' is a
  /// mood, an energy and a stress level, and a single map gave the energy
  /// chip a water drop. A test walks every category against this.
  static const Map<String, IconData> icons = {
    'Everything is fine': Icons.thumb_up_alt_outlined,

    'mood/Happy': Icons.sentiment_satisfied_alt_rounded,
    'mood/Okay': Icons.sentiment_neutral_rounded,
    'mood/Calm': Icons.self_improvement_rounded,
    'mood/Low': Icons.sentiment_dissatisfied_rounded,
    'mood/Irritable': Icons.mood_bad_rounded,

    'energy/High': Icons.battery_full_rounded,
    'energy/Medium': Icons.battery_4_bar_rounded,
    'energy/Low': Icons.battery_2_bar_rounded,

    'pain/None': Icons.check_circle_outline_rounded,
    'pain/Mild': Icons.remove_circle_outline_rounded,
    'pain/Severe': Icons.error_outline_rounded,

    'sleep/<6h': Icons.bedtime_off_outlined,
    'sleep/6-8h': Icons.bedtime_outlined,
    'sleep/>8h': Icons.hotel_rounded,

    'stress/Low': Icons.spa_outlined,
    'stress/Moderate': Icons.waves_rounded,
    'stress/High': Icons.flash_on_rounded,

    'water/1L': Icons.local_drink_outlined,
    'water/2L': Icons.local_drink_rounded,
    'water/3L': Icons.water_drop_rounded,

    'movement/Active': Icons.directions_run_rounded,
    'movement/Light': Icons.directions_walk_rounded,
    'movement/None': Icons.airline_seat_recline_normal_rounded,

    'flow/Light': Icons.water_drop_outlined,
    'flow/Medium': Icons.water_drop,
    'flow/Heavy': Icons.opacity_rounded,
    'flow/Blood clots': Icons.grain_rounded,

    'symptom/Cramps': Icons.bolt_rounded,
    'symptom/Headache': Icons.psychology_alt_outlined,
    'symptom/Tender breasts': Icons.favorite_border_rounded,
    'symptom/Backache': Icons.accessibility_new_rounded,
    'symptom/Abdominal pain': Icons.blur_circular_rounded,
    'symptom/Acne': Icons.face_retouching_natural_outlined,
    'symptom/Fatigue': Icons.battery_2_bar_rounded,
    'symptom/Cravings': Icons.cookie_outlined,
    'symptom/Insomnia': Icons.bedtime_off_outlined,
    'symptom/Swelling': Icons.bubble_chart_rounded,
    'symptom/Dry skin': Icons.texture_rounded,
    'symptom/Dry eyes': Icons.visibility_off_outlined,

    'hair/Hair thinning': Icons.content_cut_rounded,
    'hair/Excess facial hair': Icons.face_rounded,

    'intimate/Vaginal itching': Icons.spa_outlined,
    'intimate/Vaginal dryness': Icons.opacity_outlined,

    'discharge/Dry': Icons.wb_sunny_outlined,
    'discharge/Sticky': Icons.colorize_outlined,
    'discharge/Creamy': Icons.invert_colors_on_rounded,
    'discharge/Watery': Icons.water_outlined,
    'discharge/Eggwhite': Icons.egg_alt_outlined,
    'discharge/Unusual': Icons.help_outline_rounded,
    'discharge/Clumpy white': Icons.scatter_plot_rounded,
    'discharge/Grey': Icons.cloud_outlined,

    'digestion/Nausea': Icons.sick_outlined,
    'digestion/Bloating': Icons.bubble_chart_outlined,
    'digestion/Constipation': Icons.hourglass_bottom_rounded,
    'digestion/Diarrhea': Icons.waves_rounded,

    'sex/Did not have sex': Icons.do_not_disturb_alt_rounded,
    'sex/Protected sex': Icons.shield_outlined,
    'sex/Unprotected sex': Icons.lock_open_rounded,
    'sex/Oral sex': Icons.favorite_rounded,
    'sex/Masturbation': Icons.self_improvement_outlined,
    'sex/Sensual touch': Icons.back_hand_outlined,
    'sex/High sex drive': Icons.trending_up_rounded,
    'sex/Neutral sex drive': Icons.trending_flat_rounded,
    'sex/Low sex drive': Icons.trending_down_rounded,

    'ovulation_test/Test: negative': Icons.remove_circle_outline,
    'ovulation_test/Test: low': Icons.signal_cellular_alt_1_bar_rounded,
    'ovulation_test/Test: high': Icons.signal_cellular_alt_2_bar_rounded,
    'ovulation_test/Test: peak': Icons.signal_cellular_alt_rounded,

    'pregnancy_test/Did not test': Icons.do_not_disturb_alt_rounded,
    'pregnancy_test/Positive': Icons.add_circle_outline_rounded,
    'pregnancy_test/Negative': Icons.remove_circle_outline_rounded,
    'pregnancy_test/Faint line': Icons.more_horiz_rounded,

    'activity/Did not exercise': Icons.airline_seat_recline_normal_rounded,
    'activity/Yoga': Icons.self_improvement_outlined,
    'activity/Gym': Icons.fitness_center_rounded,
    'activity/Aerobics and dancing': Icons.music_note_rounded,
    'activity/Swimming': Icons.pool_rounded,
    'activity/Team sports': Icons.sports_basketball_rounded,
    'activity/Running': Icons.directions_run_rounded,
    'activity/Cycling': Icons.directions_bike_rounded,
    'activity/Walking': Icons.directions_walk_rounded,

    'lifestyle/Travel': Icons.flight_takeoff_rounded,
    'lifestyle/Meditation': Icons.spa_rounded,
    'lifestyle/Journaling': Icons.menu_book_rounded,
    'lifestyle/Kegel exercises': Icons.fitness_center_outlined,
    'lifestyle/Breathing exercises': Icons.air_rounded,
    'lifestyle/Disease or injury': Icons.healing_rounded,
    'lifestyle/Alcohol': Icons.wine_bar_outlined,

    'fetal_movement/Active': Icons.child_care_rounded,
    'fetal_movement/Normal': Icons.check_circle_outline_rounded,
    'fetal_movement/Quiet': Icons.volume_off_rounded,

    'contractions/None': Icons.check_circle_outline_rounded,
    'contractions/Mild': Icons.waves_rounded,
    'contractions/Strong': Icons.flash_on_rounded,

    'feeding/Breastfeeding': Icons.child_friendly_rounded,
    'feeding/Bottle Feeding': Icons.local_drink_rounded,
    'feeding/Pumping': Icons.compress_rounded,

    'postpartum_bleeding/None': Icons.check_circle_outline_rounded,
    'postpartum_bleeding/Spotting': Icons.water_drop_outlined,
    'postpartum_bleeding/Flow': Icons.opacity_rounded,

    'incision/Healing': Icons.healing_rounded,
    'incision/Sore': Icons.error_outline_rounded,
    'incision/Not Applicable': Icons.do_not_disturb_alt_rounded,

    'pelvic_floor/Completed': Icons.check_circle_outline_rounded,
    'pelvic_floor/Not Done': Icons.radio_button_unchecked_rounded,

    'hot_flash/None': Icons.check_circle_outline_rounded,
    'hot_flash/Mild': Icons.thermostat_rounded,
    'hot_flash/Intense': Icons.local_fire_department_rounded,

    'night_sweat/None': Icons.check_circle_outline_rounded,
    'night_sweat/Mild': Icons.nightlight_round,
    'night_sweat/Intense': Icons.water_drop_rounded,

    'brain_fog/None': Icons.check_circle_outline_rounded,
    'brain_fog/Mild': Icons.cloud_queue_rounded,
    'brain_fog/Intense': Icons.cloud_rounded,

    'joint_pain/None': Icons.check_circle_outline_rounded,
    'joint_pain/Mild': Icons.accessibility_rounded,
    'joint_pain/Intense': Icons.error_outline_rounded,

    'hormone_therapy/Taken': Icons.check_circle_outline_rounded,
    'hormone_therapy/Not Taken': Icons.radio_button_unchecked_rounded,
    'hormone_therapy/None': Icons.do_not_disturb_alt_rounded,
  };

  /// A tint per group, so a glance tells you which section you are in.
  static const Map<String, Color> tints = {
    'mood': Color(0xFFE0A458),
    'energy': Color(0xFFD9A521),
    'pain': Color(0xFFC96A6A),
    'sleep': Color(0xFF6C7BB0),
    'stress': Color(0xFFB0776C),
    'water': Color(0xFF4E9FC6),
    'movement': Color(0xFF5FA36A),
    'flow': Color(0xFFE0699A),
    'symptom': Color(0xFFB07CC6),
    'intimate': Color(0xFF9B7CC6),
    'hair': Color(0xFFA98A6C),
    'discharge': Color(0xFF7C86C6),
    'digestion': Color(0xFFD16BA5),
    'sex': Color(0xFFDD5E7C),
    'ovulation_test': Color(0xFF4FA8A0),
    'pregnancy_test': Color(0xFFE09355),
    'activity': Color(0xFF5FA36A),
    'lifestyle': Color(0xFFD79A4A),
    'fetal_movement': Color(0xFF7BA7D9),
    'contractions': Color(0xFFC96A8A),
    'feeding': Color(0xFF6FA8A0),
    'postpartum_bleeding': Color(0xFFD1697F),
    'incision': Color(0xFFC08457),
    'pelvic_floor': Color(0xFF7FA36A),
    'hot_flash': Color(0xFFD9663D),
    'night_sweat': Color(0xFF5E7FB0),
    'brain_fog': Color(0xFF8A8FA8),
    'joint_pain': Color(0xFFB07C8A),
    'hormone_therapy': Color(0xFF6C8FC6),
    'weight': Color(0xFF6F7C8C),
    'bbt': Color(0xFFC0507A),
  };

  /// Opens the sheet and saves on confirm. Returns what was saved, or null if
  /// it was dismissed.
  static Future<Set<String>?> show(
    BuildContext context, {
    required Set<String> initialSelection,
    required void Function(Set<String>) onSave,
    void Function(Map<String, double>)? onSaveNumeric,
    void Function(String)? onOpenTrend,
    Map<String, double> initialNumeric = const {},
    String? stage,
    Future<Set<String>> Function(DateTime)? onLoadDay,
  }) {
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SymptomLogSheet(
        initialSelection: initialSelection,
        onSave: onSave,
        onSaveNumeric: onSaveNumeric,
        onOpenTrend: onOpenTrend,
        initialNumeric: initialNumeric,
        stage: stage,
        onLoadDay: onLoadDay,
      ),
    );
  }

  @override
  State<SymptomLogSheet> createState() => _SymptomLogSheetState();
}

class _SymptomLogSheetState extends State<SymptomLogSheet> {
  // Qualified on the way in, so a bare word from an older caller still
  // lands on a chip. Everything from here on is `categoryId/label`.
  late final Set<String> _selected = {
    for (final key in widget.initialSelection) SymptomKey.normalise(key),
  };

  /// Readings changed on this sheet, by numeric id. Only what she touched is
  /// sent, so opening the sheet and closing it does not record a weight.
  final Map<String, double> _numeric = {};

  /// The day being looked at. Today unless she has used the back arrow.
  late DateTime _day = _startOfToday();

  /// What was logged on [_day], when that day is not today.
  Set<String>? _pastSelection;
  bool _loadingDay = false;

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isToday {
    final today = _startOfToday();
    return _day.year == today.year &&
        _day.month == today.month &&
        _day.day == today.day;
  }

  /// Only today can be edited.
  ///
  /// An earlier day is shown as it was recorded. Writing to it would need the
  /// event timestamped to that day and the idempotency key rebuilt around it;
  /// until that exists, offering chips that silently record against today
  /// would be worse than not offering them.
  bool get _readOnly => !_isToday;

  Set<String> get _shown => _isToday ? _selected : (_pastSelection ?? const {});

  Future<void> _goToDay(DateTime day) async {
    final today = _startOfToday();
    // There is nothing to log in the future, so the forward arrow stops here.
    if (day.isAfter(today)) return;

    setState(() {
      _day = day;
      _pastSelection = null;
      _loadingDay = !_isToday;
    });

    if (_isToday || widget.onLoadDay == null) return;

    final loaded = await widget.onLoadDay!(day);
    if (!mounted) return;
    setState(() {
      _pastSelection = {for (final key in loaded) SymptomKey.normalise(key)};
      _loadingDay = false;
    });
  }

  /// "Today", or the date. Yesterday is named too: it is the day most often
  /// looked back at, and a date reads as further away than it is.
  String get _dayLabel {
    if (_isToday) return 'Today';
    final today = _startOfToday();
    if (today.difference(_day).inDays == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final label = '${_day.day} ${months[_day.month - 1]}';
    return _day.year == today.year ? label : '$label ${_day.year}';
  }

  /// True for a key that belongs to [category].
  static bool _inGroup(SymptomCategory category, String key) =>
      SymptomKey.categoryId(key) == category.id;

  void _toggle(SymptomCategory category, String label) {
    // Keyed by group as well as word. The words are not unique across
    // groups -- "Low" is mood, energy and stress -- and as bare words the
    // sheet could hold only one of them.
    final key = SymptomKey.qualify(category.id, label);
    setState(() {
      if (!category.multiSelect) {
        // One answer a day: the group's other pick goes, this one comes --
        // or, tapped again, it goes and nothing replaces it.
        final wasSelected = _selected.contains(key);
        _selected.removeWhere((k) => _inGroup(category, k));
        if (!wasSelected) _selected.add(key);
        return;
      }

      if (!_selected.remove(key)) _selected.add(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Stage decides which groups exist at all; the switches decide which of
    // those are still being collected.
    final categories = SymptomCategories.forStage(widget.stage);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: BlushyColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: BlushyColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isToday ? "Log today's symptoms" : 'Logged symptoms',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: BlushyColors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: BlushyColors.secondaryText),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (widget.onLoadDay != null) _dayNavigator(),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: [
                  if (_loadingDay)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_readOnly && _shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Nothing was logged by you.',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: BlushyColors.secondaryText,
                          ),
                        ),
                      ),
                    )
                  else ...[
                  for (final category in categories) ...[
                    if (category != categories.first) const SizedBox(height: 18),
                    _CategoryHeader(
                      title: category.label,
                      subtitle: category.subtitle,
                    ),
                    const SizedBox(height: 10),
                    if (category.isNumeric)
                      _numericRow(category)
                    else
                      _chips(category),
                    const SizedBox(height: 8),
                  ],
                ],
                ],
              ),
            ),
            if (_readOnly)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Text(
                    'This day is shown as you logged it.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
                ),
              )
            else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      // Filtered again on the way out: the switch is the
                      // promise, and this is the last place it can be kept.
                      final keep = SymptomCategoryPreference.filter(_selected);
                      widget.onSave(keep);
                      if (_numeric.isNotEmpty) {
                        widget.onSaveNumeric?.call(_numeric);
                      }
                      Navigator.of(context).pop(keep);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(BlushyTheme.radius),
                      ),
                    ),
                    child: Text(
                      _selected.isEmpty ? 'Save' : 'Save ${_selected.length}',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A reading rather than a choice.
  ///
  /// Weight and basal temperature are numbers, so they get a stepper and a
  /// field instead of chips. They are stored on the same save as everything
  /// else on the sheet rather than through a second dialog.
  Widget _numericRow(SymptomCategory category) {
    final metric = category.numericId == 'bbt'
        ? NumericMetric.bbt
        : NumericMetric.weight;
    final tint = SymptomLogSheet.tints[category.id] ?? BlushyColors.primary;
    final current = widget.initialNumeric[category.numericId] ??
        _numeric[category.numericId];

    return Material(
      color: BlushyColors.cardBg,
      borderRadius: BorderRadius.circular(BlushyTheme.radius),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BlushyTheme.radius),
          border: Border.all(color: BlushyColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                category.numericId == 'bbt'
                    ? Icons.thermostat_rounded
                    : Icons.monitor_weight_outlined,
                size: 17,
                color: tint,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: widget.onOpenTrend == null
                    ? null
                    : () => widget.onOpenTrend!(category.numericId!),
                child: Row(
                  children: [
                    Text(
                      current == null
                          ? 'Not logged'
                          : '${metric.format(current)} ${metric.unit}',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: current == null
                            ? BlushyColors.secondaryText
                            : BlushyColors.text,
                      ),
                    ),
                    if (widget.onOpenTrend != null) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.show_chart_rounded,
                          size: 15, color: BlushyColors.secondaryText),
                    ],
                  ],
                ),
              ),
            ),
            _NumericStep(
              icon: Icons.remove,
              onTap: () => _nudgeNumeric(category, metric, -metric.step),
            ),
            const SizedBox(width: 6),
            _NumericStep(
              icon: Icons.add,
              onTap: () => _nudgeNumeric(category, metric, metric.step),
            ),
          ],
        ),
      ),
    );
  }

  void _nudgeNumeric(
      SymptomCategory category, NumericMetric metric, double by) {
    final id = category.numericId!;
    final seed = _numeric[id] ??
        widget.initialNumeric[id] ??
        (id == 'bbt' ? 36.5 : 60.0);
    // Snapped to the step so repeated taps do not accumulate a drift the
    // decimals then hide, and clamped to the range the server enforces.
    final next = (seed + by).clamp(metric.min, metric.max);
    final snapped =
        ((next / metric.step).round() * metric.step).clamp(metric.min, metric.max);
    setState(() => _numeric[id] = double.parse(metric.format(snapped)));
  }

  /// The day being looked at, with an arrow either side.
  Widget _dayNavigator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _DayArrow(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous day',
            onTap: () =>
                _goToDay(_day.subtract(const Duration(days: 1))),
          ),
          Expanded(
            child: Text(
              _dayLabel,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BlushyColors.text,
              ),
            ),
          ),
          _DayArrow(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next day',
            // Nothing to see in the future, so this is off on today rather
            // than appearing to work and doing nothing.
            onTap: _isToday
                ? null
                : () => _goToDay(_day.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }

  Widget _chips(SymptomCategory category) {
    final tint = SymptomLogSheet.tints[category.id] ?? BlushyColors.primary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in category.options)
          _SymptomChip(
            label: label,
            icon: SymptomLogSheet.icons['${category.id}/$label'] ??
                Icons.circle_outlined,
            tint: tint,
            selected: _shown.contains(SymptomKey.qualify(category.id, label)),
            onTap: _readOnly ? null : () => _toggle(category, label),
          ),
      ],
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: BlushyColors.secondaryText,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: BlushyColors.secondaryText,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SymptomChip extends StatelessWidget {
  const _SymptomChip({
    required this.label,
    required this.icon,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final bool selected;

  /// Null renders the chip as a record rather than a control, which is how an
  /// earlier day is shown.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? tint.withValues(alpha: 0.16) : BlushyColors.cardBg,
      // Pills, deliberately, and the one exception to the app's 12px rule --
      // see the allowlist in corner_radius_test.dart.
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? tint : BlushyColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: selected ? 0.28 : 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: tint),
              ),
              const SizedBox(width: 9),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: BlushyColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _NumericStep extends StatelessWidget {
  const _NumericStep({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BlushyColors.background,
      shape: const CircleBorder(
        side: BorderSide(color: BlushyColors.border),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 18, color: BlushyColors.text),
        ),
      ),
    );
  }
}


class _DayArrow extends StatelessWidget {
  const _DayArrow({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;

  /// Null disables it, which is how the forward arrow reads on today.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              size: 26,
              color:
                  enabled ? BlushyColors.text : BlushyColors.border,
            ),
          ),
        ),
      ),
    );
  }
}
