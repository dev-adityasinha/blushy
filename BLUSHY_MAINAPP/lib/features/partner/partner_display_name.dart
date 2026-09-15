/// How a partner is named in the interface.
///
/// The portal showed an address where a name belongs -- "codeaviii@gmail.com's
/// Portal" -- because the connection payload carried only `partnerEmail`. The
/// server now sends `partnerName` from the name the partner chose, so the
/// address is a last resort rather than the usual answer.
///
/// Kept in one place because four screens name the same person and were each
/// deciding it differently: two stripped the domain, two printed the whole
/// address, and none of them looked at the field that actually holds the name.
///
/// The email's local part is used before giving up entirely: it is not a name,
/// but "codeaviii" reads as a person where the full address reads as a record,
/// and it is what partner_home already did. Of the 176 people currently in a
/// connection, 174 have a real name, so this is the rare path.
String partnerDisplayName(
  Map<String, dynamic>? connection, {
  String fallback = 'Partner',
}) {
  if (connection == null) return fallback;

  String? pick(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  // What the partner calls themselves, as the server now supplies it.
  final named = pick(connection['partnerName']) ??
      pick((connection['partner'] as Map?)?['displayName']);
  if (named != null) return named;

  final email = pick(connection['partnerEmail']);
  if (email != null) {
    final at = email.indexOf('@');
    final local = at > 0 ? email.substring(0, at) : email;
    if (local.isNotEmpty) return local;
  }

  return fallback;
}
