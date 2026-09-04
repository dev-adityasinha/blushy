import 'package:flutter/material.dart';

import '../theme/scale.dart';

/// A dashboard section heading.
///
/// Uppercase, spaced, in the brand red, with an optional mark before it. One
/// style for every section on every tab, so a heading is recognisable as a
/// heading before it is read.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.icon});

  final String title;

  /// Retained for API compatibility, but unused per design spec to eliminate header icons.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: BlushyType.eyebrow(),
      ),
    );
  }
}
