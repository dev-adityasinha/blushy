import 'package:flutter/material.dart';
import '../../../services/journal_storage.dart';
import '../repository/journal_repository.dart';
import '../core/event_bus/journal_event_bus.dart';
import '../core/scheduler/background_task_scheduler.dart';
import '../core/crash_recovery/crash_recovery_service.dart';

class JournalController extends ChangeNotifier {
  final JournalRepository repository = JournalRepository();
  final JournalEventBus eventBus = JournalEventBus();
  final BackgroundTaskScheduler scheduler = BackgroundTaskScheduler();
  final CrashRecoveryService crashRecovery = CrashRecoveryService();

  List<LocalJournalEntry> _entries = [];
  bool _isLoading = false;

  List<LocalJournalEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;

  Future<void> loadEntries(String userId) async {
    _isLoading = true;
    notifyListeners();
    _entries = await repository.getAllEntries(userId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveEntry(String userId, LocalJournalEntry entry) async {
    await repository.addOrUpdateEntry(userId, entry);
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
      eventBus.publish(EntryEditedEvent(entryId: entry.id));
    } else {
      _entries.insert(0, entry);
      eventBus.publish(EntryCreatedEvent(entryId: entry.id, title: entry.title));
    }

    scheduler.enqueue(
      taskId: 'save_${entry.id}',
      priority: TaskPriority.critical,
      action: () async {},
    );

    crashRecovery.clearDraft();
    notifyListeners();
  }

  Future<void> deleteEntry(String userId, String entryId) async {
    await repository.deleteEntry(userId, entryId);
    _entries.removeWhere((e) => e.id == entryId);
    eventBus.publish(EntryDeletedEvent(entryId: entryId));
    notifyListeners();
  }
}
