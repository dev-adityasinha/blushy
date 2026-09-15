import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/blushy_models.dart';
import '../../../services/api_blushy_service.dart';
import '../../../services/api_contract_client.dart';
import '../../../theme/colors.dart';

/// A user's journey, built from what they actually logged.
///
/// This replaces seven hardcoded timelines, one per life stage, that marked
/// milestones such as "20 Week Scan Done" complete on a freshly installed app.
/// Every row here is a real health event with the date it was recorded, so an
/// empty journey shows as empty rather than as a history that never happened.
class RealJourneyTimeline extends StatefulWidget {
  const RealJourneyTimeline({
    super.key,
    this.title = 'Your Journey',
    this.emptyHeadline = 'Your journey starts with your first log',
    this.emptyBody =
        'Everything you record here builds your timeline. Log a period, a check-in or a '
        'reflection and it appears with the date you logged it.',
    this.limit = 12,
    this.eventTypes,
  });

  final String title;
  final String emptyHeadline;
  final String emptyBody;
  final int limit;

  /// Narrows the timeline to particular event types, so a stage can show the
  /// part of the history that concerns it.
  final List<String>? eventTypes;

  @override
  State<RealJourneyTimeline> createState() => _RealJourneyTimelineState();
}

class _RealJourneyTimelineState extends State<RealJourneyTimeline>
    with AutomaticKeepAliveClientMixin {
  // A section of the lazy home list: kept alive so it loads once, not on
  // every scroll back into view.
  @override
  bool get wantKeepAlive => true;

  ApiResult<Timeline> _result = const ApiResult.loading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await EventsApi.timeline(
      limit: widget.limit,
      eventTypes: widget.eventTypes,
    );
    if (!mounted) return;
    setState(() => _result = result);
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final entries = _result.data?.entries ?? const <TimelineEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.text,
                ),
              ),
            ),
            if (_result.state == ApiState.loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_result.isError)
          _message(
            'Could not load your journey',
            'It will appear once the connection is back. Nothing you logged is lost.',
            onRetry: _load,
          )
        else if (_result.state != ApiState.loading && entries.isEmpty)
          _message(widget.emptyHeadline, widget.emptyBody)
        else
          ...entries.map(_entryRow),
      ],
    );
  }

  Widget _entryRow(TimelineEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: BlushyColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 1.4,
                height: 28,
                color: BlushyColors.border,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(entry.date),
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: BlushyColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.displayText,
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: BlushyColors.text,
                  ),
                ),
                // Says where the record came from, so a value the user typed is
                // never confused with one the app inferred.
                if (entry.source.isNotEmpty)
                  Text(
                    entry.source == 'manual' ? 'You logged this' : 'Source: ${entry.source}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(String headline, String body, {VoidCallback? onRetry}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE3E6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDD0D22).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEAEA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Color(0xFFDD0D22),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  headline,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: BlushyColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              height: 1.45,
              color: const Color(0xFF645A60),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEAEA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFDD0D22)),
                    const SizedBox(width: 6),
                    Text(
                      'Try again',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFDD0D22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
