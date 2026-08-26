class PhoneNumberService {
  Future<bool> isValidInternational(String phoneNumber) async {
    final normalized = _clean(phoneNumber);
    final e164Pattern = RegExp(r'^\+[1-9]\d{7,14}$');
    return e164Pattern.hasMatch(normalized);
  }

  Future<String?> normalizeToE164(String phoneNumber) async {
    final normalized = _clean(phoneNumber);
    final e164Pattern = RegExp(r'^\+[1-9]\d{7,14}$');
    if (!e164Pattern.hasMatch(normalized)) {
      return null;
    }

    return normalized;
  }

  String _clean(String input) {
    return input.trim().replaceAll(RegExp(r'[\s\-().]'), '');
  }
}
