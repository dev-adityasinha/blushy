import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'profile_answers.dart';

/// Shows period-day guidance for the physical activities she picked at
/// onboarding. Deliberately body-led, not restrictive: the evidence does not
/// support blanket "don't exercise on your period" rules, so this suggests
/// gentle adjustments for low-energy days while making clear she can train as
/// normal when she feels good.
///
/// Pass the current cycle day and period length so it can tailor the copy to
/// whether she is on her period right now. Renders nothing when she picked no
/// activities (or only "not very active").
class ActivityCareCard extends StatelessWidget {
  const ActivityCareCard({
    super.key,
    this.currentCycleDay,
    this.periodLength,
  });

  final int? currentCycleDay;
  final int? periodLength;

  static const Color _accent = Color(0xFF177E6F);
  static const Color _bg = Color(0xFFE9F6F2);
  static const Color _textMain = Color(0xFF14241F);
  static const Color _textMuted = Color(0xFF5E6E69);

  static const Map<String, String> _periodTips = {
    'Swimming':
        'Totally fine on your period — a tampon or menstrual cup keeps it comfortable. Swim at your usual pace and ease off if cramps show up.',
    'Gym & strength training':
        'Lifting on your period is safe. If your energy dips on heavier days, lower the weight or add a few reps — but train as normal when you feel strong.',
    'Gym / strength training':
        'Lifting on your period is safe. If your energy dips on heavier days, lower the weight or add a few reps — but train as normal when you feel strong.',
    'Yoga':
        'Gentle flows and hip-opening poses can really ease cramps. Only skip a pose if it feels uncomfortable — there is no rule against any of them.',
    'Dance':
        'Dancing can lift your mood and loosen cramps. Keep water close and follow your energy.',
    'Running':
        'Easy runs can ease cramps and boost your mood. Shorten or slow down on low-energy days, and hydrate well.',
    'Cycling':
        'Perfectly fine through your period. Take it a little easier on heavy-flow days if you feel drained.',
    'Badminton':
        'Go for it — just hydrate and take a breather between games if you feel low on energy.',
    'Throwball':
        'All good to play. Rest between points on heavier days and keep water handy.',
    'Kho-Kho':
        'Fine to play — pace yourself on heavy-flow days and hydrate between rounds.',
    'Volleyball':
        'No reason to sit it out. Ease your effort if cramps or fatigue hit, and drink plenty of water.',
    'Walking':
        'A gentle walk can ease cramps and clear your head — lovely on any day of your cycle.',
  };

  static const String _defaultTip =
      'Keep moving at a pace that feels good. Lighter effort on heavy-flow days is completely okay, and you can train as normal when you feel up to it.';

  /// Whether this card will render for the current profile (has at least one
  /// real activity). Used by LifestyleSection to decide the section header.
  static bool hasActivities() => profileListAnswer('physical_activities')
      .any((a) => a.toLowerCase() != 'not very active right now');

  bool get _isOnPeriod {
    final d = currentCycleDay;
    final p = periodLength;
    if (d == null || p == null) return false;
    return d >= 1 && d <= p;
  }

  @override
  Widget build(BuildContext context) {
    final activities = profileListAnswer('physical_activities')
        .where((a) => a.toLowerCase() != 'not very active right now')
        .toList();
    if (activities.isEmpty) return const SizedBox.shrink();

    final shown = activities.take(4).toList();
    final onPeriod = _isOnPeriod;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bg, Colors.white],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.self_improvement_rounded,
                    size: 19, color: _accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  onPeriod ? 'Moving on your period' : 'Moving with your cycle', // i18n-ignore: activity care card (English copy)
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: _textMain,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            onPeriod
                ? 'You can absolutely keep doing what you love — here are gentle tweaks for the days you need them.' // i18n-ignore: activity care card (English copy)
                : "You're outside your period right now, so train as you normally love to. Here's what helps when it arrives:", // i18n-ignore: activity care card (English copy)
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              height: 1.45,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 14),
          ...shown.map(_activityRow),
          const SizedBox(height: 4),
          Text(
            'Gentle suggestions, not rules — your body knows best.', // i18n-ignore: activity care card (English copy)
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: _textMuted.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityRow(String activity) {
    final tip = _periodTips[activity] ?? _defaultTip;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fiber_manual_record, size: 7, color: _accent),
              const SizedBox(width: 8),
              Text(
                activity,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Text(
              tip,
              style: GoogleFonts.manrope(
                fontSize: 12,
                height: 1.4,
                color: _textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
