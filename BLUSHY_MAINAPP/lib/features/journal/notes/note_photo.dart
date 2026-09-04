import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../services/html_file_helper.dart';

/// Picking a photo to use as a page background.
///
/// The image travels inside the entry as base64, the way the journal already
/// carries photos and voice notes. That is what makes it work on web and
/// survive a reinstall, and it is also why it is shrunk hard first: a phone
/// photo is several megabytes and base64 adds a third again, which would put
/// a multi-megabyte string in every entry and in every sync of it.
class NotePhoto {
  const NotePhoto._();

  /// Narrower than the journal's own photo limit.
  ///
  /// A background is behind a panel and mostly covered, so detail there is
  /// paid for and never seen.
  static const int maxWidth = 720;

  /// The most a stored background may weigh, encoded.
  ///
  /// A cap rather than a hope: an entry is read and written whole, so one
  /// oversized background makes every save of that note slow.
  static const int maxEncodedBytes = 900 * 1024;

  /// Picks an image and returns it base64-encoded, or null if cancelled.
  ///
  /// Returns null on a failure too. A background is decoration: it is not
  /// worth an error dialog, and the caller shows one message either way.
  static Future<String?> pick() async {
    PickedBlushyFile? picked;
    try {
      picked = await pickFileFromDevice(accept: 'image/*');
    } catch (_) {
      return null;
    }
    if (picked == null) return null;

    try {
      final shrunk = await _shrink(Uint8List.fromList(picked.bytes));
      if (shrunk == null) return null;
      final encoded = base64Encode(shrunk);
      // Still too big after shrinking: a very tall panorama can be under the
      // width limit and enormous. Better to refuse than to store it.
      if (encoded.length > maxEncodedBytes) return null;
      return encoded;
    } catch (_) {
      return null;
    }
  }

  /// Decodes a stored background, or null if it cannot be read.
  ///
  /// Never throws. A background that fails to decode costs the decoration,
  /// not the note.
  static Uint8List? decode(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return null;
    try {
      final bytes = base64Decode(encoded);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  /// Shrinks to at most [maxWidth] across, leaving smaller images alone rather
  /// than upscaling them into a bigger file.
  static Future<Uint8List?> _shrink(Uint8List original) async {
    final probe = await ui.instantiateImageCodec(original);
    final frame = await probe.getNextFrame();
    final width = frame.image.width;
    frame.image.dispose();

    final codec = width <= maxWidth
        ? await ui.instantiateImageCodec(original)
        : await ui.instantiateImageCodec(original, targetWidth: maxWidth);

    final resized = await codec.getNextFrame();
    final data =
        await resized.image.toByteData(format: ui.ImageByteFormat.png);
    resized.image.dispose();

    return data?.buffer.asUint8List();
  }
}
