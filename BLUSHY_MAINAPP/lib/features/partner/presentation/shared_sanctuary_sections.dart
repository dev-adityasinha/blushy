import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/api_partner_service.dart';

// ============================================================================
// STAGE 1 DESIGN SYSTEM TOKENS (Shared Sanctuary)
// Strictly follows STAGE1_DESIGN_RULES.md & AGENTS.md
// ============================================================================
const Color kSanctuaryCanvas = Color(0xFFFAF7F2);
const Color kSanctuaryCard = Color(0xFFFFFFFF);
const Color kSanctuaryBorder = Color(0xFFEFE8E0);
const Color kSanctuaryCrimson = Color(0xFFDD0D22);
const Color kSanctuaryCharcoal = Color(0xFF221510);
const Color kSanctuaryMuted = Color(0xFF7A6B72);
const Color kSanctuaryDivider = Color(0xFFF3EEE9);

// Semantic Accent Badge Pairs (Hue + 10-12% Soft Tint)
const Color kCobalt = Color(0xFF2563EB);
const Color kCobaltTint = Color(0xFFDBEAFE);
const Color kTeal = Color(0xFF0D9488);
const Color kTealTint = Color(0xFFCCFBF1);
const Color kMagenta = Color(0xFFF72585);
const Color kMagentaTint = Color(0xFFFFE5F0);
const Color kPurple = Color(0xFF7209B7);
const Color kPurpleTint = Color(0xFFF3E8FF);
const Color kAmber = Color(0xFFD97706);
const Color kAmberTint = Color(0xFFFEF3C7);
const Color kCoral = Color(0xFFFF4A00);
const Color kCoralTint = Color(0xFFFFEBE0);
const Color kCrimsonTint = Color(0xFFFFECEB);

// ============================================================================
// 01 — UNBOXED EDITORIAL HEADER
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
          Text(
            'YOUR SHARED SPACE',
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: kSanctuaryCrimson,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A little space for the two of you.',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
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
              fontSize: 12.5,
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
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
            icon: const Icon(Icons.favorite_rounded, size: 16, color: Colors.white),
            label: Text(
              'Invite Partner',
              style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }

    final pName = partnerName != null && partnerName!.trim().isNotEmpty
        ? partnerName!.trim()
        : 'Your Partner';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SHARED SANCTUARY',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: kSanctuaryCrimson,
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'You & '),
                    TextSpan(
                      text: pName,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: kSanctuaryCrimson,
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
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isPrivateSpaceActive ? kPurple : kTeal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPrivateSpaceActive
                        ? 'PRIVATE SPACE ACTIVE'
                        : ((durationText != null && durationText!.isNotEmpty)
                            ? '$durationText  ·  SYNCED'
                            : 'CONNECTED'),
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: kSanctuaryMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        InkWell(
          onTap: onManageConnection,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kSanctuaryCard,
              shape: BoxShape.circle,
              border: Border.all(color: kSanctuaryBorder),
            ),
            child: const Icon(Icons.tune_rounded, color: kSanctuaryMuted, size: 18),
          ),
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
        Text(
          'TODAY, TOGETHER',
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: kSanctuaryCrimson,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 98,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: signals.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final spec = signals[index];
              return InkWell(
                onTap: spec.onTap,
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 76,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: spec.tint,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(spec.icon, size: 22, color: spec.colour),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        spec.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: kSanctuaryMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        spec.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
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
// 03 — PRIMARY "RIGHT NOW" EXPERIENCE
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
    if (type == RightNowEventType.lowData) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSanctuaryCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kSanctuaryBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RIGHT NOW',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: kSanctuaryMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nothing new — and that\'s okay.',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: kSanctuaryCharcoal,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your shared space is here whenever you want it.',
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                color: kSanctuaryMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onPrimaryTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    primaryCtaText ?? 'Send something',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kSanctuaryCrimson,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: kSanctuaryCrimson),
                ],
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kSanctuaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                headline ?? 'RIGHT NOW',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: kSanctuaryCrimson,
                ),
              ),
              if (timeDisplay != null && timeDisplay!.isNotEmpty)
                Text(
                  timeDisplay!,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: kSanctuaryMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            bodyText ?? '',
            style: type == RightNowEventType.message
                ? GoogleFonts.cormorantGaramond(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: kSanctuaryCharcoal,
                    height: 1.3,
                  )
                : GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: kSanctuaryCharcoal,
                    height: 1.25,
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (primaryCtaText != null)
                GestureDetector(
                  onTap: onPrimaryTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        primaryCtaText!,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kSanctuaryCrimson,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: kSanctuaryCrimson),
                    ],
                  ),
                ),
              if (secondaryCtaText != null) ...[
                const SizedBox(width: 18),
                GestureDetector(
                  onTap: onSecondaryTap,
                  child: Text(
                    secondaryCtaText!,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kSanctuaryMuted,
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
// 04 — MAKE A LITTLE MOMENT (ACTION RAIL)
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
      (label: 'Send a Bloom', emoji: '🌷', onTap: onSendBloom),
      (label: 'Write a Letter', emoji: '💌', onTap: onWriteLetter),
      (label: 'Leave a Message', emoji: '💬', onTap: onLeaveMessage),
      (label: 'Plan Something', emoji: '✨', onTap: onPlanSomething),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: actions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final a = actions[index];
              return InkWell(
                onTap: a.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: kSanctuaryCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kSanctuaryBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(a.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        a.label,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
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

// ============================================================================
// 05 — YOUR STORY (MEMORY BOOK PREVIEW)
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
        Text(
          'YOUR STORY',
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: kSanctuaryCrimson,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'The moments you\'ve kept.',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
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
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kSanctuaryBorder),
          ),
          child: memoryCount > 0
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: kTealTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.photo_library_outlined, size: 16, color: kTeal),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                latestMemoryTitle ?? 'Shared Moment',
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: kSanctuaryCharcoal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (latestMemoryDate != null)
                                Text(
                                  latestMemoryDate!,
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: kSanctuaryMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: kSanctuaryCanvas,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kSanctuaryBorder),
                          ),
                          child: Text(
                            memoryCount == 1 ? '1 memory' : '$memoryCount memories',
                            style: GoogleFonts.manrope(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: kSanctuaryCharcoal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: onOpenMemoryBook,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View your story',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kSanctuaryCrimson,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: kSanctuaryCrimson),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your story is just beginning.',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: kSanctuaryCharcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The little moments you choose to keep will live here.',
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        color: kSanctuaryMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: onStartMemory,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Start a memory',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kSanctuaryCrimson,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: kSanctuaryCrimson),
                        ],
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
// 06 — LITTLE THINGS (COMPACT ARTIFACTS: LETTERS & BLOOMS)
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
        Text(
          'LITTLE THINGS',
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: kSanctuaryCrimson,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpenLetters,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kSanctuaryCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kSanctuaryBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: kMagentaTint,
                          shape: BoxShape.circle,
                        ),
                        child: const Text('💌', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'LETTERS',
                        style: GoogleFonts.manrope(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: kSanctuaryMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sealedLettersCount > 0
                            ? '$sealedLettersCount sealed'
                            : (lettersCount > 0 ? '$lettersCount written' : 'No letters yet'),
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kSanctuaryCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kSanctuaryBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: kTealTint,
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🌷', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'BLOOMS',
                        style: GoogleFonts.manrope(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: kSanctuaryMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bloomsCount > 0 ? '$bloomsCount blooming' : 'Send a flower',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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
// 07 — DO SOMETHING TOGETHER (CONTEXTUAL ACTIVITY)
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
        Text(
          'DO SOMETHING TOGETHER',
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: kSanctuaryCrimson,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kSanctuaryCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kSanctuaryBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TONIGHT\'S LITTLE IDEA',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: kSanctuaryCrimson,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
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
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: onAction,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isComp
                              ? 'Completed together ✨'
                              : (isInProg ? 'In progress · Finish →' : 'I\'m in →'),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kSanctuaryCrimson,
                          ),
                        ),
                        if (!isComp) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: kSanctuaryCrimson),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onViewAll,
                    child: Text(
                      'All couple ideas',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: kSanctuaryMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 08 — A LITTLE HELP? (DOCSY)
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
        Text(
          'A LITTLE HELP?',
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: kSanctuaryCrimson,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ask Docsy',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
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
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kSanctuaryBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: kCobaltTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, size: 16, color: kCobalt),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dynamicPrompt,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: kSanctuaryCharcoal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: onAskDocsy,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Talk to Docsy',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kSanctuaryCrimson,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: kSanctuaryCrimson),
                  ],
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: kSanctuaryCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kSanctuaryBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: kCrimsonTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, size: 18, color: kSanctuaryCrimson),
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
// 10 — UNPAIRED ASPIRATIONAL PREVIEW
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
        color: kTeal,
        tint: kTealTint,
        title: 'Blooms & Postcards',
        desc: 'Send digital flower blooms and sweet postcards throughout the day.',
      ),
      (
        icon: Icons.mail_outline_rounded,
        color: kMagenta,
        tint: kMagentaTint,
        title: 'Time Capsule Letters',
        desc: 'Leave sealed letters for anniversaries, milestones, and quiet days.',
      ),
      (
        icon: Icons.photo_library_outlined,
        color: kCobalt,
        tint: kCobaltTint,
        title: 'Living Memory Book',
        desc: 'A living scrapbook of memories and challenges you experience together.',
      ),
      (
        icon: Icons.shield_outlined,
        color: kPurple,
        tint: kPurpleTint,
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
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kSanctuaryBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: p.tint, shape: BoxShape.circle),
                  child: Icon(p.icon, size: 18, color: p.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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
      ],
    );
  }
}
