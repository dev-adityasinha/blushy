import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/storage.dart';

/// The "Did your period arrive?" flow shared by every stage that tracks a cycle.
///
/// Once the tracker reaches the expected period date (current cycle day has
/// caught up to the cycle length) it asks, from the bottom, whether the period
/// arrived. On "Yes" the caller logs the new period start (which resets the
/// tracker to Day 1) and a short Docsy insight is shown with what Blushy
/// calculated. On "Not yet" it waits until the next day before asking again, and
/// once confirmed it never re-asks for that cycle.
class PeriodArrivalPrompt {
  PeriodArrivalPrompt._();

  static bool _isShowing = false;
  static const String _storeFile = 'period_arrival_prompt.json';

  static const Color _crimson = Color(0xFFDD0D22);
  static const Color _textMain = Color(0xFF221510);
  static const Color _textMuted = Color(0xFF7A6B72);
  static const Color _surface = Color(0xFFFFFFFF);

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Map<String, dynamic> _readStore() {
    try {
      return Map<String, dynamic>.from(BlushyStorage.read(_storeFile));
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static void _writeStore(Map<String, dynamic> store) {
    try {
      BlushyStorage.write(_storeFile, store);
    } catch (_) {}
  }

  /// Shows the prompt when the expected period date has been reached and it has
  /// not already been confirmed for this cycle (or dismissed for today). Safe to
  /// call on every cycle refresh — it de-duplicates itself.
  ///
  /// [onConfirm] must log the given start date (resetting the cycle) and reload
  /// the caller's cycle state.
  static Future<void> maybeShow(
    BuildContext context, {
    required bool hasLoggedPeriod,
    required int currentCycleDay,
    required int cycleLength,
    required DateTime? lastPeriodStart,
    required int completedCycles,
    required Future<void> Function(DateTime start) onConfirm,
  }) async {
    if (_isShowing) return;
    if (!hasLoggedPeriod || lastPeriodStart == null || cycleLength <= 0) return;
    // Not due until the tracker has reached the expected period date.
    if (currentCycleDay < cycleLength) return;

    final String cycleKey = _dayKey(lastPeriodStart);
    final String todayKey = _dayKey(DateTime.now());
    final store = _readStore();

    // Already confirmed for this cycle — don't ask again until a new one starts.
    if (store['confirmed_cycle'] == cycleKey) return;
    // Already asked and set aside today — wait until tomorrow before re-asking.
    if (store['dismissed_cycle'] == cycleKey &&
        store['dismissed_on'] == todayKey) {
      return;
    }

    _isShowing = true;
    bool? confirmed;
    try {
      confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ArrivalSheet(cycleDay: currentCycleDay),
      );
    } finally {
      _isShowing = false;
    }
    if (!context.mounted) return;

    if (confirmed == true) {
      final DateTime start = DateTime.now();
      final int justCompleted = start.difference(lastPeriodStart).inDays;
      try {
        await onConfirm(start);
      } catch (_) {}
      final updated = _readStore()
        ..['confirmed_cycle'] = cycleKey
        ..remove('dismissed_cycle')
        ..remove('dismissed_on');
      _writeStore(updated);
      if (context.mounted) {
        await _showInsight(
          context,
          justCompletedDays: justCompleted,
          averageDays: cycleLength,
          completedCycles: completedCycles,
        );
      }
    } else {
      final updated = _readStore()
        ..['dismissed_cycle'] = cycleKey
        ..['dismissed_on'] = todayKey;
      _writeStore(updated);
    }
  }

  static Future<void> _showInsight(
    BuildContext context, {
    required int justCompletedDays,
    required int averageDays,
    required int completedCycles,
  }) {
    final int shownCycle =
        justCompletedDays > 0 ? justCompletedDays : averageDays;

    final int diff = (shownCycle - averageDays).abs();
    String insight;
    if (completedCycles == 1) {
      insight =
          'This is an early tracked cycle. As you log a few more, Blushy learns '
          'your personal rhythm and its predictions get sharper.';
    } else if (diff <= 3) {
      insight =
          'That is right in line with your usual rhythm of about $averageDays '
          'days — nicely regular.';
    } else {
      insight =
          'A little different from your usual ~$averageDays days. Cycle length '
          'shifting by a few days is completely normal.';
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InsightSheet(
        cycleDays: shownCycle,
        averageDays: averageDays,
        completedCycles: completedCycles,
        insight: insight,
      ),
    );
  }
}

class _ArrivalSheet extends StatelessWidget {
  const _ArrivalSheet({required this.cycleDay});

  final int cycleDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 18,
        left: 22,
        right: 22,
        bottom: 22 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: PeriodArrivalPrompt._surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFECE4DC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: PeriodArrivalPrompt._crimson.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.water_drop_rounded,
                    size: 18, color: PeriodArrivalPrompt._crimson),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Did your period arrive?',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: PeriodArrivalPrompt._textMain,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "You're on day $cycleDay — around when your next period is expected. "
            'Confirm it so Blushy can start a fresh cycle and keep your rhythm '
            'accurate.',
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              height: 1.45,
              color: PeriodArrivalPrompt._textMuted,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: PeriodArrivalPrompt._crimson,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Yes, it started today',
                style: GoogleFonts.manrope(
                    fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Not yet',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: PeriodArrivalPrompt._textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightSheet extends StatelessWidget {
  const _InsightSheet({
    required this.cycleDays,
    required this.averageDays,
    required this.completedCycles,
    required this.insight,
  });

  final int cycleDays;
  final int averageDays;
  final int completedCycles;
  final String insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 18,
        left: 22,
        right: 22,
        bottom: 22 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: PeriodArrivalPrompt._surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFECE4DC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 18, color: PeriodArrivalPrompt._crimson),
              const SizedBox(width: 8),
              Text(
                'Docsy noticed',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: PeriodArrivalPrompt._crimson,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Fresh cycle started 🌸',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: PeriodArrivalPrompt._textMain,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _stat('This cycle', '$cycleDays days'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat('Your average', '~$averageDays days'),
              ),
              if (completedCycles > 0) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _stat('Tracked', '$completedCycles cycles'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            insight,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              height: 1.45,
              color: PeriodArrivalPrompt._textMuted,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: PeriodArrivalPrompt._crimson,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Got it',
                style: GoogleFonts.manrope(
                    fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFE8E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: PeriodArrivalPrompt._textMain,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: PeriodArrivalPrompt._textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
