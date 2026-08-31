import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Onboarding has to be able to switch on the personalisation the dashboard
/// already supports.
///
/// `_isMetricSelected` gates 45 places on the home page against the answers
/// given at signup. **67 of its 100 keywords could not be produced by any
/// question** — the personalisation was built and could not be reached. Worse,
/// the branch most women take, reproductive years, asked about cycle type,
/// last period, goals and contraception and never about symptoms at all, so it
/// fell through to a fixed set of cards.
void main() {
  String read(String p) => File(p).readAsStringSync();

  final wizard = read('lib/features/auth/presentation/onboarding_wizard.dart');
  final dashboard =
      read('lib/features/home/presentation/stages/everyday_wellness_dashboard.dart');

  Set<String> dashboardKeywords() {
    final out = <String>{};
    for (final call in RegExp(r'_isMetricSelected\([^)]*\[[^\]]*\]').allMatches(dashboard)) {
      for (final k in RegExp(r"'([a-z ]+)'").allMatches(call[0]!)) {
        out.add(k[1]!);
      }
    }
    return out;
  }

  Set<String> onboardingOptions() => RegExp(r'''["']([A-Z][a-z][A-Za-z &/,'-]{2,40})["']''')
      .allMatches(wizard)
      .map((m) => m[1]!.toLowerCase())
      .toSet();

  test('the main branch asks what she notices', () {
    // Reproductive years is the most common route and had no symptoms step.
    expect(wizard.contains('_buildReproductiveStep8'), isTrue,
        reason: 'the branch most women take must ask about symptoms');
    expect(RegExp(r'if \(branchStep == 4\) return _profile\.symptoms\.isNotEmpty;')
        .hasMatch(wizard), isTrue,
        reason: 'and require an answer, as the other symptom steps do');
  });

  test('most of the dashboard is now reachable from onboarding', () {
    final keywords = dashboardKeywords();
    final options = onboardingOptions();
    expect(keywords.length, greaterThan(50), reason: 'the gating keywords moved');

    final reachable = keywords
        .where((k) => options.any((o) => k.contains(o) || o.contains(k)))
        .length;

    // Was 33 of 100. The remainder is mostly stage-specific vocabulary that
    // belongs in its own branch, not in a question everyone answers.
    expect(reachable, greaterThanOrEqualTo(55),
        reason: 'only $reachable of ${keywords.length} cards can be switched on '
            'by anything a user is asked');
  });

  test('every branch that asks about symptoms asks a useful question', () {
    // An option that unlocks nothing is a question asked for no reason.
    //
    // Checked across all three symptom steps rather than the reproductive one
    // alone: this guard caught "Breast tenderness" there, and would have said
    // nothing about the same mistake in the TTC or postpartum branches, which
    // is exactly where new options get added.
    //
    // Anchored on each definition, not the first mention — the call site in
    // steps.addAll appears earlier, and slicing from there reads a different
    // method's options.
    final keywords = dashboardKeywords();

    // Discovered rather than listed by name: a named list only covers the
    // steps someone remembered to add to it, and the PCOS, perimenopause and
    // menopause steps were carrying orphaned options the whole time precisely
    // because nothing was looking at them.
    final steps = RegExp(r'Widget (_build\w+)\(\)')
        .allMatches(wizard)
        .map((m) => m[1]!)
        .where((n) {
          final at = wizard.indexOf('Widget $n()');
          final next = wizard.indexOf('Widget _build', at + 10);
          final body =
              wizard.substring(at, next == -1 ? wizard.length : next);
          return body.contains('_buildMultiSelectSymptomsStep');
        })
        .toList();

    expect(steps.length, greaterThanOrEqualTo(5),
        reason: 'the symptom steps moved or were renamed');

    for (final step in steps) {
      final defAt = wizard.indexOf('Widget $step()');
      final start = wizard.indexOf('options = [', defAt);
      final block = wizard.substring(start, wizard.indexOf('];', start));
      final options = RegExp(r'"([^"]+)"')
          .allMatches(block)
          .map((m) => m[1]!.toLowerCase())
          .toList();
      expect(options, isNotEmpty, reason: '$step offers nothing');

      final orphans = options
          .where((o) => !keywords.any((k) => k.contains(o) || o.contains(k)))
          .toList();

      expect(orphans, isEmpty,
          reason: '$step asks these but they change nothing: '
              '${orphans.join(", ")}');
    }
  });

  test('TTC and postpartum ask what she notices too', () {
    // Both branches asked how she tracks, how she feeds and what she wants
    // help with, and never what her body was doing — so anyone arriving
    // through them finished with an empty symptom list and a home page with
    // every symptom-keyed card switched off. Not because she tracks nothing,
    // because she was never asked.
    for (final step in const ['_buildTtcStep7', '_buildPostpartumStep7']) {
      expect(wizard.contains(step), isTrue, reason: '$step must exist');
      expect(wizard.contains('$step()'), isTrue,
          reason: '$step must be registered in steps.addAll, not just defined');
    }

    // Each branch's fourth step must require an answer, as the others do.
    // Whitespace is collapsed first so the check does not depend on how the
    // validation block happens to be wrapped.
    final flat = wizard.replaceAll(RegExp(r'\s+'), ' ');
    for (final anchor in const [
      "ttc_treatment'] != null; "
          'if (branchStep == 3) return _profile.symptoms.isNotEmpty;',
      "postpartum_feeding'] != null; "
          'if (branchStep == 2) return _profile.goals.isNotEmpty; '
          'if (branchStep == 3) return _profile.symptoms.isNotEmpty;',
    ]) {
      expect(flat.contains(anchor), isTrue,
          reason: 'the new symptoms step must be validated, not just shown');
    }
  });

  test('the change-your-answers-later dialog asks the same things', () {
    // Onboarding is not the only way these answers get set. The stage
    // questionnaire is the path for changing them later, and it mirrored the
    // old branch structure: TTC, postpartum and reproductive years collected
    // goals and a treatment choice and never asked about symptoms. New signups
    // got the questions; an existing user re-answering through settings did
    // not, so the fix would have reached no one already using the app.
    final dialog = read('lib/features/home/widgets/stage_questionnaire_dialog.dart');
    final keywords = dashboardKeywords();

    // Every symptoms step in the dialog, found by the set it writes into
    // rather than by name, so a new branch is covered the day it is added.
    final blocks = RegExp(r'selectedSet: _selectedSymptoms,\s*options: \[([^\]]*)\]')
        .allMatches(dialog)
        .map((m) => m[1]!)
        .toList();

    expect(blocks.length, greaterThanOrEqualTo(6),
        reason: 'reproductive years, TTC and postpartum must each ask, '
            'alongside the branches that already did');

    for (final block in blocks) {
      final options = RegExp(r'"([^"]+)"')
          .allMatches(block)
          .map((m) => m[1]!.toLowerCase())
          .toList();
      expect(options, isNotEmpty);

      final orphans = options
          .where((o) => !keywords.any((k) =>
              o.contains(k) || k.split(RegExp(r'[^a-z0-9]+')).contains(o)))
          .toList();

      expect(orphans, isEmpty,
          reason: 'the dialog asks these but they change nothing: '
              '${orphans.join(", ")}');
    }

    // And each new step must be required, as the existing symptom steps are.
    final flat = dialog.replaceAll(RegExp(r'\s+'), ' ');
    for (final anchor in const [
      "contraception_choice'] != null; "
          'if (_currentStep == 4) return _selectedSymptoms.isNotEmpty;',
      "ttc_treatment'] != null; "
          'if (_currentStep == 3) return _selectedSymptoms.isNotEmpty;',
      "postpartum_feeding'] != null; "
          'if (_currentStep == 2) return _selectedGoals.isNotEmpty; '
          'if (_currentStep == 3) return _selectedSymptoms.isNotEmpty;',
    ]) {
      expect(flat.contains(anchor), isTrue,
          reason: 'the dialog step must be validated, not just shown');
    }
  });
}
