import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/blushy_surface.dart';
import '../../../theme/colors.dart';
import '../../../theme/scale.dart';
import 'cycle_card.dart';
import '../../../shared/docsy_star.dart';

/// The top of the home tab: the greeting, the cycle, and what was logged
/// lately. Built to the home design spec -- editorial, quiet, content-first.
///
/// Presentation only. The phase, the day, the counts and the words for them
/// come from the dashboard, which has the cycle model and the stored log;
/// nothing here decides what is true, only how it reads.

/// "Good afternoon," on one line, the name on the next, in the display face.
///
/// Replaces the bordered greeting card: the spec asks for the greeting to
/// sit on the page rather than in a box, so the background can breathe.
class GreetingHero extends StatelessWidget {
  const GreetingHero({
    super.key,
    required this.greeting,
    required this.name,
    this.subtitle,
  });

  /// The localised greeting with the name already in it -- "Good morning,
  /// Zaid". The name is split out for its own line and colour.
  final String greeting;

  /// The name as it appears inside [greeting], or "there" when there is
  /// none. Never empty: the second line always reads as someone.
  final String name;

  /// A line under the name, where a screen wants one. The home tab does
  /// not: the greeting stands on its own.
  final String? subtitle;

  /// The greeting with the name removed -- "Good morning," -- or the whole
  /// string where the name is not in it (an unexpected translation shape).
  static String leadOf(String greeting, String name) {
    final at = greeting.lastIndexOf(name);
    if (name.isEmpty || at < 0) return greeting;
    return greeting.substring(0, at).trimRight();
  }

  @override
  Widget build(BuildContext context) {
    final lead = leadOf(greeting, name);
    final hasName = lead != greeting;
    final leadText = hasName ? (lead.endsWith(',') ? lead : '$lead,') : greeting;
    final nameText = hasName ? '$name.' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BlushySpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            leadText,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: BlushyColors.text,
              height: 1.15,
            ),
          ),
          if (nameText.isNotEmpty)
            Text(
              nameText,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: BlushyColors.primary,
                height: 1.15,
              ),
            ),
          const SizedBox(height: BlushySpace.xs + 2),
          Text(
            subtitle ?? "Whatever today looks like, you don't have to do it alone.",
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF7A6B72),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// The four phases the ring and its legend show.
enum CyclePhaseKind { menstrual, follicular, ovulation, luteal }

extension CyclePhaseKindLook on CyclePhaseKind {
  String get label => switch (this) {
        CyclePhaseKind.menstrual => 'Menstrual',
        CyclePhaseKind.follicular => 'Follicular',
        CyclePhaseKind.ovulation => 'Ovulation',
        CyclePhaseKind.luteal => 'Luteal',
      };

  /// Red, soft pink, orange -- and purple for luteal, which the spec allows
  /// only as a phase indicator. It is used nowhere else.
  Color get color => switch (this) {
        CyclePhaseKind.menstrual => BlushyColors.primary,
        CyclePhaseKind.follicular => BlushyColors.secondary,
        CyclePhaseKind.ovulation => BlushyColors.accent,
        CyclePhaseKind.luteal => BlushyColors.lutealPhase,
      };

  /// A line for the phase. Decorative and hedged on purpose -- "may" --
  /// because this is not the cycle model speaking; the model's own words
  /// are on the card's status line.
  String get insight => switch (this) {
        CyclePhaseKind.menstrual => 'Be gentle with yourself today.',
        CyclePhaseKind.follicular => 'A good stretch for starting things.',
        CyclePhaseKind.ovulation => 'You may feel a little more outward today.',
        CyclePhaseKind.luteal => 'You may be feeling a little more inward today.',
      };

  /// The phase a server phase name means, or null for anything else.
  static CyclePhaseKind? parse(String? raw) {
    final v = (raw ?? '').toLowerCase();
    if (v.contains('menstr') || v.contains('period')) return CyclePhaseKind.menstrual;
    if (v.contains('ovul')) return CyclePhaseKind.ovulation;
    if (v.contains('follic')) return CyclePhaseKind.follicular;
    if (v.contains('luteal')) return CyclePhaseKind.luteal;
    return null;
  }
}

/// How much is known about the cycle, as the card needs to know it.
enum CycleCardState {
  /// The request has not answered and there is nothing cached.
  loading,

  /// No period logged: nothing to draw, and no day or phase to assume.
  noTracking,

  /// A day and phase, from the model.
  ready,
}

/// The cycle, as the page's focal element.
///
/// A thin segmented ring -- one tick per day, coloured by phase, with today
/// marked -- around a line for the phase. The spec asks for this in place
/// of the thick illustration stroke, and for four states drawn on purpose:
/// loading (a skeleton), no tracking (an invitation, no assumed day),
/// insufficient data (the model's own caveat, no invented precision), and
/// the ordinary case.
class CycleRingCard extends StatelessWidget {
  const CycleRingCard({
    super.key,
    required this.state,
    this.phase,
    this.cycleDay,
    this.cycleLength,
    this.periodLength = 5,
    this.caveat,
    this.onCalendar,
    this.onInsights,
    this.onSetUp,
  });

  final CycleCardState state;
  final CyclePhaseKind? phase;
  final int? cycleDay;
  final int? cycleLength;
  final int periodLength;

  /// The model's own note where predictions are limited or the cycle is
  /// irregular -- shown as written, never reworded into confidence.
  final String? caveat;

  final VoidCallback? onCalendar;
  final VoidCallback? onInsights;
  final VoidCallback? onSetUp;

  @override
  Widget build(BuildContext context) {
    return BlushySurface(
      padding: const EdgeInsets.fromLTRB(
          BlushySpace.xl, BlushySpace.xl, BlushySpace.xl, BlushySpace.sm),
      child: switch (state) {
        CycleCardState.loading => const _RingSkeleton(),
        CycleCardState.noTracking => _NoTracking(onSetUp: onSetUp),
        CycleCardState.ready => _Ready(card: this),
      },
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({required this.card});

  final CycleRingCard card;

  @override
  Widget build(BuildContext context) {
    final phase = card.phase;
    final day = card.cycleDay;
    final length = card.cycleLength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'YOUR CYCLE',
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: BlushyColors.primary,
              ),
            ),
            if (card.onCalendar != null)
              InkWell(
                onTap: card.onCalendar,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF3D5D8), width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 12, color: BlushyColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Calendar',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: BlushyColors.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, size: 14, color: BlushyColors.primary),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: BlushySpace.xs),
        Row(
          children: [
            Flexible(
              child: Text(
                phase == null ? 'Your cycle' : '${phase.label} phase',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: BlushyColors.text,
                ),
              ),
            ),
            if (phase != null) ...[
              const SizedBox(width: BlushySpace.xs + 2),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: phase.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        if (day != null && length != null)
          Text(
            'Day $day of $length',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF7A6B72),
            ),
          ),
        const SizedBox(height: BlushySpace.lg),
        const Center(
          child: SizedBox(
            width: 260,
            height: 96,
            child: BlushyCycleCard(purePainterMode: true),
          ),
        ),
        const SizedBox(height: BlushySpace.md),
        Text(
          card.caveat ?? phase?.insight ?? 'You may be feeling a little more inward today.',
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.manrope(
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
            color: BlushyColors.text,
            height: 1.4,
          ),
        ),
        const SizedBox(height: BlushySpace.md),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final kind in CyclePhaseKind.values) ...[
                if (kind != CyclePhaseKind.values.first)
                  const SizedBox(width: BlushySpace.md),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: kind.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: BlushySpace.xs),
                Text(
                  kind.label,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF7A6B72),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (card.onInsights != null) ...[
          const SizedBox(height: BlushySpace.lg),
          const Divider(height: 1, thickness: 1, color: BlushyColors.border),
          InkWell(
            onTap: card.onInsights,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: BlushySpace.md),
              child: Row(
                children: [
                  const DocsyStar(size: 16, color: BlushyColors.primary),
                  const SizedBox(width: BlushySpace.md),
                  Expanded(
                    child: Text(
                      'Insights for your phase',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: BlushyColors.text,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: BlushyColors.secondaryText),
                ],
              ),
            ),
          ),
        ] else
          const SizedBox(height: BlushySpace.md),
      ],
    );
  }
}

/// The ring: one tick per day, coloured by phase, today marked.
///
/// Phases are laid out from the cycle length and the period length the way
/// the legend under the hero does: the period first, ovulation around
/// fourteen days before the end, the luteal stretch after it. Ticks for days
/// already passed are drawn solid; the rest are faint. The marker is a ring
/// on today's tick, so it is unmistakable without being heavy.
class CycleRingPainter extends CustomPainter {
  CycleRingPainter({
    required this.cycleDay,
    required this.cycleLength,
    required this.periodLength,
  });

  final int cycleDay;
  final int cycleLength;
  final int periodLength;

  static CyclePhaseKind phaseOfDay(int day, int cycleLength, int periodLength) {
    final ovulation = (cycleLength - 14).clamp(periodLength + 2, cycleLength);
    if (day <= periodLength) return CyclePhaseKind.menstrual;
    if (day >= ovulation - 1 && day <= ovulation + 1) return CyclePhaseKind.ovulation;
    if (day < ovulation) return CyclePhaseKind.follicular;
    return CyclePhaseKind.luteal;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (cycleLength <= 0) return;
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const tickLength = 12.0;
    final today = cycleDay.clamp(1, cycleLength);

    for (var d = 1; d <= cycleLength; d++) {
      // Day one at the top, clockwise.
      final angle = -math.pi / 2 + 2 * math.pi * (d - 1) / cycleLength;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final outer = centre + dir * radius;
      final inner = centre + dir * (radius - tickLength);
      final kind = phaseOfDay(d, cycleLength, periodLength);
      final passed = d <= today;
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = kind.color.withValues(alpha: passed ? 1.0 : 0.30)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // Today.
    final angle = -math.pi / 2 + 2 * math.pi * (today - 1) / cycleLength;
    final at = centre + Offset(math.cos(angle), math.sin(angle)) * (radius - tickLength / 2);
    canvas.drawCircle(at, 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      at,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = BlushyColors.primary,
    );
    canvas.drawCircle(at, 3.5, Paint()..color = BlushyColors.primary);
  }

  @override
  bool shouldRepaint(covariant CycleRingPainter old) =>
      old.cycleDay != cycleDay ||
      old.cycleLength != cycleLength ||
      old.periodLength != periodLength;
}

class _RingSkeleton extends StatelessWidget {
  const _RingSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: BlushyColors.border,
            borderRadius: BorderRadius.circular(6),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bar(80, 10),
        const SizedBox(height: BlushySpace.md),
        bar(180, 26),
        const SizedBox(height: BlushySpace.sm),
        bar(90, 14),
        const SizedBox(height: BlushySpace.lg),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: BlushyColors.border, width: 10),
            ),
          ),
        ),
        const SizedBox(height: BlushySpace.lg),
      ],
    );
  }
}

/// No period logged. Nothing is assumed: no day, no phase.
class _NoTracking extends StatelessWidget {
  const _NoTracking({required this.onSetUp});

  final VoidCallback? onSetUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('YOUR CYCLE', style: BlushyType.eyebrow()),
        const SizedBox(height: BlushySpace.sm),
        Text('Start with your last period', style: BlushyType.headline()),
        const SizedBox(height: BlushySpace.sm),
        Text(
          'Everything here is counted from the period dates you log. Add the '
          'first and the page fills in around it.',
          style: BlushyType.body(),
        ),
        const SizedBox(height: BlushySpace.lg),
        if (onSetUp != null)
          _QuietPill(
            icon: Icons.calendar_today_outlined,
            label: 'Log a period start',
            onTap: onSetUp!,
            filled: true,
          ),
        const SizedBox(height: BlushySpace.md),
      ],
    );
  }
}

/// A quiet outlined pill, or a filled one for the single primary action.
class _QuietPill extends StatelessWidget {
  const _QuietPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : BlushyColors.primary;
    return Material(
      color: filled ? BlushyColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 44,
          // Compact, so the headline beside it keeps its size: the pill is
          // the secondary thing on its row.
          padding: const EdgeInsets.symmetric(horizontal: BlushySpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: filled ? null : Border.all(color: BlushyColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: BlushySpace.xs + 2),
              Text(label, style: BlushyType.caption(color: fg, weight: FontWeight.w600)),
              if (!filled) ...[
                const SizedBox(width: BlushySpace.xs),
                Icon(Icons.chevron_right_rounded, size: 18, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of what was logged lately.
class RecentItem {
  const RecentItem({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;

  /// Already worded by the dashboard -- "18-22 Aug", "Bloating, Cramps".
  final String value;

  final VoidCallback? onTap;
}

/// Recently: one surface, a few rows, a chevron each.
///
/// Empty rows are not passed in: the dashboard only includes what has a
/// value, and when nothing does the card says so with a first action rather
/// than showing an empty box.
class RecentlySurface extends StatelessWidget {
  const RecentlySurface({super.key, required this.items, this.onEmptyAction});

  final List<RecentItem> items;

  /// What to do when there is nothing yet -- opens the logging sheet.
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BlushySpace.xs),
          child: Text(
            'RECENTLY',
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: BlushyColors.primary,
            ),
          ),
        ),
        const SizedBox(height: BlushySpace.xs + 2),
        BlushySurface(
          padding: const EdgeInsets.symmetric(vertical: BlushySpace.xs),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(BlushySpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nothing logged yet', style: BlushyType.heading()),
                      const SizedBox(height: BlushySpace.xs),
                      Text(
                        'Your period, symptoms and mood will show here once '
                        'you log them.',
                        style: BlushyType.body(),
                      ),
                      if (onEmptyAction != null) ...[
                        const SizedBox(height: BlushySpace.md),
                        _QuietPill(
                          icon: Icons.edit_note_rounded,
                          label: 'Log today',
                          onTap: onEmptyAction!,
                          filled: false,
                        ),
                      ],
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: BlushySpace.lg),
                          child: Divider(height: 1, thickness: 1, color: BlushyColors.border),
                        ),
                      _RecentRow(item: items[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.item});

  final RecentItem item;

  Color _badgeBg(String title) {
    final t = title.toLowerCase();
    if (t.contains('period')) return const Color(0xFFFDF2F4);
    if (t.contains('symptom')) return const Color(0xFFFDF6F0);
    return const Color(0xFFFDF8EE);
  }

  Border _badgeBorder(String title) {
    final t = title.toLowerCase();
    if (t.contains('period')) return Border.all(color: const Color(0xFFF7D8DD), width: 0.8);
    if (t.contains('symptom')) return Border.all(color: const Color(0xFFF9E4DA), width: 0.8);
    return Border.all(color: const Color(0xFFFBE6CE), width: 0.8);
  }

  Color _iconColor(String title) {
    final t = title.toLowerCase();
    if (t.contains('period')) return BlushyColors.primary;
    if (t.contains('symptom')) return const Color(0xFFE06D53);
    return const Color(0xFFE59239);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: BlushySpace.lg, vertical: BlushySpace.md),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _badgeBg(item.title),
                border: _badgeBorder(item.title),
              ),
              child: Icon(item.icon, size: 16, color: _iconColor(item.title)),
            ),
            const SizedBox(width: BlushySpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BlushyColors.text,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF7A6B72),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFFB5A9AF),
            ),
          ],
        ),
      ),
    );
  }
}
