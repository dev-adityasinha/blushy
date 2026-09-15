import 'dart:io';
import 'dart:math';

import 'package:blushy_life_app/core/storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Points BlushyStorage at a directory unique to this test process.
///
/// Without it, file-backed storage resolves relative to the working directory,
/// so every concurrently running test file reads and writes the same JSON files
/// in the project root. That raced: the storage-isolation security test
/// intermittently observed another suite's data and failed.
///
/// Call once at the top of `main()` in any suite that touches BlushyStorage.
void useIsolatedStorage() {
  late final Directory dir;

  setUpAll(() {
    final suffix = '${pid}_${Random().nextInt(1 << 32)}';
    dir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}blushy_test_$suffix')
      ..createSync(recursive: true);
    BlushyStorage.storageRoot = dir.path;
  });

  setUp(() {
    // Each test starts from an empty store rather than inheriting the last one.
    BlushyStorage.clearMemoryCache();
    if (dir.existsSync()) {
      for (final entity in dir.listSync()) {
        if (entity is File) {
          try {
            entity.deleteSync();
          } catch (_) {}
        }
      }
    }
  });

  tearDownAll(() {
    BlushyStorage.storageRoot = null;
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {}
  });
}
