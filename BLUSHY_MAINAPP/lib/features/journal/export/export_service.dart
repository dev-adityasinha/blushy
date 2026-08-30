import '../../../services/journal_storage.dart';

enum ExportFormat { pdf, markdown, json, html }
enum ExportLayoutStyle { classicNotebook, hardcoverScrapbook, minimal, timeline, magazine, photoAlbum }

class ExportHeaderMetadata {
  final String formatVersion;
  final String schemaVersion;
  final String exportDate;
  final String appVersion;
  final String locale;

  ExportHeaderMetadata({
    this.formatVersion = '1.0',
    this.schemaVersion = 'v2',
    required this.exportDate,
    this.appVersion = '1.0.0',
    this.locale = 'en_US',
  });

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'schemaVersion': schemaVersion,
        'exportDate': exportDate,
        'appVersion': appVersion,
        'locale': locale,
      };
}

class ExportService {
  String exportEntry({
    required LocalJournalEntry entry,
    required ExportFormat format,
    required ExportLayoutStyle style,
  }) {
    final header = ExportHeaderMetadata(exportDate: DateTime.now().toIso8601String());

    switch (format) {
      case ExportFormat.markdown:
        return '''
---
${header.toJson().entries.map((e) => '${e.key}: "${e.value}"').join('\n')}
layout_style: "${style.name}"
---

# ${entry.title}
*Date: ${entry.date}* | *Mood: ${entry.moodKey}*

${entry.body}
''';

      case ExportFormat.html:
        return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>${entry.title}</title>
  <!-- Export Metadata: ${header.toJson()} -->
  <style>
    body { font-family: 'Playfair Display', Georgia, serif; background: #FDFBF7; padding: 40px; color: #2D3748; }
    h1 { color: #D97706; }
    .card { background: white; padding: 24px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
  </style>
</head>
<body>
  <div class="card">
    <h1>${entry.title}</h1>
    <p><em>${entry.date}</em></p>
    <div>${entry.body}</div>
  </div>
</body>
</html>
''';

      case ExportFormat.json:
        return '''
{
  "header": ${header.toJson()},
  "layoutStyle": "${style.name}",
  "entry": ${entry.toJson()}
}
''';

      case ExportFormat.pdf:
        return 'PDF Export Document generated for ${entry.title} [Style: ${style.name}]';
    }
  }
}
