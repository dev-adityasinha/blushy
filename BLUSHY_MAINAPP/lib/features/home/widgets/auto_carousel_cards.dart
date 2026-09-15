import 'dart:async';
import 'package:flutter/material.dart';
import '../../../theme/colors.dart';

/// A card carousel that automatically transitions through cards of the same category
/// every [autoScrollDuration] (default 3 seconds), with manual swipe gesture support
/// and subtle page indicator dots.
class AutoCarouselCards extends StatefulWidget {
  const AutoCarouselCards({
    super.key,
    required this.cards,
    this.autoScrollDuration = const Duration(seconds: 3),
    this.height = 210.0,
    this.categoryEyebrow,
  });

  final List<Widget> cards;
  final Duration autoScrollDuration;
  final double height;
  final String? categoryEyebrow;

  @override
  State<AutoCarouselCards> createState() => _AutoCarouselCardsState();
}

class _AutoCarouselCardsState extends State<AutoCarouselCards> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.cards.length <= 1) return;
    _timer = Timer.periodic(widget.autoScrollDuration, (_) {
      if (!mounted) return;
      final nextPage = (_currentPage + 1) % widget.cards.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();
    if (widget.cards.length == 1) return widget.cards.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.categoryEyebrow != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
            child: Text(
              widget.categoryEyebrow!.toUpperCase(),
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: BlushyColors.primary,
              ),
            ),
          ),
        ],
        Listener(
          onPointerDown: (_) => _timer?.cancel(),
          onPointerUp: (_) => _startTimer(),
          child: SizedBox(
            height: widget.height,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.cards.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: widget.cards[index],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.cards.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 4,
              width: _currentPage == index ? 16 : 6,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? BlushyColors.primary
                    : const Color(0xFFE2D9D5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
