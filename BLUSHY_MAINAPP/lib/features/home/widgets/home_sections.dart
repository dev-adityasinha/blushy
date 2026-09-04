import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/blushy_surface.dart';
import '../../../shared/section_heading.dart';
import '../../../theme/colors.dart';
import '../../../theme/scale.dart';
import 'cycle_anatomy_painter.dart';
import 'cycle_outline.dart';

/// The four blocks the home tab opens with.
///
/// Presentation only. Every one of them takes its text and its callbacks from
/// the dashboard, so what is on screen still comes from what has actually been
/// logged -- these decide how it looks, never what it says. Every size in here
/// is from [BlushyType] and [BlushySpace]; none is chosen per widget.

/// The cycle, as the first thing on the page.
///
/// Centred: the illustration in the middle with the day under it, and the
/// estimate in its own panel at the foot. The day is the one number someone
/// opens the app for, so it is set at display size and nothing shares its
/// line.
class CycleHeroCard extends StatelessWidget {
  const CycleHeroCard({
    super.key,
    required this.dayText,
    required this.phaseText,
    required this.subtitleText,
    required this.progress,
    required this.cycleLength,
    this.periodLength = 5,
    this.lutealStart,
    required this.onEdit,
    this.onLearnMore,
  });

  /// The illustration, when one has been added to the project.
  ///
  /// Prepared by tool/prepare_cycle_image.py. Without it the card draws the
  /// anatomy itself, so nothing about the cycle depends on the file.
  static const String imageAsset = 'assets/cycle_uterus.png';

  /// The day line, already worded by the dashboard -- "Cycle Day 8", or the
  /// reason there is no number yet.
  final String dayText;

  final String phaseText;
  final String subtitleText;

  /// How far through the cycle, 0..1, for the illustration.
  final double progress;

  final int cycleLength;

  /// Days of bleeding, for the illustration's shading only.
  ///
  /// Defaulted rather than required because nothing logs it: the cycle card
  /// leaves the painter's own default in place too, and a required argument
  /// here would only invite a made-up number at every call site.
  final int periodLength;

  /// The first luteal day, for the ring's colours. The dashboard's rule when
  /// null: fourteen days before the end of the cycle.
  final int? lutealStart;

  final VoidCallback onEdit;
  final VoidCallback? onLearnMore;

  /// Splits "Cycle Day 8" so the number can be styled apart from the words.
  ///
  /// Falls back to the whole string where the line has no trailing number --
  /// "Loading...", "Cycle Day: Not Logged" -- rather than guessing at where
  /// to cut it. Kept public because the dashboard tests it.
  static (String, String?) splitTrailingNumber(String text) {
    final match = RegExp(r'^(.*?)(\d+)$').firstMatch(text.trim());
    if (match == null) return (text, null);
    return (match.group(1)!, match.group(2)!);
  }

  static const double _artHeight = 210;

  /// The tracker: how thick it is drawn, and how far outside the picture's
  /// edge it runs. Together they are the margin the picture keeps from the
  /// edge of its box.
  static const double _trackWidth = 12;
  static const double _trackOffset = 8;
  static const double _trackPad = _trackWidth + _trackOffset;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Pale pink rather than white: this is the one card on the page that
        // is the page's subject, and the tint is what says so.
        // Solid: a pale pink mixed from the page colour and the soft pink.
        color: Color.lerp(BlushyColors.background, BlushyColors.secondary, 0.22),
        borderRadius: BorderRadius.circular(20),
        boxShadow: BlushySurface.shadow,
      ),
      padding: BlushySpace.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionHeading("TODAY'S CYCLE"),
              ),
              _EditButton(onTap: onEdit),
            ],
          ),
          const SizedBox(height: BlushySpace.xs),
          // The picture with the tracker round it. The box is the picture's
          // own shape plus the tracker's margin, so the tracker can be drawn
          // outside the picture without being clipped.
          SizedBox(
            height: _artHeight,
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final innerH = _artHeight - _trackPad * 2;
                  var innerW = innerH * cycleOutlineAspect;
                  // Never wider than the card allows; scale the height with
                  // it so the picture keeps its shape.
                  final maxW = constraints.maxWidth - _trackPad * 2;
                  final h = innerW > maxW ? maxW / cycleOutlineAspect : innerH;
                  innerW = h * cycleOutlineAspect;

                  return SizedBox(
                    width: innerW + _trackPad * 2,
                    height: h + _trackPad * 2,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // A soft disc behind the picture, so it sits on
                        // something rather than floating on the gradient.
                        Container(
                          width: h,
                          height: h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: CycleOutlinePainter(
                                progress: progress,
                                cycleLength: cycleLength,
                                periodLength: periodLength,
                                lutealStart: lutealStart ??
                                    (cycleLength - 14).clamp(7, cycleLength),
                                strokeWidth: _trackWidth,
                                offset: _trackOffset,
                                pad: _trackPad,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: innerW,
                          height: h,
                          child: IgnorePointer(
                            child: Image.asset(
                              imageAsset,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              // The whole seam. No file, or a bad one, and
                              // the card draws the anatomy itself -- without
                              // its own trace, because the tracker outside
                              // already marks the day.
                              errorBuilder: (_, _, _) => CustomPaint(
                                painter: CycleAnatomyPainter(
                                  progress: progress,
                                  cycleLength: cycleLength,
                                  periodLength: periodLength,
                                  showCycle: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: BlushySpace.md),
          Text(
            dayText,
            textAlign: TextAlign.center,
            style: BlushyType.display(),
          ),
          const SizedBox(height: BlushySpace.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _Dashes(),
              const SizedBox(width: BlushySpace.md),
              Flexible(
                child: Text(
                  phaseText,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BlushyType.heading(color: BlushyColors.primary),
                ),
              ),
              const SizedBox(width: BlushySpace.md),
              const _Dashes(),
            ],
          ),
          const SizedBox(height: BlushySpace.lg),
          // The note. Sized from the reference, where the text has roughly
          // half the row: on a phone the button took most of it and a
          // three-line note ran to six.
          Container(
            padding: const EdgeInsets.all(BlushySpace.md),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: BlushySpace.control,
                      height: BlushySpace.control,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: BlushyColors.primary.withValues(alpha: 0.10),
                      ),
                      child: const Icon(Icons.calendar_month_rounded,
                          size: 18, color: BlushyColors.primary),
                    ),
                    const SizedBox(width: BlushySpace.md),
                    Expanded(
                      child: Text(
                        subtitleText,
                        style: BlushyType.body(color: BlushyColors.text),
                      ),
                    ),
                  ],
                ),
                // Under the note, the width of it. Beside the note it took
                // half the row and pushed the text into a narrow column.
                if (onLearnMore != null) ...[
                  const SizedBox(height: BlushySpace.md),
                  _LearnMoreButton(onTap: onLearnMore!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The cycle traced round the picture: one lap of its outer edge is one
/// cycle, coloured by phase, with today marked on it.
///
/// The edge comes from [cycleOutlinePoints], generated from the image, and is
/// pushed [offset] pixels outward so the stroke runs beside the sticker's
/// white border rather than over it. It starts at the top and runs clockwise,
/// so day one is twelve o'clock and the marker moves the way a clock hand
/// does. Phases are the same three the legend names, in the same colours,
/// from the same boundaries.
class CycleOutlinePainter extends CustomPainter {
  CycleOutlinePainter({
    required this.progress,
    required this.cycleLength,
    required this.periodLength,
    required this.lutealStart,
    required this.strokeWidth,
    required this.offset,
    required this.pad,
  });

  final double progress;
  final int cycleLength;
  final int periodLength;
  final int lutealStart;

  /// How thick the track is.
  final double strokeWidth;

  /// How far outside the picture's edge the track runs.
  final double offset;

  /// The margin between the picture and the edge of this painter's box.
  final double pad;

  static const Color menstrual = BlushyColors.primary;
  static const Color follicular = BlushyColors.secondary;
  static const Color luteal = BlushyColors.accent;

  /// The outline in this box's pixels, pushed outward by [offset].
  Path _outline(Size size) {
    final image = Rect.fromLTWH(
      pad,
      pad,
      size.width - pad * 2,
      size.height - pad * 2,
    );
    final points = [
      for (final p in cycleOutlinePoints)
        Offset(image.left + p.dx * image.width, image.top + p.dy * image.height),
    ];

    var cx = 0.0;
    var cy = 0.0;
    for (final p in points) {
      cx += p.dx;
      cy += p.dy;
    }
    final centre = Offset(cx / points.length, cy / points.length);

    Offset pushed(Offset p) {
      final d = p - centre;
      final len = d.distance;
      if (len == 0) return p;
      return p + d / len * offset;
    }

    final path = Path()..moveTo(pushed(points.first).dx, pushed(points.first).dy);
    for (final p in points.skip(1)) {
      final q = pushed(p);
      path.lineTo(q.dx, q.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || cycleLength <= 0) return;
    final metrics = _outline(size).computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final total = metric.length;
    if (total <= 0) return;

    double along(int days) => total * days / cycleLength;

    Paint stroke(Color color, {StrokeCap cap = StrokeCap.butt}) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = cap
      ..color = color;

    // The track, faint, all the way round.
    canvas.drawPath(
      metric.extractPath(0, total),
      stroke(Colors.white.withValues(alpha: 0.7), cap: StrokeCap.round),
    );

    // The three phases laid over it, each at a fraction of its colour so the
    // part already passed can be drawn stronger on top.
    final period = periodLength.clamp(1, cycleLength);
    final lut = lutealStart.clamp(period + 1, cycleLength);
    final segments = <(int, int, Color)>[
      (0, period, menstrual),
      (period, lut - 1, follicular),
      (lut - 1, cycleLength, luteal),
    ];
    for (final (from, to, color) in segments) {
      if (to <= from) continue;
      canvas.drawPath(
        metric.extractPath(along(from), along(to)),
        stroke(color.withValues(alpha: 0.28)),
      );
    }

    // What has passed, at full strength, phase by phase.
    final elapsed = total * progress.clamp(0.0, 1.0);
    for (final (from, to, color) in segments) {
      final a = along(from);
      final b = math.min(along(to), elapsed);
      if (b <= a) continue;
      canvas.drawPath(
        metric.extractPath(a, b),
        stroke(color, cap: StrokeCap.round),
      );
    }

    // Today.
    final tangent = metric.getTangentForOffset(elapsed);
    if (tangent == null) return;
    final marker = tangent.position;
    canvas.drawCircle(
      marker,
      strokeWidth * 0.9,
      Paint()
        ..color = BlushyColors.text.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(marker, strokeWidth * 0.85, Paint()..color = Colors.white);
    canvas.drawCircle(
      marker,
      strokeWidth * 0.85,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = BlushyColors.primary,
    );
  }

  @override
  bool shouldRepaint(covariant CycleOutlinePainter old) =>
      old.progress != progress ||
      old.cycleLength != cycleLength ||
      old.periodLength != periodLength ||
      old.lutealStart != lutealStart ||
      old.strokeWidth != strokeWidth ||
      old.offset != offset ||
      old.pad != pad;
}

/// The way to correct the date the whole card is calculated from.
class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: BlushySpace.control,
      height: BlushySpace.control,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: BlushyColors.primary,
        boxShadow: [
          BoxShadow(
            color: BlushyColors.primary.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// Three short dashes, either side of the phase name.
class _Dashes extends StatelessWidget {
  const _Dashes();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Container(
            width: 7,
            height: 2,
            decoration: BoxDecoration(
              color: BlushyColors.primary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ],
    );
  }
}

class _LearnMoreButton extends StatelessWidget {
  const _LearnMoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BlushyColors.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: BlushySpace.tapHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.menu_book_rounded, size: 16, color: Colors.white),
              const SizedBox(width: BlushySpace.sm),
              Text(
                'Learn more',
                style: BlushyType.body(
                  color: Colors.white,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One phase of the cycle, for the legend under the hero.
class CyclePhase {
  const CyclePhase({
    required this.name,
    required this.days,
    required this.color,
    required this.icon,
  });

  final String name;

  /// The day range this phase covers, already worded -- "Days 1-5".
  final String days;

  final Color color;
  final IconData icon;
}

/// The three phases, and where in them today falls.
///
/// The old legend was three coloured dots with names beside them, which said
/// what the colours meant but not what they covered or where you were. This
/// says both.
class PhaseLegendCard extends StatelessWidget {
  const PhaseLegendCard({
    super.key,
    required this.phases,
    required this.activeIndex,
    required this.progress,
  });

  final List<CyclePhase> phases;

  /// Which phase today is in, or -1 where nothing has been logged.
  final int activeIndex;

  /// How far through the whole cycle, 0..1, for the marker on the track.
  final double progress;

  @override
  Widget build(BuildContext context) {
    return BlushySurface(
      child: Column(
        children: [
          // Each label over its own marker on the rail: the first at the
          // start, the middle in the centre, the last at the end. Laid out
          // in equal thirds they were nowhere near the markers.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < phases.length; i++)
                Expanded(
                  child: Align(
                    alignment: i == 0
                        ? Alignment.topLeft
                        : i == phases.length - 1
                            ? Alignment.topRight
                            : Alignment.topCenter,
                    child: _phase(
                      phases[i],
                      i == activeIndex,
                      align: i == 0
                          ? CrossAxisAlignment.start
                          : i == phases.length - 1
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: BlushySpace.md),
          SizedBox(
            height: 14,
            child: CustomPaint(
              size: Size.infinite,
              painter: _PhaseTrackPainter(
                phases: phases,
                progress: progress,
                activeIndex: activeIndex,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _phase(
    CyclePhase phase,
    bool isActive, {
    required CrossAxisAlignment align,
  }) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(phase.icon, size: 13, color: phase.color),
            const SizedBox(width: BlushySpace.xs),
            Flexible(
              child: Text(
                phase.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // The phase you are in is named in its own colour. The other
                // two stay dark, so there is one thing to find rather than
                // three competing for it.
                style: BlushyType.body(
                  color: isActive ? phase.color : BlushyColors.text,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Text(
          phase.days,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BlushyType.caption(),
        ),
      ],
    );
  }
}

/// The dotted rail under the three phase names.
class _PhaseTrackPainter extends CustomPainter {
  _PhaseTrackPainter({
    required this.phases,
    required this.progress,
    required this.activeIndex,
  });

  final List<CyclePhase> phases;
  final double progress;
  final int activeIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || phases.isEmpty) return;
    final y = size.height / 2;
    // The end markers are drawn at the labels' outer edges, so the rail runs
    // the full width and the marker radius is the only inset.
    const inset = 7.0;
    final left = inset;
    final right = size.width - inset;
    final span = right - left;
    if (span <= 0) return;

    // A dotted rail rather than a solid bar: a cycle is counted in days, and
    // dots say "days" where a continuous line says "a proportion".
    const step = 7.0;
    const dot = 1.5;
    for (var x = left; x <= right; x += step) {
      final t = ((x - left) / span).clamp(0.0, 1.0);
      final passed = t <= progress;
      canvas.drawCircle(
        Offset(x, y),
        dot,
        Paint()
          ..color = passed
              ? BlushyColors.primary.withValues(alpha: 0.45)
              : BlushyColors.border,
      );
    }

    // One marker per phase, at the start of its stretch of the rail.
    for (var i = 0; i < phases.length; i++) {
      final t = phases.length == 1 ? 0.0 : i / (phases.length - 1);
      final centre = Offset(left + span * t, y);
      final color = phases[i].color;

      if (i == activeIndex) {
        // The phase you are in is a ring, not a disc: it reads as "here"
        // rather than as another milestone already passed.
        canvas.drawCircle(centre, 7, Paint()..color = Colors.white);
        canvas.drawCircle(
          centre,
          7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = color,
        );
      } else {
        canvas.drawCircle(centre, 5, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PhaseTrackPainter old) =>
      old.progress != progress ||
      old.activeIndex != activeIndex ||
      old.phases != phases;
}

/// The one way in to logging, as a banner rather than a button.
///
/// It is the page's primary action and the only entry point to the symptoms
/// sheet, so it is given the width of the page and the brand colour instead of
/// sitting in a card with everything else.
class LogSymptomsBanner extends StatelessWidget {
  const LogSymptomsBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: BlushyColors.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: BlushyColors.primary.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: BlushySpace.card,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_note_rounded,
                      size: 26, color: BlushyColors.primary),
                ),
                const SizedBox(width: BlushySpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: BlushyType.heading(
                          color: Colors.white,
                          weight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: BlushyType.caption(
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: BlushySpace.sm),
                Container(
                  width: BlushySpace.control,
                  height: BlushySpace.control,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(Icons.chevron_right_rounded,
                      size: 22, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One line of today's log.
class LoggedSignal {
  const LoggedSignal({
    required this.label,
    required this.value,
    required this.logged,
    required this.color,
    required this.icon,
    this.onTap,
  });

  final String label;

  /// What was logged, already worded by the dashboard.
  final String value;

  /// Whether [value] is a reading or the placeholder for an empty day. The
  /// dashboard knows the difference; the row must not have to infer it from
  /// the wording.
  final bool logged;

  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
}

/// Today's log, one row per signal.
class LoggedSignalsCard extends StatelessWidget {
  const LoggedSignalsCard({super.key, required this.signals, this.footer});

  final List<LoggedSignal> signals;

  /// What sits under the rows, the width of the card: the way to the full
  /// log. Optional, so the card can be used without one.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return BlushySurface(
      padding: const EdgeInsets.symmetric(vertical: BlushySpace.xs),
      child: Column(
        children: [
          for (var i = 0; i < signals.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: BlushySpace.lg),
                child: Divider(height: 1, thickness: 1, color: BlushyColors.border),
              ),
            _SignalRow(signal: signals[i]),
          ],
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BlushySpace.md, BlushySpace.sm, BlushySpace.md, BlushySpace.sm),
              child: footer,
            ),
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.signal});

  final LoggedSignal signal;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: signal.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BlushySpace.lg,
            vertical: BlushySpace.lg,
          ),
          child: Row(
            children: [
              Container(
                width: BlushySpace.tile,
                height: BlushySpace.tile,
                decoration: BoxDecoration(
                  color: signal.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(signal.icon, size: BlushySpace.iconTile, color: signal.color),
              ),
              const SizedBox(width: BlushySpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(signal.label, style: BlushyType.heading()),
                    Text(
                      signal.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // The row's own colour when there is a reading, grey
                      // when there is not: an unlogged row must not look
                      // like a logged one at a glance.
                      style: BlushyType.body(
                        color: signal.logged
                            ? signal.color
                            : BlushyColors.secondaryText,
                        weight:
                            signal.logged ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: BlushySpace.iconChevron, color: BlushyColors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}
