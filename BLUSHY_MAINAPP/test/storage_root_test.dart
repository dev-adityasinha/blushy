import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/core/storage.dart';

/// Regression for the Android failure seen on device:
///   FileSystemException: Cannot open file, path = 'usr_..._user_profile.json'
///   (OS Error: Read-only file system, errno = 30)
///
/// Storage keys are bare filenames. Without a root they resolve against the
/// process working directory, which on Android is `/`, so every write failed
/// and the app silently kept everything in memory only.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('blushy_storage_root_');
    BlushyStorage.storageRoot = tempDir.path;
  });

  tearDown(() {
    BlushyStorage.storageRoot = null;
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  // A global key: private keys are namespaced per user and skipped entirely
  // when nobody is signed in, so they cannot exercise the path logic.
  test('a write lands inside the configured root, not the working directory', () {
    BlushyStorage.write('coach_first_launch.json', {'value': 42});

    final written = tempDir
        .listSync()
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.endsWith('coach_first_launch.json'))
        .toList();

    expect(written, isNotEmpty,
        reason: 'the file must be written under the root, not relative to cwd');
    expect(BlushyStorage.read('coach_first_launch.json')['value'], 42);
  });

  test('init leaves an already-configured root alone', () async {
    // Tests set their own isolated directory; init must not replace it, or
    // concurrent test processes would collide in one shared location again.
    final before = BlushyStorage.storageRoot;
    await BlushyStorage.init();
    expect(BlushyStorage.storageRoot, before);
  });

  test('the resolved path is absolute, which is what the read-only failure needed', () {
    BlushyStorage.write('generic_discover_cache.json', {'ok': true});
    final file = tempDir
        .listSync()
        .whereType<File>()
        .firstWhere((f) => f.uri.pathSegments.last.endsWith('generic_discover_cache.json'));
    expect(
      file.path.startsWith(tempDir.path),
      isTrue,
      reason: 'a relative path is what fails against / on Android',
    );
  });
}
