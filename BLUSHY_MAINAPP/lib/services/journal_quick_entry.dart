import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../features/journal/repository/journal_repository.dart';
import 'api_auth_service.dart';
import 'journal_storage.dart';

/// Saves a short reflection into the journal from outside the journal screen.
///
/// Voice reflections used to call `BlushyOSState.addJournal`, which appends to
/// a list whose only reader lives in `lib/presentation/` -- code nothing
/// imports any more. The reflection was written to disk and then displayed
/// nowhere, which looked exactly like a save that had failed.
///
/// This writes to the store the journal screen actually reads, and pushes the
/// day to the account so the entry survives a reinstall.
class JournalQuickEntry {
  const JournalQuickEntry._();

  /// The suffix the journal screen has always used. It is a legacy value --
  /// `BlushyStorage` already namespaces per authenticated user -- but changing
  /// it here would write to a different key than the screen reads.
  static const String _storageUser = 'default_user';

  /// Lets tests turn off the account sync.
  ///
  /// `save` fires the push without awaiting it, so in a test it races the
  /// assertions and lands only if a dev server happens to be listening. That
  /// made the local-storage tests depend on the machine they ran on.
  static bool syncToAccount = true;

  /// Distinguishes entries created within the same millisecond.
  static int _sequence = 0;
  static int _nextSequence() => ++_sequence;

  static String _dateKey(DateTime when) =>
      '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}';

  /// Appends [text] as a new journal entry and returns whether it was stored.
  static Future<bool> save({
    required String text,
    required String title,
    String? moodKey,
    DateTime? when,
  }) async {
    final body = text.trim();
    if (body.isEmpty) return false;

    final at = when ?? DateTime.now();
    // Millisecond precision alone is not unique: two reflections saved in the
    // same millisecond produced the same id, and addOrUpdateEntry then treated
    // the second as an edit of the first -- silently losing one.
    final id = 'reflection_${at.millisecondsSinceEpoch}_${_nextSequence()}';

    // The loader skips any entry with empty rawJson, so the text has to be a
    // real scrapbook item rather than only living in `body`.
    final rawJson = jsonEncode({
      'themeName': 'Cream Paper',
      'fontName': 'Handwriting',
      'templateName': 'Daily Reflection',
      'items': [
        {
          'id': 'text_${at.millisecondsSinceEpoch}',
          'type': 'text',
          'content': body,
          'positionDx': 40.0,
          'positionDy': 120.0,
          'scale': 1.0,
          'rotation': 0.0,
          'zIndex': 0,
          'customColor': null,
        },
      ],
    });

    final entry = LocalJournalEntry(
      id: id,
      date: _dateKey(at),
      title: title,
      body: body,
      moodKey: moodKey ?? 'neutral',
      dateTime: at.toIso8601String(),
      rawJson: rawJson,
    );

    final repository = JournalRepository();
    try {
      await repository.addOrUpdateEntry(_storageUser, entry);
    } catch (error) {
      debugPrint('[journal] could not store reflection: $error');
      return false;
    }

    // Read back before reporting success. The journal key is private, and
    // BlushyStorage skips private writes when there is no authenticated
    // session while JournalStorage swallows the failure -- so without this
    // check the caller is told the reflection was saved when nothing was
    // written at all.
    final stored = await repository.getAllEntries(_storageUser);
    if (!stored.any((e) => e.id == id)) {
      debugPrint('[journal] reflection was not persisted; refusing to report success');
      return false;
    }

    // Best effort, and deliberately after the local write: the entry is saved
    // either way, and the server copy is what survives a reinstall.
    if (syncToAccount) {
      unawaited(_pushDay(repository, entry.date));
    }
    return true;
  }

  /// Sends every entry for one day.
  ///
  /// The server replaces a day wholesale, so pushing only the new entry would
  /// delete the others already written on that date.
  static Future<void> _pushDay(JournalRepository repository, String date) async {
    try {
      final all = await repository.getAllEntries(_storageUser);
      final forDay = all.where((e) => e.date == date).map((e) => e.toJson()).toList();
      if (forDay.isEmpty) return;

      await ApiAuthService().saveJournalForDate(
        entryDate: date,
        entries: forDay,
        summary: forDay.length == 1
            ? (forDay.first['title']?.toString() ?? '')
            : '${forDay.length} entries',
      );
    } catch (error) {
      debugPrint('[journal] could not sync reflection to the account: $error');
    }
  }
}
