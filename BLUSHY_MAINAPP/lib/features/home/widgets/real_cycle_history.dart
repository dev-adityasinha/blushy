import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/api_blushy_service.dart';
import '../../../services/api_contract_client.dart';
import '../../../theme/colors.dart';

/// Cycle lengths measured from the periods the user actually logged.
///
/// Replaces a hardcoded list ("Cycle #5 — 38 Days", and four more) that showed
/// the same invented history to everyone, including someone who had logged
/// nothing at all.
///
/// A length is the gap between two consecutive period start dates, so N logged
/// periods yield N-1 lengths. With fewer than two there is nothing to measure,
/// and the card says so rather than inventing a baseline.
class RealCycleHistory extends StatefulWidget {
  const RealCycleHistory({super.key, this.maxEntries = 6});

  final int maxEntries;

  @override
  State<RealCycleHistory> createState() => _RealCycleHistoryState();
}

class _CycleLength {
  const _CycleLength(this.label, this.days);
  final String label;
  final int days;
}

class _RealCycleHistoryState extends State<RealCycleHistory> {
  ApiResult<List<Map<String, dynamic>>> _result = const ApiResult.loading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await CycleApi.history(limit: widget.maxEntries + 1);
    if (!mounted) return;
    setState(() => _result = result);
  }

  /// Newest first, matching how the periods come back.
  List<_CycleLength> _lengths() {
    final rows = _result.data ?? const [];
    final starts = <DateTime>[];
    for (final row in rows) {
      final raw = row['periodStartDate'] ?? row['startDate'];
      final parsed = raw is String ? DateTime.tryParse(raw) : null;
      if (parsed != null) starts.add(parsed);
    }
    starts.sort((a, b) => b.compareTo(a));

    final lengths = <_CycleLength>[];
    for (var i = 0; i < starts.length - 1; i++) {
      final days = starts[i].difference(starts[i + 1]).inDays;
      if (days <= 0) continue;
      lengths.add(_CycleLength('Cycle #${starts.length - 1 - i}', days));
    }
    return lengths.take(widget.maxEntries).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loading = _result.state == ApiState.loading;
    final lengths = loading ? const <_CycleLength>[] : _lengths();

    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (lengths.isEmpty) {
      return _notice(
        _result.isError
            ? 'Could not load your cycle history'
            : 'Not enough logged periods yet',
        _result.isError
            ? 'It will appear once the connection is back.'
            : 'A cycle length is the gap between two period start dates, so this fills in '
                'once you have logged a second period.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lengths.map(_row).toList(),
    );
  }

  Widget _row(_CycleLength entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            entry.label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: BlushyColors.text,
            ),
          ),
          Text(
            '${entry.days} Days',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: BlushyColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice(String headline, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: BlushyColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: GoogleFonts.manrope(
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
