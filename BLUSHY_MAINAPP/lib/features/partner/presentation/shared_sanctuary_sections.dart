import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/api_partner_service.dart';
import '../../../shared/docsy_avatar.dart';

// ============================================================================
// STAGE 1 DESIGN SYSTEM TOKENS (Shared Sanctuary)
// Strictly follows STAGE1_DESIGN_RULES.md & AGENTS.md
// Enhanced with Vivid Saturated Accents, Radiant Gradients & Big Icons
// ============================================================================
const Color kSanctuaryCanvas = Color(0xFFFAF7F2);
const Color kSanctuaryCard = Color(0xFFFFFFFF);
const Color kSanctuaryBorder = Color(0xFFEFE8E0);
const Color kSanctuaryCrimson = Color(0xFFDD0D22);
const Color kSanctuaryCharcoal = Color(0xFF221510);
const Color kSanctuaryMuted = Color(0xFF7A6B72);
const Color kSanctuaryDivider = Color(0xFFF3EEE9);

// Semantic Saturated Accents & Gradient Pairs
const Color kCobalt = Color(0xFF2563EB);
const Color kCobaltDark = Color(0xFF1D4ED8);
const Color kCobaltTint = Color(0xFFDBEAFE);

const Color kTeal = Color(0xFF0D9488);
const Color kTealDark = Color(0xFF0F766E);
const Color kTealTint = Color(0xFFCCFBF1);

const Color kMagenta = Color(0xFFF72585);
const Color kMagentaDark = Color(0xFFB5179E);
const Color kMagentaTint = Color(0xFFFFE5F0);

const Color kPurple = Color(0xFF7209B7);
const Color kPurpleDark = Color(0xFF560BAD);
const Color kPurpleTint = Color(0xFFF3E8FF);

const Color kAmber = Color(0xFFD97706);
const Color kAmberDark = Color(0xFFB45309);
const Color kAmberTint = Color(0xFFFEF3C7);

const Color kCoral = Color(0xFFFF4A00);
const Color kCoralDark = Color(0xFFCC3B00);
const Color kCoralTint = Color(0xFFFFEBE0);

const Color kCrimsonTint = Color(0xFFFFECEB);
const Color kEmerald = Color(0xFF059669);
const Color kEmeraldTint = Color(0xFFECFDF5);

// ============================================================================
// 01 — UNBOXED EDITORIAL HEADER (WITH COUPLE MONOGRAMS & LIVE SYNC BADGE)
// ============================================================================
class SharedSanctuaryHeader extends StatelessWidget {
  const SharedSanctuaryHeader({
    super.key,
    required this.hasConnection,
    this.partnerName,
    this.durationText,
    required this.isPrivateSpaceActive,
    required this.onInvite,
    required this.onManageConnection,
  });

  final bool hasConnection;
  final String? partnerName;
  final String? durationText;
  final bool isPrivateSpaceActive;
  final VoidCallback onInvite;
  final VoidCallback onManageConnection;

  @override
  Widget build(BuildContext context) {
    if (!hasConnection) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded, size: 14, color: kSanctuaryCrimson),
              const SizedBox(width: 6),
              Text(
                'YOUR SHARED SPACE',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: kSanctuaryCrimson,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'A little space for the two of you.',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              color: kSanctuaryCharcoal,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invite someone you trust to create a private space for messages, memories, little surprises and the things you choose to share.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: kSanctuaryMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onInvite,
            style: ElevatedButton.styleFrom(
              backgroundColor: kSanctuaryCrimson,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 3,
              shadowColor: kSanctuaryCrimson.withValues(alpha: 0.35),
            ),
            icon: const Icon(Icons.favorite_rounded, size: 18, color: Colors.white),
            label: Text(
              'Invite Partner',
              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }

    final pName = partnerName != null && partnerName!.trim().isNotEmpty
        ? partnerName!.trim()
        : 'Your Partner';
    final partnerInitial = pName.isNotEmpty ? pName[0].toUpperCase() : 'P';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_rounded, size: 13, color: kSanctuaryCrimson),
                  const SizedBox(width: 5),
                  Text(
                    'SHARED SANCTUARY',
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: kSanctuaryCrimson,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'You & '),
                    TextSpan(
                      text: pName,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: kSanctuaryCrimson,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: kSanctuaryCharcoal,
                  height: 1.15,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isPrivateSpaceActive ? kPurpleTint : kEmeraldTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (isPrivateSpaceActive ? kPurple : kEmerald).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isPrivateSpaceActive ? kPurple : kEmerald,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isPrivateSpaceActive ? kPurple : kEmerald).withValues(alpha: 0.55),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      isPrivateSpaceActive
                          ? 'PRIVATE SPACE ACTIVE'
                          : ((durationText != null && durationText!.isNotEmpty)
                              ? '$durationText  ·  SYNCED'
                              : 'CONNECTED'),
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isPrivateSpaceActive ? kPurple : kEmerald,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Couple Monograms + Manage Settings Button
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 58,
              height: 38,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kMagenta,
                        boxShadow: [
                          BoxShadow(
                            color: kMagenta.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          'Y',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 22,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kCobalt,
                        boxShadow: [
                          BoxShadow(
                            color: kCobalt.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          partnerInitial,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onManageConnection,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kSanctuaryCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: kSanctuaryBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.tune_rounded, color: kSanctuaryCharcoal, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// 02 — UNBOXED DYNAMIC SIGNAL RAIL (TODAY, TOGETHER)
// ============================================================================
class TodayTogetherSignalRail extends StatelessWidget {
  const TodayTogetherSignalRail({
    super.key,
    required this.signals,
  });

  final List<SignalBadgeSpec> signals;

  @override
  Widget build(BuildContext context) {
    if (signals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TODAY, TOGETHER',
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: kSanctuaryCrimson,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kTealTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flash_on_rounded, size: 11, color: kTeal),
                  const SizedBox(width: 3),
                  Text(
                    'LIVE SIGNALS',
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: kTeal,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: signals.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final spec = signals[index];
              return InkWell(
                onTap: spec.onTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 86,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: kSanctuaryCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: spec.colour.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: spec.colour.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: spec.colour,
                          boxShadow: [
                            BoxShadow(
                              color: spec.colour.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(spec.icon, size: 24, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        spec.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: spec.colour,
                          letterSpacing: 0.7,
                        ),
                      ),
                      Text(
                        spec.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: kSanctuaryCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class SignalBadgeSpec {
  const SignalBadgeSpec({
    required this.icon,
    required this.colour,
    required this.tint,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final Color colour;
  final Color tint;
  final String label;
  final String value;
  final VoidCallback? onTap;
}

// ============================================================================
// 03 — PRIMARY "RIGHT NOW" HERO EXPERIENCE (BIG ICONS & BRIGHT GRADIENTS)
// ============================================================================
enum RightNowEventType {
  message,
  bloom,
  letter,
  memory,
  lowData,
}

class RightNowCard extends StatelessWidget {
  const RightNowCard({
    super.key,
    required this.type,
    required this.partnerName,
    this.headline,
    this.bodyText,
    this.timeDisplay,
    this.primaryCtaText,
    this.secondaryCtaText,
    this.onPrimaryTap,
    this.onSecondaryTap,
  });

  final RightNowEventType type;
  final String partnerName;
  final String? headline;
  final String? bodyText;
  final String? timeDisplay;
  final String? primaryCtaText;
  final String? secondaryCtaText;
  final VoidCallback? onPrimaryTap;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    // Determine Theme Configuration for Event Type
    final (
      Color accentColor,
      Color accentTint,
      IconData heroIcon,
      IconData badgeIcon,
    ) = switch (type) {
      RightNowEventType.message => (
          kCobalt,
          kCobaltTint,
          Icons.chat_bubble_rounded,
          Icons.sms_rounded,
        ),
      RightNowEventType.bloom => (
          kSanctuaryCrimson,
          kCrimsonTint,
          Icons.local_florist_rounded,
          Icons.favorite_rounded,
        ),
      RightNowEventType.letter => (
          kCoral,
          kCoralTint,
          Icons.mark_email_unread_rounded,
          Icons.mail_lock_rounded,
        ),
      RightNowEventType.memory => (
          kMagenta,
          kMagentaTint,
          Icons.auto_stories_rounded,
          Icons.bookmark_rounded,
        ),
      RightNowEventType.lowData => (
          kTeal,
          kTealTint,
          Icons.favorite_border_rounded,
          Icons.sync_rounded,
        ),
    };

    final cleanPrimaryCta = (primaryCtaText ?? 'Open')
        .replaceAll('→', '')
        .replaceAll('>', '')
        .trim();

    if (type == RightNowEventType.lowData) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSanctuaryCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accentTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badgeIcon, size: 12, color: accentColor),
                  const SizedBox(width: 5),
                  Text(
                    'RIGHT NOW',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: accentColor,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(heroIcon, size: 28, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nothing new — and that\'s okay.',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: kSanctuaryCharcoal,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your shared space is here whenever you want it.',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: kSanctuaryMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: onPrimaryTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: kSanctuaryCrimson,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: kSanctuaryCrimson.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cleanPrimaryCta,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSanctuaryCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: accentColor),
                    const SizedBox(width: 5),
                    Text(
                      headline ?? 'RIGHT NOW',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (timeDisplay != null && timeDisplay!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kSanctuaryCanvas,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kSanctuaryBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 11, color: kSanctuaryMuted),
                      const SizedBox(width: 4),
                      Text(
                        timeDisplay!,
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: kSanctuaryMuted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: accentColor,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(heroIcon, size: 28, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  bodyText ?? '',
                  style: type == RightNowEventType.message
                      ? GoogleFonts.cormorantGaramond(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: kSanctuaryCharcoal,
                          height: 1.25,
                        )
                      : GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: kSanctuaryCharcoal,
                          height: 1.2,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              InkWell(
                onTap: onPrimaryTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  decoration: BoxDecoration(
                    color: kSanctuaryCrimson,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: kSanctuaryCrimson.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cleanPrimaryCta,
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                    ],
                  ),
                ),
              ),
              if (secondaryCtaText != null) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: onSecondaryTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: kSanctuaryCanvas,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kSanctuaryBorder),
                    ),
                    child: Text(
                      secondaryCtaText!,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kSanctuaryCharcoal,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 04 — MAKE A LITTLE MOMENT (BIG ICONS & BRIGHT SATURATED ACTION CARDS)
// ============================================================================
class MakeALittleMomentRail extends StatelessWidget {
  const MakeALittleMomentRail({
    super.key,
    required this.onSendBloom,
    required this.onWriteLetter,
    required this.onLeaveMessage,
    required this.onPlanSomething,
  });

  final VoidCallback onSendBloom;
  final VoidCallback onWriteLetter;
  final VoidCallback onLeaveMessage;
  final VoidCallback onPlanSomething;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        label: 'Send a Bloom',
        sublabel: 'Virtual petals',
        icon: Icons.local_florist_rounded,
        tint: kCrimsonTint,
        accent: kSanctuaryCrimson,
        onTap: onSendBloom,
      ),
      (
        label: 'Write a Letter',
        sublabel: 'Time capsule',
        icon: Icons.mark_email_unread_rounded,
        tint: kMagentaTint,
        accent: kMagenta,
        onTap: onWriteLetter,
      ),
      (
        label: 'Leave a Note',
        sublabel: 'Private chat',
        icon: Icons.chat_bubble_rounded,
        tint: kCobaltTint,
        accent: kCobalt,
        onTap: onLeaveMessage,
      ),
      (
        label: 'Plan Together',
        sublabel: 'Couple quest',
        icon: Icons.event_note_rounded,
        tint: kAmberTint,
        accent: kAmber,
        onTap: onPlanSomething,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MAKE A LITTLE MOMENT',
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: kSanctuaryCrimson,
              ),
            ),
            Text(
              'SHARED SURPRISES',
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: kSanctuaryMuted,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: actions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final a = actions[index];
              return InkWell(
                onTap: a.onTap,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 136,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kSanctuaryCard,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: a.accent.withValues(alpha: 0.25), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: a.accent.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: a.accent,
                          boxShadow: [
                            BoxShadow(
                              color: a.accent.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(a.icon, size: 24, color: Colors.white),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: kSanctuaryCharcoal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a.sublabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: a.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 05 — YOUR STORY (LIVING MEMORY BOOK PREVIEW WITH BIG ICONS)
// ============================================================================
class YourStoryCard extends StatelessWidget {
  const YourStoryCard({
    super.key,
    required this.memoryCount,
    this.latestMemoryTitle,
    this.latestMemoryDate,
    required this.onOpenMemoryBook,
    required this.onStartMemory,
  });

  final int memoryCount;
  final String? latestMemoryTitle;
  final String? latestMemoryDate;
  final VoidCallback onOpenMemoryBook;
  final VoidCallback onStartMemory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'YOUR STORY',
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: kSanctuaryCrimson,
              ),
            ),
            if (memoryCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kEmeraldTint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kEmerald.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmark_added_rounded, size: 11, color: kEmerald),
                    const SizedBox(width: 4),
                    Text(
                      memoryCount == 1 ? '1 MEMORY KEPT' : '$memoryCount MEMORIES KEPT',
                      style: GoogleFonts.manrope(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: kEmerald,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'The moments you\'ve kept.',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: kSanctuaryCharcoal,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kSanctuaryCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: kMagenta.withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: kMagenta.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: memoryCount > 0
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: kMagenta,
                            boxShadow: [
                              BoxShadow(
                                color: kMagenta.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.auto_stories_rounded, size: 26, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                latestMemoryTitle ?? 'Shared Moment',
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: kSanctuaryCharcoal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (latestMemoryDate != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.event_note_rounded, size: 12, color: kSanctuaryMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      latestMemoryDate!,
                                      style: GoogleFonts.manrope(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: kSanctuaryMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: onOpenMemoryBook,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: kSanctuaryCrimson,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: kSanctuaryCrimson.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View your story',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: kMagenta,
                            boxShadow: [
                              BoxShadow(
                                color: kMagenta.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.collections_bookmark_rounded, size: 26, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your story is just beginning.',
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: kSanctuaryCharcoal,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'The moments you keep will live here.',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: kSanctuaryMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: onStartMemory,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: kSanctuaryCrimson,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Start a memory',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                          ],
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

// ============================================================================
// 06 — LITTLE THINGS (LETTERS & BLOOMS WITH BIG ICONS & BRIGHT GRADIENTS)
// ============================================================================
class LittleThingsCards extends StatelessWidget {
  const LittleThingsCards({
    super.key,
    required this.lettersCount,
    required this.sealedLettersCount,
    required this.bloomsCount,
    required this.onOpenLetters,
    required this.onOpenBouquet,
  });

  final int lettersCount;
  final int sealedLettersCount;
  final int bloomsCount;
  final VoidCallback onOpenLetters;
  final VoidCallback onOpenBouquet;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LITTLE THINGS',
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: kSanctuaryCrimson,
              ),
            ),
            Text(
              'VAULT & PETALS',
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: kSanctuaryMuted,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpenLetters,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kSanctuaryCard,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: kCoral.withValues(alpha: 0.25), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: kCoral.withValues(alpha: 0.1),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: kCoral,
                          boxShadow: [
                            BoxShadow(
                              color: kCoral.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.mark_email_read_rounded, size: 24, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'LETTERS',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: kCoral,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sealedLettersCount > 0
                            ? '$sealedLettersCount sealed'
                            : (lettersCount > 0 ? '$lettersCount written' : 'No letters yet'),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: kSanctuaryCharcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: onOpenBouquet,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kSanctuaryCard,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: kTeal.withValues(alpha: 0.25), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: kTeal.withValues(alpha: 0.1),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: kTeal,
                          boxShadow: [
                            BoxShadow(
                              color: kTeal.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.local_florist_rounded, size: 24, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'BLOOMS',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: kTeal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bloomsCount > 0 ? '$bloomsCount blooming' : 'Send a flower',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: kSanctuaryCharcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// 07 — DO SOMETHING TOGETHER (CONTEXTUAL ACTIVITY WITH BIG ICONS)
// ============================================================================
class DoSomethingTogetherCard extends StatelessWidget {
  const DoSomethingTogetherCard({
    super.key,
    required this.activity,
    required this.onAction,
    required this.onViewAll,
  });

  final SharedActivity? activity;
  final VoidCallback onAction;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final title = activity?.title.isNotEmpty == true
        ? activity!.title
        : 'Make dinner together. No phones. 30 minutes.';
    final desc = activity?.description.isNotEmpty == true
        ? activity!.description
        : 'A quiet, unhurried evening just for the two of you.';
    final isInProg = activity?.isInProgress == true;
    final isComp = activity?.isCompleted == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DO SOMETHING TOGETHER',
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: kSanctuaryCrimson,
              ),
            ),
            GestureDetector(
              onTap: onViewAll,
              child: Text(
                'All couple ideas',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: kSanctuaryCrimson,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kSanctuaryCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: kAmber.withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: kAmber.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kAmberTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.explore_rounded, size: 12, color: kAmber),
                    const SizedBox(width: 5),
                    Text(
                      'TONIGHT\'S LITTLE IDEA',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: kAmber,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: kAmber,
                      boxShadow: [
                        BoxShadow(
                          color: kAmber.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isComp ? Icons.check_circle_rounded : Icons.favorite_rounded,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: kSanctuaryCharcoal,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: kSanctuaryMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isComp ? kTeal : kSanctuaryCrimson,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: (isComp ? kTeal : kSanctuaryCrimson).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isComp
                            ? 'Completed together'
                            : (isInProg ? 'In progress · Finish' : 'I\'m in'),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isComp ? Icons.done_all_rounded : Icons.arrow_forward_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ],
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

// ============================================================================
// 08 — A LITTLE HELP? (DOCSY AI WITH BIG VIBRANT ICON)
// ============================================================================
class ALittleHelpCard extends StatelessWidget {
  const ALittleHelpCard({
    super.key,
    required this.dynamicPrompt,
    required this.onAskDocsy,
  });

  final String dynamicPrompt;
  final VoidCallback onAskDocsy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'A LITTLE HELP?',
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: kSanctuaryCrimson,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kPurpleTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DocsyIcon(size: 13, color: kPurple),
                  const SizedBox(width: 4),
                  Text(
                    'AI GUIDE',
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: kPurple,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Ask Docsy',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: kSanctuaryCharcoal,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kSanctuaryCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: kPurple.withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: kPurple.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: kPurple,
                      boxShadow: [
                        BoxShadow(
                          color: kPurple.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: DocsyAvatar(
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      dynamicPrompt,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: kSanctuaryCharcoal,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: onAskDocsy,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: kSanctuaryCrimson,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: kSanctuaryCrimson.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Talk to Docsy',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.white),
                    ],
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

// ============================================================================
// 09 — MANAGE CONNECTION FOOTER
// ============================================================================
class ManageConnectionFooter extends StatelessWidget {
  const ManageConnectionFooter({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: kSanctuaryCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kSanctuaryBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kCrimsonTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Icon(Icons.shield_outlined, size: 22, color: kSanctuaryCrimson),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage your connection',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kSanctuaryCharcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'You choose what becomes part of your shared space.',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: kSanctuaryMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: kSanctuaryMuted),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 10 — UNPAIRED ASPIRATIONAL PREVIEW (BIG ICONS & VIBRANT GRADIENTS)
// ============================================================================
class UnpairedAspirationalExperience extends StatelessWidget {
  const UnpairedAspirationalExperience({
    super.key,
    required this.onInvite,
  });

  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final previews = [
      (
        icon: Icons.local_florist_rounded,
        accent: kTeal,
        title: 'Blooms & Postcards',
        desc: 'Send digital flower blooms and sweet postcards throughout the day.',
      ),
      (
        icon: Icons.mark_email_unread_rounded,
        accent: kMagenta,
        title: 'Time Capsule Letters',
        desc: 'Leave sealed letters for anniversaries, milestones, and quiet days.',
      ),
      (
        icon: Icons.auto_stories_rounded,
        accent: kCobalt,
        title: 'Living Memory Book',
        desc: 'A living scrapbook of memories and challenges you experience together.',
      ),
      (
        icon: Icons.shield_outlined,
        accent: kPurple,
        title: 'Consent-First Sharing',
        desc: 'You have complete control over what is shared and can take private space anytime.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHAT YOU\'LL HAVE TOGETHER',
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: kSanctuaryCrimson,
          ),
        ),
        const SizedBox(height: 14),
        ...previews.map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSanctuaryCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.accent.withValues(alpha: 0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: p.accent.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: p.accent,
                    boxShadow: [
                      BoxShadow(
                        color: p.accent.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(p.icon, size: 24, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        style: GoogleFonts.manrope(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: kSanctuaryCharcoal,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        p.desc,
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          color: kSanctuaryMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: onInvite,
            style: ElevatedButton.styleFrom(
              backgroundColor: kSanctuaryCrimson,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: kSanctuaryCrimson.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            icon: const Icon(Icons.favorite_rounded, size: 20, color: Colors.white),
            label: Text(
              'Invite Your Partner',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
