import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// "Docsy" with its square mark, the way BLUSHY. carries its dot.
///
/// The product wordmark ends in a round full stop in accent orange. Docsy's
/// mark is the same colour and plays the same role, but is square — so the two
/// names read as a family without being mistaken for one another.
///
/// Used only where Docsy stands alone as a name: the tab, the header that
/// names the tab, and the button that opens it. Inside a sentence a mark after
/// the word reads as a typo rather than a wordmark, so "Ask Docsy" and "Docsy
/// speaks" stay plain text.
///
/// Built with a [WidgetSpan] rather than a Row so the name keeps ordinary text
/// behaviour — the header ellipsizes its title, and several translations are
/// far longer than the English.
class DocsyWordmark extends StatelessWidget {
  const DocsyWordmark({
    super.key,
    required this.text,
    required this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  /// The name as it should read — the header uppercases it, the tab does not.
  final String text;

  /// The style the surrounding label would have used.
  final TextStyle style;

  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    // Tied to the text size so the mark stays proportional wherever it is
    // used: it appears at 10.5pt in the tab bar and larger in the header.
    final double side = ((style.fontSize ?? 14) * 0.22).clamp(2.0, 6.0);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Padding(
              padding: EdgeInsets.only(left: side * 0.5),
              child: Container(
                width: side,
                height: side,
                color: BlushyColors.accent,
              ),
            ),
          ),
        ],
      ),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
