import '../../../../core/storage.dart';

class CrashRecoveryService {
  static const String _draftKey = 'blushy_journal_draft_autosave.json';
  int _editCount = 0;
  DateTime _lastSaveTime = DateTime.now();

  /// Save transient draft every 10 seconds or 30 edits
  void notifyEdit(Map<String, dynamic> draftJson) {
    _editCount++;
    final now = DateTime.now();

    if (_editCount >= 30 || now.difference(_lastSaveTime).inSeconds >= 10) {
      _saveDraft(draftJson);
    }
  }

  void _saveDraft(Map<String, dynamic> draftJson) {
    try {
      BlushyStorage.write(_draftKey, {
        'timestamp': DateTime.now().toIso8601String(),
        'draft': draftJson,
      });
      _editCount = 0;
      _lastSaveTime = DateTime.now();
    } catch (_) {}
  }

  Map<String, dynamic>? checkUnsavedDraft() {
    try {
      final data = BlushyStorage.read(_draftKey);
      if (data.containsKey('draft')) {
        return Map<String, dynamic>.from(data['draft'] as Map);
      }
    } catch (_) {}
    return null;
  }

  void clearDraft() {
    try {
      BlushyStorage.write(_draftKey, {});
      _editCount = 0;
    } catch (_) {}
  }
}
