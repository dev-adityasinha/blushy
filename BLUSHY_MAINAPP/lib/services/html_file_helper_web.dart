import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

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
  final completer = Completer<PickedBlushyFile?>();
  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept = accept;
  uploadInput.multiple = false;
  uploadInput.click();

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();

      reader.onLoadEnd.listen((e) {
        final result = reader.result;
        if (result is Uint8List) {
          completer.complete(
            PickedBlushyFile(
              name: file.name,
              bytes: result,
              mimeType: file.type.isNotEmpty ? file.type : 'application/octet-stream',
              size: file.size,
            ),
          );
        } else if (result is List<int>) {
          completer.complete(
            PickedBlushyFile(
              name: file.name,
              bytes: result,
              mimeType: file.type.isNotEmpty ? file.type : 'application/octet-stream',
              size: file.size,
            ),
          );
        } else {
          completer.complete(null);
        }
      });

      reader.onError.listen((e) {
        completer.complete(null);
      });

      reader.readAsArrayBuffer(file);
    } else {
      completer.complete(null);
    }
  });

  return completer.future;
}
