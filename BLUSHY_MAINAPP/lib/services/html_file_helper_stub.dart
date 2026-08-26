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

Future<PickedBlushyFile?> pickFileFromDevice({required String accept}) async {
  return null;
}
