import 'package:flutter/material.dart';

import '../../services/sia_dashboard_service.dart';
import '../../theme/colors.dart';
import 'sia_screen.dart';

/// Opens Docsy as a sheet over the current screen.
///
/// With [question], the question is sent as her own message the moment the
/// sheet opens -- shown in the thread as hers, then answered -- so a card
/// that hands her to Docsy reads as a conversation she started, not an
/// answer from nowhere. The home is asked to refresh when the sheet closes,
/// since Docsy may have captured something (a mood, a symptom) on the way.
Future<void> openDocsyWith(BuildContext context, String? question) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: BlushyColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BlushySiaScreen(initialQuestion: question),
        ),
      ),
    ),
  ).then((_) => SiaDashboardService().triggerRefresh());
}
