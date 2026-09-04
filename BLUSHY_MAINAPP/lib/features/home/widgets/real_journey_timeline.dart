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

class _RealJourneyTimelineState extends State<RealJourneyTimeline> {
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: BlushyColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: BlushyColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              height: 1.5,
              color: BlushyColors.secondaryText,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BlushyColors.primary,
                side: const BorderSide(color: BlushyColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
