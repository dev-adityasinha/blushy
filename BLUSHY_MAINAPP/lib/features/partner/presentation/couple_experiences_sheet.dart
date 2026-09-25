import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'shared_sanctuary_sections.dart';
import '../../../l10n/app_localizations.dart';

// ============================================================================
// 01. QUICK FOLLOW-UP / AWAITING REPLY SHEET
// ============================================================================

void showQuickFollowUpSheet(
  BuildContext context, {
  required String partnerName,
  required String lastMsg,
  required Function(String nudgeText) onSendNudge,
}) {
  final hasScreenshotPrompt = RegExp(
    r'\b(ss|screenshot|photo|pic|snap|bhej)\b',
    caseSensitive: false,
  ).hasMatch(lastMsg);
  final customController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: kSanctuaryCanvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: kSanctuaryBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                  color: kAmberTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.outgoing_mail, size: 18, color: kAmber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Follow up with $partnerName',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: kSanctuaryCharcoal,
                      ),
                    ),
                    Text(
                      'Your last whisper: “$lastMsg”',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        color: kSanctuaryMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'QUICK NUDGES',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: kSanctuaryCrimson,
            ),
          ),
          const SizedBox(height: 10),
          if (hasScreenshotPrompt) ...[
            _buildNudgeTile(
              ctx,
              icon: Icons.camera_alt_rounded,
              title: AppLocalizations.of(context).ceRemindScreenshot,
              subtitle: AppLocalizations.of(context).ceRemindMsg,
              onTap: () {
                Navigator.pop(ctx);
                onSendNudge('Hey, gentle reminder to send that screenshot! 📸 😉');
              },
            ),
            const SizedBox(height: 8),
          ],
          _buildNudgeTile(
            ctx,
            icon: Icons.waving_hand_rounded,
            title: AppLocalizations.of(context).cePlayfulPing,
            subtitle: AppLocalizations.of(context).cePlayfulMsg,
            onTap: () {
              Navigator.pop(ctx);
              onSendNudge('Hey you! Still waiting on your reply 😉');
            },
          ),
          const SizedBox(height: 8),
          _buildNudgeTile(
            ctx,
            icon: Icons.coffee_rounded,
            title: AppLocalizations.of(context).ceGentleThought,
            subtitle: AppLocalizations.of(context).ceGentleMsg,
            onTap: () {
              Navigator.pop(ctx);
              onSendNudge('Take your time, just thinking of you! 💕');
            },
          ),
          const SizedBox(height: 16),
          // Custom quick follow-up input
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kSanctuaryBorder),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: customController,
                    style: GoogleFonts.manrope(fontSize: 13, color: kSanctuaryCharcoal),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).ceWhisperFollowUp,
                      hintStyle: GoogleFonts.manrope(fontSize: 12.5, color: kSanctuaryMuted),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  final txt = customController.text.trim();
                  if (txt.isNotEmpty) {
                    Navigator.pop(ctx);
                    onSendNudge(txt);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: kSanctuaryCrimson,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildNudgeTile(
  BuildContext ctx, {
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSanctuaryBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kSanctuaryCrimson),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kSanctuaryCharcoal,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    color: kSanctuaryMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: kSanctuaryMuted),
        ],
      ),
    ),
  );
}

// ============================================================================
// 02. DATE PLANNER & AI SEAT BOOKING CONCIERGE SHEET
// ============================================================================

void showDatePlannerSheet(
  BuildContext context, {
  required String partnerName,
  required Function(String inviteMessage) onSendInvite,
  required Function(String prompt) onAskDocsy,
}) {
  final vibes = [
    {'icon': '🕯️', 'label': 'Candlelight Dinner'},
    {'icon': '☕', 'label': 'Cozy Cafe'},
    {'icon': '🎬', 'label': 'Movie & Popcorn'},
    {'icon': '🌅', 'label': 'Sunset Walk'},
    {'icon': '🍸', 'label': 'Rooftop Lounge'},
    {'icon': '🍨', 'label': 'Dessert Hunt'},
  ];

  final times = [
    'Tonight at 8:00 PM',
    'Tomorrow at 7:30 PM',
    'This Saturday Night',
    'Sunday Brunch',
  ];

  String selectedVibe = vibes[0]['label']!;
  String selectedTime = times[0];
  final noteController = TextEditingController(text: 'My treat! Dress up cute ❤️');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 18,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: kSanctuaryCanvas,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kSanctuaryBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: const BoxDecoration(
                        color: kCrimsonTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_rounded, size: 20, color: kSanctuaryCrimson),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plan a Date with $partnerName',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: kSanctuaryCharcoal,
                            ),
                          ),
                          Text(
                            'Pick your vibe and let Docsy concierge assist table bookings',
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              color: kSanctuaryMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      Text(
                        'CHOOSE THE VIBE',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: kSanctuaryCrimson,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: vibes.map((v) {
                          final isSelected = selectedVibe == v['label'];
                          return InkWell(
                            onTap: () => setModalState(() => selectedVibe = v['label']!),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? kSanctuaryCrimson : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? kSanctuaryCrimson : kSanctuaryBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(v['icon']!, style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(
                                    v['label']!,
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white : kSanctuaryCharcoal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),

                      // AI Concierge Seat & Booking Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: kSanctuaryBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome_rounded, size: 16, color: kSanctuaryCrimson),
                                const SizedBox(width: 6),
                                Text(
                                  'DOCSY AI VENUE & TABLE CONCIERGE',
                                  style: GoogleFonts.manrope(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.9,
                                    color: kSanctuaryCrimson,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Need ideas for top-rated spots with seat booking and table reservations nearby for a $selectedVibe?',
                              style: GoogleFonts.manrope(fontSize: 12, color: kSanctuaryCharcoal, height: 1.35),
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                onAskDocsy('Docsy, recommend romantic $selectedVibe spots, ambiance, and seat booking suggestions for me and $partnerName.');
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: kCrimsonTint,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: kSanctuaryCrimson.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.restaurant_rounded, size: 14, color: kSanctuaryCrimson),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Ask Docsy for Seat & Venue Ideas ✨',
                                      style: GoogleFonts.manrope(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: kSanctuaryCrimson,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text(
                        'WHEN SHOULD WE GO?',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: kSanctuaryCrimson,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: times.map((t) {
                          final isSelected = selectedTime == t;
                          return InkWell(
                            onTap: () => setModalState(() => selectedTime = t),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? kCobalt : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? kCobalt : kSanctuaryBorder,
                                ),
                              ),
                              child: Text(
                                t,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : kSanctuaryCharcoal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),

                      Text(
                        'NOTE TO $partnerName',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: kSanctuaryCrimson,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kSanctuaryBorder),
                        ),
                        child: TextField(
                          controller: noteController,
                          style: GoogleFonts.manrope(fontSize: 13, color: kSanctuaryCharcoal),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: AppLocalizations.of(context).ceAddCuteNote,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final note = noteController.text.trim();
                      final inviteMsg = '🥂 DATE INVITATION: $selectedVibe on $selectedTime! ${note.isNotEmpty ? '“$note”' : ''} ❤️';
                      Navigator.pop(ctx);
                      onSendInvite(inviteMsg);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSanctuaryCrimson,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Send Date Invite to $partnerName',
                          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ============================================================================
// 03. SHARED DRAWING CANVAS SHEET
// ============================================================================

class _DoodlePoint {
  final Offset offset;
  final Color color;
  final double strokeWidth;
  _DoodlePoint(this.offset, this.color, this.strokeWidth);
}

void showSharedCanvasSheet(
  BuildContext context, {
  required String partnerName,
  required Function(String message) onSendDrawing,
}) {
  final colors = [
    const Color(0xFFDD0D22), // Crimson
    const Color(0xFFFF4A00), // Coral
    const Color(0xFF2563EB), // Cobalt
    const Color(0xFF0D9488), // Teal
    const Color(0xFFD97706), // Amber
    const Color(0xFF221510), // Charcoal
  ];

  Color selectedColor = colors[0];
  double strokeWidth = 3.5;
  List<List<_DoodlePoint>> strokes = [];
  List<_DoodlePoint> currentStroke = [];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.90,
            padding: const EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 24),
            decoration: const BoxDecoration(
              color: kSanctuaryCanvas,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kSanctuaryBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: kCobaltTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.palette_rounded, size: 20, color: kCobalt),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shared Canvas with $partnerName',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: kSanctuaryCharcoal,
                            ),
                          ),
                          Text(
                            'Doodle, sketch cute notes, and share your drawing',
                            style: GoogleFonts.manrope(fontSize: 11.5, color: kSanctuaryMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.undo_rounded, color: kSanctuaryCharcoal),
                      tooltip: AppLocalizations.of(context).ceUndo,
                      onPressed: strokes.isNotEmpty
                          ? () => setModalState(() => strokes.removeLast())
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: kSanctuaryCrimson),
                      tooltip: AppLocalizations.of(context).ceClear,
                      onPressed: () => setModalState(() {
                        strokes.clear();
                        currentStroke.clear();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Palette & brush selector
                Row(
                  children: [
                    ...colors.map((c) {
                      final isSel = selectedColor == c;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedColor = c),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSel
                                ? [
                                    BoxShadow(
                                      color: c.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }),
                    const Spacer(),
                    // Brush size toggle
                    Row(
                      children: [2.0, 4.0, 8.0].map((sz) {
                        final isSel = strokeWidth == sz;
                        return GestureDetector(
                          onTap: () => setModalState(() => strokeWidth = sz),
                          child: Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isSel ? kSanctuaryCrimson : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: kSanctuaryBorder),
                            ),
                            child: Container(
                              width: sz * 1.5,
                              height: sz * 1.5,
                              decoration: BoxDecoration(
                                color: isSel ? Colors.white : kSanctuaryCharcoal,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Canvas area
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kSanctuaryBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: GestureDetector(
                        onPanStart: (details) {
                          setModalState(() {
                            currentStroke = [
                              _DoodlePoint(details.localPosition, selectedColor, strokeWidth),
                            ];
                            strokes.add(currentStroke);
                          });
                        },
                        onPanUpdate: (details) {
                          setModalState(() {
                            currentStroke.add(
                              _DoodlePoint(details.localPosition, selectedColor, strokeWidth),
                            );
                          });
                        },
                        onPanEnd: (_) {
                          currentStroke = [];
                        },
                        child: CustomPaint(
                          painter: _DoodlePainter(strokes),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: strokes.isNotEmpty
                        ? () {
                            final count = strokes.length;
                            Navigator.pop(ctx);
                            onSendDrawing('🎨 [Shared Canvas]: Sent a hand-drawn sketch for you with $count brush strokes! ❤️');
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSanctuaryCrimson,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Send Sketch to $partnerName',
                          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _DoodlePainter extends CustomPainter {
  final List<List<_DoodlePoint>> strokes;
  _DoodlePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      for (int i = 0; i < stroke.length - 1; i++) {
        final p1 = stroke[i];
        final p2 = stroke[i + 1];
        final paint = Paint()
          ..color = p1.color
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = p1.strokeWidth;
        canvas.drawLine(p1.offset, p2.offset, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) => true;
}

// ============================================================================
// 04. COUPLE GAMES (PLAY VIRTUALLY VIA TEXT) SHEET
// ============================================================================

void showCoupleGamesSheet(
  BuildContext context, {
  required String partnerName,
  required Function(String gameMessage) onSendGameQuestion,
}) {
  final wouldYouRatherQuestions = [
    'Stay in cooking an elaborate meal together OR spontaneous late-night street food hunt?',
    'Have breakfast in bed every Sunday OR never have to do the dishes ever again?',
    'Relive our first date all over again OR fast-forward to our dream vacation?',
    'A cozy mountain cabin in the rain OR a private beach hut with turquoise water?',
    'Only communicate via handwritten letters for a week OR switch lives for 24 hours?',
    'Watch a scary movie cuddling tightly OR attend a loud live concert together?',
  ];

  final pillowTalkQuestions = [
    'What was the exact moment you realized you had feelings for me?',
    'What is one little habit of mine that secretly makes you smile?',
    'If we could pause time for 24 hours just for the two of us, what would we do?',
    'What is your favorite memory of us from this past year?',
    'What song reminds you of me whenever you hear it playing?',
    'What is something new you want us to try together next month?',
  ];

  final truthOrDarePrompts = [
    '📸 Send a selfie right now with the goofiest face you can make!',
    '🎵 Voice note: Sing 15 seconds of the chorus of our favorite song.',
    '💬 Tell me the very first thought you had when you saw me in person.',
    '❤️ What is your favorite physical feature of mine?',
    '🌟 Share one secret daydream you have about our future.',
  ];

  int selectedCategory = 0; // 0: WYR, 1: Pillow Talk, 2: Truth or Dare
  int questionIndex = 0;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final currentList = selectedCategory == 0
              ? wouldYouRatherQuestions
              : (selectedCategory == 1 ? pillowTalkQuestions : truthOrDarePrompts);
          final activeQuestion = currentList[questionIndex % currentList.length];
          final categoryTitle = selectedCategory == 0
              ? 'Would You Rather?'
              : (selectedCategory == 1 ? 'Pillow Talk' : 'Truth or Dare');

          return Container(
            height: MediaQuery.of(context).size.height * 0.82,
            padding: const EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 24),
            decoration: const BoxDecoration(
              color: kSanctuaryCanvas,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kSanctuaryBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: const BoxDecoration(
                        color: kMagentaTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.casino_rounded, size: 20, color: kMagenta),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Play Games with $partnerName',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: kSanctuaryCharcoal,
                            ),
                          ),
                          Text(
                            'Take turns answering and text virtually in Messenger',
                            style: GoogleFonts.manrope(fontSize: 11.5, color: kSanctuaryMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category selector pills
                Row(
                  children: [
                    _buildGameTab('Would You Rather?', 0, selectedCategory, () {
                      setModalState(() {
                        selectedCategory = 0;
                        questionIndex = 0;
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildGameTab('Pillow Talk', 1, selectedCategory, () {
                      setModalState(() {
                        selectedCategory = 1;
                        questionIndex = 0;
                      });
                    }),
                    const SizedBox(width: 8),
                    _buildGameTab('Truth & Dare', 2, selectedCategory, () {
                      setModalState(() {
                        selectedCategory = 2;
                        questionIndex = 0;
                      });
                    }),
                  ],
                ),
                const SizedBox(height: 20),

                // Question Display Card
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: kSanctuaryBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: kMagentaTint,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                categoryTitle.toUpperCase(),
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: kMagenta,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '“$activeQuestion”',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                color: kSanctuaryCharcoal,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  questionIndex++;
                                });
                              },
                              icon: const Icon(Icons.shuffle_rounded, size: 16, color: kSanctuaryCharcoal),
                              label: Text(
                                'Shuffle Question',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: kSanctuaryCharcoal,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: kSanctuaryBorder),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final gameMsg = '🎲 COUPLE GAME with $partnerName: $categoryTitle\n“$activeQuestion”\nYour turn to reply!';
                      Navigator.pop(ctx);
                      onSendGameQuestion(gameMsg);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSanctuaryCrimson,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Send Question to $partnerName in Chat',
                          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _buildGameTab(String label, int index, int selectedIndex, VoidCallback onTap) {
  final isSelected = index == selectedIndex;
  return Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? kSanctuaryCrimson : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? kSanctuaryCrimson : kSanctuaryBorder,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : kSanctuaryCharcoal,
          ),
        ),
      ),
    ),
  );
}

// ============================================================================
// 05. A WARM GESTURE SHEET (TACTILE MICRO-AFFECTION)
// ============================================================================

void showWarmGestureSheet(
  BuildContext context, {
  required String partnerName,
  required Function(String message) onSendGesture,
}) {
  final gestures = [
    (
      title: AppLocalizations.of(context).ceHotCoffee,
      subtitle: AppLocalizations.of(context).ceHotCoffeeMsg,
      message: 'Sending you a warm cup of coffee & cozy hug ☕❤️',
      icon: Icons.coffee_rounded,
      tint: kTealTint,
      accent: kTeal,
    ),
    (
      title: AppLocalizations.of(context).ceBigEmbrace,
      subtitle: AppLocalizations.of(context).ceBigEmbraceMsg,
      message: 'Wrapping you in the biggest warm embrace today 🫂✨',
      icon: Icons.favorite_rounded,
      tint: kMagentaTint,
      accent: kMagenta,
    ),
    (
      title: AppLocalizations.of(context).ceForeheadKiss,
      subtitle: AppLocalizations.of(context).ceForeheadKissMsg,
      message: 'A gentle forehead kiss to brighten your day 💋🌸',
      icon: Icons.face_rounded,
      tint: kCoralTint,
      accent: kCoral,
    ),
    (
      title: AppLocalizations.of(context).ceTreatDelivery,
      subtitle: AppLocalizations.of(context).ceTreatDeliveryMsg,
      message: 'Sending sweet treats and all my love to you 🍫🥰',
      icon: Icons.cookie_rounded,
      tint: kAmberTint,
      accent: kAmber,
    ),
    (
      title: AppLocalizations.of(context).cePauseBreathe,
      subtitle: AppLocalizations.of(context).cePauseBreatheMsg,
      message: 'Take a deep breath, my love. You are doing amazing 🌿🕊️',
      icon: Icons.spa_rounded,
      tint: kCobaltTint,
      accent: kCobalt,
    ),
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: kSanctuaryCanvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: kSanctuaryBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'SWEET SURPRISE',
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: kSanctuaryCrimson,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Send a Warm Gesture to $partnerName',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kSanctuaryCharcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap any gesture below to send it instantly into your shared chat.',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: kSanctuaryMuted,
              ),
            ),
            const SizedBox(height: 16),
            ...gestures.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      onSendGesture(g.message);
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: kSanctuaryBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
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
                              shape: BoxShape.circle,
                              color: g.tint,
                            ),
                            child: Icon(g.icon, size: 22, color: g.accent),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.title,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: kSanctuaryCharcoal,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  g.subtitle,
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: kSanctuaryMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: g.accent),
                        ],
                      ),
                    ),
                  ),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

// ============================================================================
// 06. VIBE PULSE SHEET (HEARTBEAT & ENERGY SHARING)
// ============================================================================

void showVibePulseSheet(
  BuildContext context, {
  required String partnerName,
  required Function(String message) onSendVibe,
}) {
  final vibes = [
    (
      title: AppLocalizations.of(context).ceThinkingOfYou,
      subtitle: AppLocalizations.of(context).ceThinkingMsg,
      message: 'Thinking of you right now and smiling ✨❤️',
      icon: Icons.auto_awesome_rounded,
      tint: kCobaltTint,
      accent: kCobalt,
    ),
    (
      title: AppLocalizations.of(context).ceMissingVoice,
      subtitle: AppLocalizations.of(context).ceMissingMsg,
      message: 'Missing you a little extra today 🥺❤️',
      icon: Icons.favorite_border_rounded,
      tint: kMagentaTint,
      accent: kMagenta,
    ),
    (
      title: AppLocalizations.of(context).ceCravingCuddles,
      subtitle: AppLocalizations.of(context).ceCravingMsg,
      message: 'Officially craving cuddles with you 🧸❤️',
      icon: Icons.pets_rounded,
      tint: kAmberTint,
      accent: kAmber,
    ),
    (
      title: AppLocalizations.of(context).ceProudOfYou,
      subtitle: AppLocalizations.of(context).ceProudMsg,
      message: 'Just wanted to say: I am so incredibly proud of you 🌟💖',
      icon: Icons.star_rounded,
      tint: kAmberTint,
      accent: kAmber,
    ),
    (
      title: AppLocalizations.of(context).ceRechargeNeeded,
      subtitle: AppLocalizations.of(context).ceRechargeMsg,
      message: 'Low battery today, need your sweet positive warmth 🔋🥺',
      icon: Icons.battery_charging_full_rounded,
      tint: kTealTint,
      accent: kTeal,
    ),
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: kSanctuaryCanvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: kSanctuaryBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'HEARTBEAT & ENERGY',
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: kSanctuaryCrimson,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Share Your Vibe with $partnerName',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kSanctuaryCharcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Send your real energy state to $partnerName with one gentle tap.',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: kSanctuaryMuted,
              ),
            ),
            const SizedBox(height: 16),
            ...vibes.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      onSendVibe(v.message);
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: kSanctuaryBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
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
                              shape: BoxShape.circle,
                              color: v.tint,
                            ),
                            child: Icon(v.icon, size: 22, color: v.accent),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.title,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: kSanctuaryCharcoal,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  v.subtitle,
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: kSanctuaryMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: v.accent),
                        ],
                      ),
                    ),
                  ),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

