import 'package:blushy_life_app/features/home/symptom_categories.dart';
import 'package:flutter_test/flutter_test.dart';

/// A selection is a group and a word, not a word.
///
/// The words on the sheet are not unique: "Low" is mood, energy and stress;
/// "Medium" is energy and flow; "None" is pain and movement. A flat set of
/// words could not hold energy "Low" and stress "Low" at once, and stored a
/// flow of "Medium" as an energy of "Medium" -- the first group that owns
/// the word -- so the flow row stayed "Not Logged Today". Every selection
/// carries its group now.
void main() {
  test('the words really do collide, which is why the key exists', () {
    final owners = <String, List<String>>{};
    for (final c in SymptomCategories.all) {
      for (final o in c.options) {
        owners.putIfAbsent(o, () => []).add(c.id);
      }
    }
    expect(owners['Low'], containsAll(['mood', 'energy', 'stress']));
    expect(owners['Medium'], containsAll(['energy', 'flow']));
    expect(owners['None'], containsAll(['pain', 'movement']));
  });

  test('a qualified key names its group and its word', () {
    final key = SymptomKey.qualify('flow', 'Medium');
    expect(key, 'flow/Medium');
    expect(SymptomKey.categoryId(key), 'flow');
    expect(SymptomKey.label(key), 'Medium');
    expect(SymptomKey.category(key)?.id, 'flow');
    expect(SymptomKey.category(key)?.metric, 'flow',
        reason: 'and so it stores under flow, not energy');
  });

  test('a bare word resolves to the first group that owns it', () {
    // The only reading a bare word ever had; kept so older callers and
    // stored lists still land somewhere.
    expect(SymptomKey.categoryId('Medium'), isNull);
    expect(SymptomKey.normalise('Medium'), 'energy/Medium');
    expect(SymptomKey.normalise('Cramps'), 'symptom/Cramps');
    expect(SymptomKey.normalise('flow/Medium'), 'flow/Medium',
        reason: 'already qualified: left alone');
  });

  test('a word no group owns keeps its bare form', () {
    expect(SymptomKey.normalise('Everything is fine'), 'Everything is fine');
    expect(SymptomKey.category('Everything is fine'), isNull);
  });

  test('a word with a colon in it is not mistaken for a key', () {
    // "Test: negative" is an ovulation-test option; the separator is the
    // slash, which no option contains.
    for (final c in SymptomCategories.all) {
      for (final o in c.options) {
        expect(o.contains(SymptomKey.separator), isFalse,
            reason: '"$o" would break as a key');
      }
    }
    expect(SymptomKey.label('ovulation_test/Test: negative'), 'Test: negative');
  });
}
