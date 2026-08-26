import 'dart:async';

abstract class JournalEvent {
  final DateTime timestamp;
  JournalEvent() : timestamp = DateTime.now();
}

class EntryCreatedEvent extends JournalEvent {
  final String entryId;
  final String title;
  EntryCreatedEvent({required this.entryId, required this.title});
}

class EntryEditedEvent extends JournalEvent {
  final String entryId;
  EntryEditedEvent({required this.entryId});
}

class EntryDeletedEvent extends JournalEvent {
  final String entryId;
  EntryDeletedEvent({required this.entryId});
}

class BackupCompletedEvent extends JournalEvent {
  final String backupId;
  final bool isSuccess;
  BackupCompletedEvent({required this.backupId, required this.isSuccess});
}

class SyncCompletedEvent extends JournalEvent {
  final int syncedCount;
  SyncCompletedEvent({required this.syncedCount});
}

class ThemeChangedEvent extends JournalEvent {
  final String themeName;
  ThemeChangedEvent({required this.themeName});
}

class TimeCapsuleUnlockedEvent extends JournalEvent {
  final String capsuleId;
  TimeCapsuleUnlockedEvent({required this.capsuleId});
}

class JournalEventBus {
  static final JournalEventBus _instance = JournalEventBus._internal();
  factory JournalEventBus() => _instance;
  JournalEventBus._internal();

  final StreamController<JournalEvent> _streamController = StreamController<JournalEvent>.broadcast();

  Stream<T> on<T extends JournalEvent>() {
    return _streamController.stream.where((event) => event is T).cast<T>();
  }

  void publish(JournalEvent event) {
    _streamController.add(event);
  }

  void dispose() {
    _streamController.close();
  }
}
