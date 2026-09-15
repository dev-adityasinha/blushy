import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'partner_home_sections.dart'
    show kPmCrimson, kPmCardBorder, kPmCharcoal, kPmMuted, kPmHairline;

/// What her body may be navigating today, and a way to ask about it.
///
/// The care this needs is in the wording. A partner reading "her estrogen is
/// high, so she is energetic" learns to treat her as a phase rather than a
/// person, and is then wrong about her on the days she does not match the
/// chart. Everything here is hedged because the hedge is true: a phase is a
/// tendency across many people, not a fact about one.
///
/// Nothing is generated from nothing. With no cycle shared, the card says so
/// and offers the things that do not need her data.
class CycleHarmonyCard extends StatelessWidget {
  const CycleHarmonyCard({
    super.key,
    required this.partnerName,
    required this.cycleInfo,
    required this.onAskDocsy,
  });

  final String partnerName;
  final Map<String, dynamic>? cycleInfo;
  final VoidCallback onAskDocsy;

  /// What is generally said about this part of a cycle, phrased as a tendency.
  ///
  /// Static education, deliberately: it is not derived from her data beyond
  /// the phase, and presenting it as a reading of her would be a claim the app
  /// cannot support.
  static String? noteFor(String? phase) {
    switch (phase?.toLowerCase().trim()) {
      case 'menstrual':
        return 'Some people feel lower energy and want more rest during a '
            'period, and some feel relief once it starts. Warmth, fewer '
            'demands and not having to explain usually help either way.';
      case 'follicular':
        return 'Energy often builds over the days after a period, though '
            'everyone runs on their own clock. It can be a good stretch for '
            'plans, if she is up for them.';
      case 'ovulation':
      case 'ovulatory':
        return 'Some people feel most sociable and clear-headed around now. '
            'Others notice cramping or tenderness instead -- both are common.';
      case 'luteal':
        return 'The days before a period can bring lower patience, poorer '
            'sleep or a heavier mood for some people, and nothing at all for '
            'others. Asking beats assuming.';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = cycleInfo?['phase']?.toString();
    final day = cycleInfo?['currentCycleDay'];
    final note = noteFor(phase);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPmCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CYCLE HARMONY',
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: kPmCrimson,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            note != null
                ? 'What her body may be navigating today'
                : 'Building your shared rhythm',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: kPmCharcoal,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          if (note != null) ...[
            if (day != null || phase != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  [
                    if (day != null) 'Day $day',
                    ?phase,
                  ].join('  ·  '),
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kPmMuted,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            Text(
              note,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                color: kPmCharcoal,
                height: 1.55,
              ),
            ),
          ] else
            Text(
              'Once $partnerName shares more with you, Blushy can help you '
              'understand how to show up for her. Until then, asking is the '
              'best data there is.',
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                color: kPmMuted,
                height: 1.55,
              ),
            ),
          const SizedBox(height: 14),
          Container(height: 1, color: kPmHairline),
          const SizedBox(height: 12),
          // The way into the AI that already exists, rather than a second one.
          InkWell(
            onTap: onAskDocsy,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ask Docsy how to support her today...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        color: kPmMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: kPmCrimson,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Ask',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small things that might make her day easier, as one card rather than four.
///
/// The actions come from the server's own care suggestions where it sent any.
/// Where it did not, the fallbacks are plainly general -- they are the things
/// that help most people most days, not a reading of her.
class SupportActionsCard extends StatelessWidget {
  const SupportActionsCard({
    super.key,
    required this.actions,
    required this.completedIds,
    required this.onToggle,
  });

  /// Each: {'id', 'title', 'description', 'category'}.
  final List<Map<String, dynamic>> actions;
  final Set<String> completedIds;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final done = actions
        .where((a) => completedIds.contains(a['id']?.toString()))
        .length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPmCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "TODAY'S SUPPORT",
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: kPmCrimson,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Text(
                '$done / ${actions.length} completed',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kPmMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Small actions that could make her day easier',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: kPmCharcoal,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: actions.isEmpty ? 0 : done / actions.length,
              minHeight: 4,
              backgroundColor: kPmHairline,
              valueColor: const AlwaysStoppedAnimation(kPmCrimson),
            ),
          ),
          const SizedBox(height: 4),
          for (final action in actions)
            _SupportRow(
              action: action,
              done: completedIds.contains(action['id']?.toString()),
              onToggle: () => onToggle(action['id']?.toString() ?? ''),
            ),
        ],
      ),
    );
  }
}

class _SupportRow extends StatelessWidget {
  const _SupportRow({
    required this.action,
    required this.done,
    required this.onToggle,
  });

  final Map<String, dynamic> action;
  final bool done;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final title = action['title']?.toString() ?? '';
    final description = action['description']?.toString();
    final category = action['category']?.toString();

    return Semantics(
      button: true,
      checked: done,
      label: title,
      excludeSemantics: true,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 21,
                color: done ? kPmCrimson : kPmMuted,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category != null && category.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          category.toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: kPmMuted,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: done ? kPmMuted : kPmCharcoal,
                        decoration:
                            done ? TextDecoration.lineThrough : null,
                        decorationColor: kPmMuted,
                      ),
                    ),
                    if (description != null && description.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          description,
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            color: done
                                ? kPmMuted.withValues(alpha: 0.6)
                                : kPmMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
