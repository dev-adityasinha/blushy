import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/services/html_file_helper_stub.dart';

/// The web picker takes a browser `accept` string; the native picker takes a
/// list of extensions. Both platforms are driven from the same call site, so
/// the translation between them has to be right.
void main() {
  group('accept string to native extensions', () {
    test('a bare extension list is passed through without dots', () {
      expect(extensionsFromAccept('.pdf,application/pdf'), containsAll(['pdf']));
    });

    test('image/* expands, because a wildcard has no single extension', () {
      final result = extensionsFromAccept('image/*,.jpg,.jpeg,.png,.webp');
      expect(result, containsAll(['jpg', 'jpeg', 'png', 'webp']));
      expect(result, isNot(contains('*')));
      expect(result, isNot(contains('image/*')));
    });

    test('duplicates collapse, so the picker is not handed the same type twice', () {
      final result = extensionsFromAccept('.jpg,.jpg,image/jpeg');
      expect(result.where((e) => e == 'jpg').length, 1);
    });

    test('an empty accept yields no filter rather than an impossible one', () {
      expect(extensionsFromAccept(''), isEmpty);
      expect(extensionsFromAccept('   '), isEmpty);
    });

    test('the real call sites both produce usable filters', () {
      // Verbatim from sia_screen.dart.
      expect(extensionsFromAccept('.pdf,application/pdf'), isNotEmpty);
      expect(extensionsFromAccept('image/*,.jpg,.jpeg,.png,.webp'), isNotEmpty);
    });
  });
}
