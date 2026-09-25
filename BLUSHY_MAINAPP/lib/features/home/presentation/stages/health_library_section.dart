import 'package:flutter/material.dart';

import 'stage_shared_components.dart';

/// A "Health Library" section header for a stage's home page.
///
/// The generic curated preview cards were removed, so this renders only the
/// section header and is intentionally blank beneath it. Stages fill it with
/// their own content where they have it -- the pregnancy stage adds a
/// "Pregnancy health" subsection directly below this header; every other stage
/// shows just the header.
class HealthLibrarySection extends StatelessWidget {
  const HealthLibrarySection({
    super.key,
    required this.stageKey,
    this.previewCount = 3,
  });

  /// The life stage this section belongs to (kept for call-site compatibility).
  final String stageKey;

  /// Retained for call-site compatibility; no longer used for rendering.
  final int previewCount;

  @override
  Widget build(BuildContext context) {
    return buildSectionTitleWithFilledIcon(
      icon: Icons.menu_book_rounded,
      title: 'Health Library',
    );
  }
}
