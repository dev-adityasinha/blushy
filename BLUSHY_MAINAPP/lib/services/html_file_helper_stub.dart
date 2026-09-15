import 'package:file_picker/file_picker.dart';

/// Native (Android / iOS / desktop) half of the file picker. The web half lives
/// in `html_file_helper_web.dart`; `html_file_helper.dart` picks one.

class PickedBlushyFile {
  final String name;
  final List<int> bytes;
  final String mimeType;
  final int size;

  const PickedBlushyFile({
    required this.name,
    required this.bytes,
    required this.mimeType,
    required this.size,
  });

  bool get isPdf => name.toLowerCase().endsWith('.pdf') || mimeType == 'application/pdf';
  bool get isImage => mimeType.startsWith('image/') || RegExp(r'\.(jpg|jpeg|png|webp|gif|bmp)$', caseSensitive: false).hasMatch(name);

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

const Map<String, String> _mimeByExtension = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'bmp': 'image/bmp',
  'heic': 'image/heic',
  'heif': 'image/heif',
};

/// Turns a browser `accept` string into the extension list the native picker
/// wants, so both platforms are driven by the same call site.
///
/// `image/*` has no single extension, so it expands to the image types the
/// backend accepts.
List<String> extensionsFromAccept(String accept) {
  final extensions = <String>{};
  for (final rawToken in accept.split(',')) {
    final token = rawToken.trim().toLowerCase();
    if (token.isEmpty) continue;
    if (token == 'image/*') {
      extensions.addAll(['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif']);
    } else if (token.startsWith('.')) {
      extensions.add(token.substring(1));
    } else if (token.contains('/')) {
      final subtype = token.split('/').last;
      if (subtype != '*') extensions.add(subtype);
    }
  }
  return extensions.toList();
}

Future<PickedBlushyFile?> pickFileFromDevice({required String accept}) async {
  final extensions = extensionsFromAccept(accept);

  final result = await FilePicker.platform.pickFiles(
    // The caller works with bytes, and on Android a content:// URI is not a
    // readable path, so the data is requested up front.
    withData: true,
    type: extensions.isEmpty ? FileType.any : FileType.custom,
    allowedExtensions: extensions.isEmpty ? null : extensions,
  );

  if (result == null || result.files.isEmpty) return null;

  final file = result.files.first;
  final bytes = file.bytes;
  if (bytes == null) return null;

  final extension = (file.extension ?? '').toLowerCase();

  return PickedBlushyFile(
    name: file.name,
    bytes: bytes,
    mimeType: _mimeByExtension[extension] ?? 'application/octet-stream',
    size: file.size,
  );
}
