import 'package:flutter/foundation.dart';

/// Decides what actually leaves the app when a doctor summary is saved,
/// shared or copied (spec section 18).
///
/// Kept out of the widget because this is the point where the user's removals
/// are honoured. If it is wrong, information the user explicitly took out
/// reaches a clinician, a message thread or the clipboard. That deserves tests
/// that do not require building a screen.
@immutable
class DoctorSummaryComposer {
  /// Sections exactly as the preview endpoint returned them.
  final List<Map<String, dynamic>> sections;

  /// Entries the user removed, keyed `"sectionKey::index"` against the
  /// original preview ordering.
  final Set<String> removed;

  final List<String> questions;
  final String fromLabel;
  final String toLabel;
  final String? disclaimer;

  const DoctorSummaryComposer({
    required this.sections,
    this.removed = const {},
    this.questions = const [],
    required this.fromLabel,
    required this.toLabel,
    this.disclaimer,
  });

  static const String defaultDisclaimer =
      'Prepared from what you logged in Blushy. This is a record of self-reported '
      'information and app-generated observations, not a diagnosis.';

  static String entryKey(String sectionKey, int index) => '$sectionKey::$index';

  static String provenanceLabel(String? provenance) {
    switch (provenance) {
      case 'user_reported':
        return 'What you logged';
      case 'app_generated':
        return 'What the app noticed';
      default:
        return 'From your records';
    }
  }

  static String _itemText(dynamic item) {
    if (item is Map) return item['text']?.toString() ?? '';
    return item.toString();
  }

  /// The sections with removed entries stripped out. A section left with no
  /// entries is dropped entirely rather than exported as an empty heading.
  List<Map<String, dynamic>> get keptSections {
    final out = <Map<String, dynamic>>[];

    for (final raw in sections) {
      final section = Map<String, dynamic>.from(raw);
      final key = section['key']?.toString() ?? '';
      final items = (section['items'] as List?) ?? const [];

      final kept = <dynamic>[];
      for (var i = 0; i < items.length; i++) {
        if (!removed.contains(entryKey(key, i))) kept.add(items[i]);
      }

      if (kept.isEmpty) continue;
      section['items'] = kept;
      out.add(section);
    }

    return out;
  }

  bool get isEmpty => keptSections.isEmpty;

  int get keptEntryCount =>
      keptSections.fold(0, (sum, s) => sum + ((s['items'] as List?)?.length ?? 0));

  /// Plain text for the share sheet and the clipboard.
  ///
  /// Provenance labels and the disclaimer are always included: once this text
  /// is in a message or a notes app, they are the only thing distinguishing a
  /// self-reported symptom from an app-generated observation.
  String toPlainText() {
    final buffer = StringBuffer()
      ..writeln('Blushy summary')
      ..writeln('$fromLabel to $toLabel')
      ..writeln();

    for (final section in keptSections) {
      final title = section['title']?.toString() ?? section['key']?.toString() ?? '';
      buffer.writeln('$title (${provenanceLabel(section['provenance']?.toString())})');
      for (final item in (section['items'] as List? ?? const [])) {
        final text = _itemText(item);
        if (text.isNotEmpty) buffer.writeln('  - $text');
      }
      buffer.writeln();
    }

    if (questions.isNotEmpty) {
      buffer.writeln('Questions to ask');
      for (final question in questions) {
        buffer.writeln('  - $question');
      }
      buffer.writeln();
    }

    buffer.writeln(disclaimer ?? defaultDisclaimer);
    return buffer.toString();
  }
}
