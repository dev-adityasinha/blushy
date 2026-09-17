import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Screen documents belong to the account, not to one installation.
///
/// Thirteen keys were written with `BlushyStorage` and nowhere else: the
/// period kit, the school bag, body changes, what she is noticing, her life
/// mode, her treatments, support circle, logged signals and health records,
/// her reflections, the letters between partners, the TTC task list and the
/// last pregnancy check-in. All of it was invisible on the web, absent for a
/// clinician, and gone with a reinstall -- and `stage4_treatments` is
/// medication history.
///
/// They go through `UserStateStore` now: the server is the record, the device
/// keeps a mirror so screens can still read synchronously during a build and
/// still show something with no signal.
void main() {
  const keys = [
    'stage1_period_kit',
    'stage2_school_bag',
    'stage2_body_changes',
    'stage3_noticings',
    'stage3_life_mode',
    'stage4_treatments',
    'stage4_support_circle',
    'stage4_logged_signals',
    'stage4_health_records',
    'mstudio_reflections',
    'partner_letters',
    'ttc_partner_tasks',
    'pregnancy_last_checkin',
  ];

  List<File> dartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('no screen document is written straight to the device any more', () {
    final offenders = <String>[];
    for (final f in dartFiles()) {
      if (f.path.replaceAll(r'\', '/').endsWith('services/user_state_store.dart')) continue;
      final src = f.readAsStringSync();
      for (final k in keys) {
        if (src.contains("BlushyStorage.read('$k") || src.contains("BlushyStorage.write('$k")) {
          offenders.add('${f.path} -> $k');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'still device-only:\n${offenders.join('\n')}');
  });

  test('each one goes through the store instead', () {
    final all = dartFiles().map((f) => f.readAsStringSync()).join(String.fromCharCode(10));
    for (final k in keys) {
      final used = all.contains("UserStateStore.read('$k')") ||
          all.contains("UserStateStore.write('$k'");
      expect(used, isTrue, reason: '$k is not wired to the store');
    }
  });

  test('the store writes the mirror before the network, and does not block', () {
    final store = File('lib/services/user_state_store.dart').readAsStringSync();
    final start = store.indexOf('static void write(');
    expect(start, greaterThan(-1));

    final body = store.substring(start, start + 500);
    // The mirror first: the screen has already shown the change, and a refused
    // request must not undo it on screen.
    expect(body.indexOf('BlushyStorage.write'), lessThan(body.indexOf('_push(')));
    expect(body, contains('unawaited(_push('));
  });

  test('reads stay synchronous, so build() is unchanged', () {
    final store = File('lib/services/user_state_store.dart').readAsStringSync();
    expect(store, contains('static Map<String, dynamic> read(String key)'),
        reason: 'an async read would have meant rewriting every screen');
  });

  test('the account copy is pulled at startup and again at sign-in', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('UserStateStore.hydrate()'));

    // main() runs before there is a session, so a fresh install finds nothing
    // there; signing in is the first moment the fetch can work.
    final state = File('lib/core/state.dart').readAsStringSync();
    final start = state.indexOf('void setAuthenticated(');
    expect(start, greaterThan(-1));
    expect(state.substring(start, start + 700), contains('UserStateStore.hydrate()'));
  });

  test('the server scopes every document to the token', () {
    final controller =
        File('backend/src/controllers/userStateController.js').readAsStringSync();
    expect(controller, contains('req.user?.userId'));
    expect(controller.contains('req.body?.userId'), isFalse,
        reason: 'the body must never be able to name an account');
    expect(controller, contains('256 * 1024'), reason: 'unbounded documents');
  });

  test('deleting an account takes the documents with it', () {
    final deletion =
        File('backend/src/services/accountDeletionService.js').readAsStringSync();
    expect(deletion, contains("['user_state', ['user_id']]"));
  });
}
