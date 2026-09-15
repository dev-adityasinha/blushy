import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

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

/// Opens the browser file picker and reads the chosen file into memory.
///
/// Completes with null on cancel, on a read error, or if the browser hands
/// back something other than an ArrayBuffer — the caller cannot tell those
/// apart, and in every case there is no file to work with.
Future<PickedBlushyFile?> pickFileFromDevice({required String accept}) async {
  final completer = Completer<PickedBlushyFile?>();

  final uploadInput = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..multiple = false;

  uploadInput.onchange = ((web.Event _) {
    final files = uploadInput.files;
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final file = files.item(0);
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final reader = web.FileReader();

    reader.onloadend = ((web.Event _) {
      if (completer.isCompleted) return;
      final result = reader.result;
      if (result.isA<JSArrayBuffer>()) {
        completer.complete(
          PickedBlushyFile(
            name: file.name,
            bytes: (result as JSArrayBuffer).toDart.asUint8List(),
            mimeType: file.type.isNotEmpty ? file.type : 'application/octet-stream',
            size: file.size,
          ),
        );
      } else {
        completer.complete(null);
      }
    }).toJS;

    reader.onerror = ((web.Event _) {
      if (!completer.isCompleted) completer.complete(null);
    }).toJS;

    reader.readAsArrayBuffer(file);
  }).toJS;

  uploadInput.click();

  return completer.future;
}
