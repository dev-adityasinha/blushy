import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The top of Partner Mode: who you are connected to, what is actually known
/// today, and the state of the sharing between you.
///
/// Lifted out of the 1,500-line screen rather than added to it. Each widget
/// takes exactly what it needs, which is also what makes it possible to say at
/// a glance that none of them can reach data the permission matrix did not
/// send.
///
/// Every value here is real or absent. There is no placeholder cycle day, no
/// invented mood, and no relationship duration where the connection payload
/// does not carry one -- a partner acting on a number the app made up is worse
/// than a partner who was told nothing.

/// Stage 1 tokens, as STAGE1_DESIGN_RULES.md names them.
const Color kPmCrimson = Color(0xFFDD0D22);
const Color kPmCardBorder = Color(0xFFEFE8E0);
const Color kPmCharcoal = Color(0xFF221510);
const Color kPmMuted = Color(0xFF7A6B72);
const Color kPmHairline = Color(0xFFF3EEE9);

/// 01 -- who you are connected to, and the state of that connection.
class PartnerEditorialHeader extends StatelessWidget {
  const PartnerEditorialHeader({
    super.key,
    required this.partnerName,
    required this.cycleInfo,
    required this.connectedSince,
    required this.live,
    this.eyebrow = 'SHARED HORIZONS',
    this.verb = 'Connected with',
    this.stageFacts = const <String>[],
  });

  final String? partnerName;
  final Map<String, dynamic>? cycleInfo;

  /// Stage wording, where her stage is known. The defaults are the
  /// stage-agnostic version, which is also what an unshared stage gets.
  final String eyebrow;
  final String verb;

  /// Facts the stage cares about -- a pregnancy week, a recovery week, an
  /// open fertile window. Supplied by the caller from real values only; an
  /// empty list falls back to the cycle day and sync state below.
  final List<String> stageFacts;

  /// Days since the connection was accepted, or null when the payload does
  /// not say. Never guessed.
  final int? connectedSince;

  /// Whether the permission-filtered feed answered, so "live" is a fact
  /// rather than decoration.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final connected = partnerName != null && partnerName!.trim().isNotEmpty;

    // Joined from whatever is actually known, so a connection with no cycle
    // shared simply says less rather than showing a gap where a number goes.
    final parts = <String>[
      // The stage speaks first where it has something to say -- a pregnancy
      // week matters more than a cycle day -- and the cycle day stands in
      // where it does not.
      ...stageFacts,
      if (stageFacts.isEmpty && cycleInfo?['currentCycleDay'] != null)
        'Day ${cycleInfo!['currentCycleDay']}',
      if (live) 'Live sync active',
      if (connectedSince != null)
        'Together for $connectedSince ${connectedSince == 1 ? 'day' : 'days'}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            eyebrow,
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: kPmCrimson,
              letterSpacing: 1.1,
            ),
          ),
        ),
        if (connected)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$verb '),
                TextSpan(
                  text: partnerName,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: kPmCrimson,
                  ),
                ),
              ],
            ),
            style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: kPmCharcoal,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          )
        else
          Text(
            'Not connected yet.',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: kPmCharcoal,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
        const SizedBox(height: 6),
        Text(
          parts.isNotEmpty
              ? parts.join('  ·  ')
              : connected
                  ? 'Nothing personal is being shared yet.'
                  : 'Send an invite, or ask her for her partner code.',
          style: GoogleFonts.manrope(
            fontSize: 12.5,
            color: kPmMuted,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// 02 -- four signals, unboxed. Each is real, or says plainly that it is not.
class PartnerSignalRow extends StatelessWidget {
  const PartnerSignalRow({
    super.key,
    required this.cycleInfo,
    required this.moodData,
    required this.permitted,
    required this.sharingActive,
    this.badges,
  });

  final Map<String, dynamic>? cycleInfo;
  final Map<String, dynamic>? moodData;
  final Map<String, dynamic> permitted;
  final bool sharingActive;

  /// Stage-specific signals, where her stage is known. Null keeps the
  /// stage-agnostic four below, which is what an unshared stage gets.
  final List<PartnerSignalBadge>? badges;

  /// Energy, only where she has actually logged it.
  String? get _energy {
    for (final key in ['energy', 'energyLevel', 'energy_level']) {
      final value = permitted[key] ?? moodData?[key];
      if (value == null) continue;
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) {
        return value >= 7 ? 'High' : (value >= 4 ? 'Medium' : 'Low');
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final day = cycleInfo?['currentCycleDay'];
    final phase = cycleInfo?['phase']?.toString();
    final mood = moodData?['mood']?.toString();
    final energy = _energy;

    final signals = badges ??
        <Widget>[
          PartnerSignalBadge(
            icon: Icons.water_drop_rounded,
            colour: const Color(0xFF2563EB),
            tint: const Color(0xFFDBEAFE),
            label: day != null ? 'DAY $day' : 'CYCLE',
            // "Private" rather than "no data": she has not shared it, which is a
            // decision of hers, not a gap in the app.
            value: phase ?? (day != null ? 'Shared' : 'Private'),
          ),
          PartnerSignalBadge(
            icon: Icons.bolt_rounded,
            colour: const Color(0xFF0D9488),
            tint: const Color(0xFFCCFBF1),
            label: 'ENERGY',
            value: energy ?? 'Not logged',
          ),
          PartnerSignalBadge(
            icon: Icons.favorite_rounded,
            colour: const Color(0xFFF72585),
            tint: const Color(0xFFFFE5F0),
            label: 'MOOD',
            value: mood ?? 'Private',
          ),
          PartnerSignalBadge(
            icon: Icons.lock_person_rounded,
            colour: const Color(0xFF7209B7),
            tint: const Color(0xFFF3E8FF),
            label: sharingActive ? 'SHARING' : 'PRIVATE',
            value: sharingActive ? 'Active' : 'Paused',
          ),
        ];

    // Scrolls rather than squeezing: four badges with two-word values do not
    // fit a narrow phone, and a Row would clip the last one.
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: signals.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) => signals[index],
      ),
    );
  }
}

class PartnerSignalBadge extends StatelessWidget {
  const PartnerSignalBadge({
    super.key,
    required this.icon,
    required this.colour,
    required this.tint,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color colour;
  final Color tint;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, $value',
      excludeSemantics: true,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(icon, size: 23, color: colour),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: kPmMuted,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: kPmCharcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 03 -- the state of the shared space, and the way into the sharing settings.
class ConnectionSanctuary extends StatelessWidget {
  const ConnectionSanctuary({
    super.key,
    required this.sharing,
    required this.onManage,
  });

  final bool sharing;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
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
            'YOUR SHARED SPACE',
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: kPmCrimson,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: sharing ? const Color(0xFF0D9488) : kPmMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sharing ? 'Connected' : 'Connected, sharing paused',
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: kPmCharcoal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            sharing
                ? 'Sharing is active.'
                : 'Nothing personal is being shared right now.',
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              color: kPmMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: kPmHairline),
          const SizedBox(height: 12),
          InkWell(
            onTap: onManage,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'What she shares with you',
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: kPmCharcoal,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: kPmMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
