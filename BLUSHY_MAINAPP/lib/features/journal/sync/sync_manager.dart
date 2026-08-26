import 'package:flutter/material.dart';

class SyncPendingChange {
  final String entryId;
  final String action; // 'create', 'update', 'delete'
  final DateTime timestamp;

  SyncPendingChange({
    required this.entryId,
    required this.action,
    required this.timestamp,
  });
}

class SyncManager extends ChangeNotifier {
  final List<SyncPendingChange> _offlineQueue = [];
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  List<SyncPendingChange> get offlineQueue => List.unmodifiable(_offlineQueue);
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  void enqueueChange(String entryId, String action) {
    _offlineQueue.add(SyncPendingChange(
      entryId: entryId,
      action: action,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
    triggerSync();
  }

  Future<void> triggerSync() async {
    if (_isSyncing || _offlineQueue.isEmpty) return;

    _isSyncing = true;
    notifyListeners();

    // Simulate conflict resolution and sync execution
    await Future.delayed(const Duration(milliseconds: 1200));

    _offlineQueue.clear();
    _isSyncing = false;
    _lastSyncTime = DateTime.now();
    notifyListeners();
  }
}
