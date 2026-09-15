import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A retry is only correct when sending the request twice leaves the same
/// result as sending it once.
///
/// The cold-start fix retried **every** verb on a timeout. That is safe while
/// the instance is asleep — the request never arrived — but once it is awake
/// and merely slow, a `POST /posts` the server had already accepted was sent
/// again and published the post twice. The 503 handling would have repeated
/// that mistake.
///
/// Only two write routes dedupe: events and period logs, both via
/// `Idempotency-Key`. Everything else must not be repeated.
void main() {
  final source =
      File('lib/services/api_contract_client.dart').readAsStringSync();

  test('every verb declares whether it may be repeated', () {
    for (final call in const [
      "repeatable: _isRepeatable('GET')",
      "repeatable: _isRepeatable('POST', idempotencyKey: idempotencyKey)",
      "repeatable: _isRepeatable('PUT')",
      "repeatable: _isRepeatable('PATCH')",
      "repeatable: _isRepeatable('DELETE')",
    ]) {
      expect(source.contains(call), isTrue, reason: 'missing: $call');
    }

    expect(source.contains('required bool repeatable'), isTrue,
        reason: 'the flag must be required, so a new verb cannot forget it');
  });

  test('a POST is repeatable only when it carries an idempotency key', () {
    expect(
        RegExp(r"case 'POST':\s*\n\s*return idempotencyKey != null && idempotencyKey\.isNotEmpty;")
            .hasMatch(source),
        isTrue,
        reason: 'otherwise a retried post creates a second post');
  });

  test('PATCH and DELETE are never repeated', () {
    // PATCH may be a relative change; a repeated DELETE reports 404 for work
    // that succeeded.
    expect(RegExp(r"default:\s*\n\s*return false;").hasMatch(source), isTrue);
  });

  test('the timeout retry is gated, not unconditional', () {
    // This is the regression: the cold-start fix retried everything.
    expect(source.contains('if (!repeatable) rethrow;'), isTrue,
        reason: 'a timed-out write the server accepted must not be resent');
  });

  test('a 503 is retried only where repeating is safe', () {
    expect(source.contains('if (response.statusCode == 503 && repeatable)'), isTrue,
        reason: 'busy is worth retrying, but not at the cost of duplicates');
  });

  test('the wait is bounded and jittered', () {
    // Unbounded, the caller waits on a number the app did not choose.
    // Unjittered, every client saturated together returns together.
    expect(source.contains('seconds.clamp(1, 10)'), isTrue);
    expect(source.contains('_random.nextInt(400)'), isTrue);
  });
}
