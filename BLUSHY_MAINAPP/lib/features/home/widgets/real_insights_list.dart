import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/blushy_models.dart';
import '../../../services/api_blushy_service.dart';
import '../../../services/api_contract_client.dart';
import '../../../theme/colors.dart';

/// Patterns the server actually derived from this user's logs.
///
/// Replaces eight hardcoded lists that asserted personal findings nobody had
/// measured — "Based on your last 3 cycles, your LH peak consistently falls on
/// Day 17", "a 30% drop in intensity", "you feel more energetic after 7.5
/// hours". Those read as conclusions from tracking, which is exactly what they
/// were not.
///
/// The pattern engine needs enough logs before it will say anything, so an
/// insufficient-data response is shown as such rather than filled in.
class RealInsightsList extends StatefulWidget {
  const RealInsightsList({
    super.key,
    this.title = 'What your logs show',
    this.limit = 5,
  });

  final String title;
  final int limit;

  @override
  State<RealInsightsList> createState() => _RealInsightsListState();
}

class _RealInsightsListState extends State<RealInsightsList> {
  ApiResult<List<Insight>> _result = const ApiResult.loading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await PatternsApi.load(limit: widget.limit);
    if (!mounted) return;
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final insights = _result.data ?? const <Insight>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.text,
                ),
              ),
            ),
            if (_result.state == ApiState.loading)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 12),
        if (_result.isError)
          _notice('Could not load your patterns',
              'They will appear once the connection is back.')
        else if (_result.isInsufficientData)
          _notice('Not enough logged yet to find a pattern',
              'The more you log, the more the engine can say. It stays quiet until it has enough to be sure.')
        else if (_result.state != ApiState.loading && insights.isEmpty)
          _notice('No patterns yet',
              'Nothing stood out in what you have logged so far.')
        else
          ...insights.map(_card),
      ],
    );
  }

  Widget _card(Insight insight) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insight.title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: BlushyColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            insight.description,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              height: 1.5,
              color: BlushyColors.secondaryText,
            ),
          ),
          const SizedBox(height: 10),
          // How much this rests on, so a reader can weigh it. A pattern drawn
          // from three logs should not look like one drawn from thirty.
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (insight.sourceEventIds.isNotEmpty)
                _chip('${insight.sourceEventIds.length} of your logs'),
              if (insight.strength != null && insight.strength!.isNotEmpty)
                _chip('Strength: ${insight.strength}'),
              if (insight.engineVersion != null)
                _chip('Rule-based', muted: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, {bool muted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: muted ? BlushyColors.taupe : BlushyColors.lutealSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: muted ? BlushyColors.secondaryText : BlushyColors.primary,
        ),
      ),
    );
  }

  Widget _notice(String headline, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: BlushyColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: BlushyColors.text,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 12,
              height: 1.45,
              color: BlushyColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
