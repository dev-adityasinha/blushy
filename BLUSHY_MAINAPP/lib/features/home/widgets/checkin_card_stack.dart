import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colors.dart';
import '../checkin_followups.dart';
import 'checkin_scene.dart';
import 'checkin_scene_view.dart';

/// The check-in follow-ups, as a deck of cards.
///
/// One question at a time, with the next showing behind it, rather than a
/// column of them: a list of five questions reads as a form, and the whole
/// point of these is that they are short and answerable.
///
/// Swipe either way to look at another card without answering it. Answering
/// advances to the next one.
class CheckinCardStack extends StatefulWidget {
  const CheckinCardStack({
    super.key,
    required this.cards,
    required this.answerFor,
    required this.onAnswer,
  });

  final List<CheckinFollowUp> cards;

  /// Today's answer for a card, if it has one. Shown on the card so a question
  /// already answered does not look unanswered.
  final String? Function(CheckinFollowUp card) answerFor;

  final void Function(CheckinFollowUp card, String value) onAnswer;

  @override
  State<CheckinCardStack> createState() => _CheckinCardStackState();
}

class _CheckinCardStackState extends State<CheckinCardStack>
    with TickerProviderStateMixin {
  /// Drives every scene. One controller for the deck rather than one per card:
  /// only the top two are ever visible, and five looping controllers behind a
  /// screen is work nobody sees.
  late final AnimationController _scene = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  /// Carries the card after it is let go.
  ///
  /// Unbounded and driven by a spring rather than a curve over a fixed
  /// duration: a spring takes the speed of the flick with it, so a hard swipe
  /// leaves fast and a slow one drifts. A tween cannot do that -- every
  /// release takes the same 280ms whatever the hand did.
  late final AnimationController _settle =
      AnimationController.unbounded(vsync: this);

  /// The spring the cards move on. Stiff enough to feel immediate, damped just
  /// under critical so it arrives without wobbling around the target -- a card
  /// carrying a question should not bounce.
  static const SpringDescription _spring =
      SpringDescription(mass: 1, stiffness: 320, damping: 34);

  int _index = 0;
  double _drag = 0;

  /// Where the spring is heading. Zero brings the card back to the middle.
  double _settleTo = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Held still when the device asks for less motion. A looping scene is
    // decoration, and someone who has turned animation off has said they do
    // not want it -- it also means the widget can settle, which a permanently
    // repeating controller never does.
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced) {
      if (_scene.isAnimating) _scene.stop();
      _scene.value = 0.25;
    } else if (!_scene.isAnimating) {
      _scene.repeat();
    }
  }

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      setState(() => _drag = _settle.value);

      // A spring never formally completes, so arrival is judged on distance
      // rather than on a status. Once the card is off the screen there is
      // nothing left to watch it do.
      if (_settleTo != 0 && (_drag - _settleTo).abs() < 1) {
        _settle.stop();
        setState(() {
          _index = _wrap(_index + (_settleTo > 0 ? -1 : 1));
          _drag = 0;
          _settleTo = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _scene.dispose();
    _settle.dispose();
    super.dispose();
  }

  /// The deck loops, so the last card's next is the first again.
  int _wrap(int index) {
    final count = widget.cards.length;
    if (count == 0) return 0;
    return (index % count + count) % count;
  }

  /// Lets the card go, at whatever speed it was moving.
  ///
  /// [velocity] is pixels per second from the gesture. A flick counts as well
  /// as distance: a short, fast swipe means the card should leave, and judging
  /// on distance alone would drag it back under the thumb.
  void _release(double width, double velocity) {
    final flicked = velocity.abs() > 420;
    // A third of the card is far enough to mean it: less than that, with no
    // speed behind it, and a scroll that caught the card would throw the
    // question away.
    final leaving = flicked || _drag.abs() > width / 3;

    if (leaving) {
      final direction = flicked
          ? (velocity.isNegative ? -1 : 1)
          : (_drag.isNegative ? -1 : 1);
      _settleTo = direction * width * 1.4;
    } else {
      _settleTo = 0;
    }

    _settle
      ..stop()
      ..animateWith(
        SpringSimulation(_spring, _drag, _settleTo, velocity),
      );
  }

  void _answer(CheckinFollowUp card, String value) {
    widget.onAnswer(card, value);
    if (widget.cards.length < 2) return;

    // Off to the left, the way a card that is done with should go. Given a
    // push so it leaves like a swipe rather than easing away.
    _settleTo = -MediaQuery.sizeOf(context).width * 1.4;
    _settle
      ..stop()
      ..animateWith(SpringSimulation(_spring, _drag, _settleTo, -900));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();

    final card = widget.cards[_wrap(_index)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "BECAUSE OF TODAY'S SYMPTOMS",
          style: GoogleFonts.manrope(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.7,
            color: BlushyColors.secondaryText,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 330,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Behind first, so the front card draws over them.
                  for (int depth = 2; depth >= 1; depth--)
                    if (widget.cards.length > depth)
                      _behind(
                        widget.cards[_wrap(_index + depth)],
                        depth,
                        width,
                      ),
                  _front(card, width),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        _answers(card),
        if (widget.cards.length > 1) ...[const SizedBox(height: 10), _dots()],
      ],
    );
  }

  /// A card waiting its turn: smaller, lower, and rising as the front one goes.
  Widget _behind(CheckinFollowUp card, int depth, double width) {
    // How far the front card has been pulled, 0..1. The deck moves with it, so
    // the next card is already coming forward before the top one has left.
    final progress = (_drag.abs() / width).clamp(0.0, 1.0);
    final effective = depth - progress;

    return Transform.translate(
      offset: Offset(0, 12 * effective),
      child: Transform.scale(
        scale: 1 - 0.05 * effective,
        child: Opacity(
          opacity: (1 - 0.25 * effective).clamp(0.0, 1.0),
          child: IgnorePointer(child: _card(card, animate: false)),
        ),
      ),
    );
  }

  Widget _front(CheckinFollowUp card, double width) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) => setState(() => _drag += d.delta.dx),
      onHorizontalDragEnd: (d) =>
          _release(width, d.primaryVelocity ?? 0),
      child: Transform.translate(
        offset: Offset(_drag, 0),
        child: Transform.rotate(
          // A small tilt with the drag, so the card feels picked up rather
          // than slid.
          angle: (_drag / width) * 0.12,
          child: _card(card, animate: true),
        ),
      ),
    );
  }

  Widget _card(CheckinFollowUp card, {required bool animate}) {
    final scene = CheckinScene.forMetric(card.metric);
    final answered = widget.answerFor(card);

    return Container(
      // The deck's Stack gives loose constraints, so without this the card
      // sized to its content and sat narrower than the section.
      width: double.infinity,
      decoration: BoxDecoration(
        color: scene.colour,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // The upper part of the card only. Filling it put the figure behind
          // the question, where the two overlapped and neither read.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 118,
            child: animate
                ? AnimatedBuilder(
                    animation: _scene,
                    builder: (_, _) => CheckinSceneView(
                      scene: scene,
                      t: _scene.value,
                      animate: _scene.isAnimating,
                    ),
                  )
                // The cards behind are still: five looping scenes for one
                // visible card is work nobody sees.
                : CheckinSceneView(scene: scene, t: 0.25, animate: false),
          ),
          Column(
            children: [
              const SizedBox(height: 14),
              _chip(scene.label, answered),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                child: Column(
                  children: [
                    // The question, and nothing under it. The line naming
                    // the symptoms that raised it explained the machinery
                    // rather than helping anyone answer.
                    Text(
                      card.question,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String? answered) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (answered != null) ...[
            const Icon(Icons.check_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 5),
          ],
          Text(
            // Always the category. It used to show the stored value, so an
            // answered water card announced "1L" -- the shape the answer
            // happens to be recorded in, which means nothing here.
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _answers(CheckinFollowUp card) {
    final answered = widget.answerFor(card);
    return Row(
      children: [
        Expanded(
          child: _answerButton(
            label: 'No',
            icon: Icons.close_rounded,
            selected: answered == card.noValue,
            onTap: () => _answer(card, card.noValue),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _answerButton(
            label: 'Yes',
            icon: Icons.check_rounded,
            selected: answered == card.yesValue,
            onTap: () => _answer(card, card.yesValue),
          ),
        ),
      ],
    );
  }

  Widget _answerButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? BlushyColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? BlushyColors.primary : BlushyColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : BlushyColors.text,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : BlushyColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Which card of how many, so the deck does not look bottomless.
  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < math.min(widget.cards.length, 8); i++)
          Container(
            width: i == _wrap(_index) ? 16 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == _wrap(_index)
                  ? BlushyColors.primary
                  : BlushyColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
