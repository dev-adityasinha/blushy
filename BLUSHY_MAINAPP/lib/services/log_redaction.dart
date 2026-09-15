/// What may be written to the device log about a response body.
///
/// `debugPrint` reaches logcat. On many devices that is readable by other
/// processes and by anyone with the phone plugged in, so a whole response body
/// is never the right thing to log. Four lines used to log one:
///
///   * the signup response, which carries `code`, `otp` and `verificationLink`
///     whenever the backend has its delivery fallback on -- the verification
///     code for an address, in a log;
///   * the onboarding response, whose values are the answers themselves: life
///     stage, date of birth, symptoms;
///   * both Docsy chat responses, which are the model's reply about her health.
///
/// Key names are what those lines were actually for -- they diagnose a shape
/// mismatch between client and server. The values were never needed for that.
///
/// Kept in one place rather than copied per service: a second copy is how the
/// first one stops being updated.
library;

/// The shape of a response body, with none of its values.
String shapeOf(dynamic body) {
  if (body is Map) {
    return body.isEmpty ? 'empty map' : 'keys: ${body.keys.join(', ')}';
  }
  if (body is List) return 'list of ${body.length}';
  // An un-decoded body arrives as a String. Its length still says whether the
  // server sent something or nothing, which is what the caller wanted to know.
  if (body is String) return 'string of ${body.length} chars';
  return body.runtimeType.toString();
}
