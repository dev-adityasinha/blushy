import 'dart:async';

enum TaskPriority { critical, high, medium, low, idle }

class ScheduledTask {
  final String id;
  final TaskPriority priority;
  final Future<void> Function() action;
  final DateTime queuedTime;

  ScheduledTask({
    required this.id,
    required this.priority,
    required this.action,
  }) : queuedTime = DateTime.now();
}

class BackgroundTaskScheduler {
  static final BackgroundTaskScheduler _instance = BackgroundTaskScheduler._internal();
  factory BackgroundTaskScheduler() => _instance;
  BackgroundTaskScheduler._internal();

  final List<ScheduledTask> _queue = [];
  bool _isProcessing = false;
  int _completedTaskCount = 0;

  int get pendingTaskCount => _queue.length;
  int get completedTaskCount => _completedTaskCount;

  void enqueue({required String taskId, required TaskPriority priority, required Future<void> Function() action}) {
    _queue.add(ScheduledTask(id: taskId, priority: priority, action: action));
    _queue.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    _processNext();
  }

  void _processNext() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;
    final task = _queue.removeAt(0);

    try {
      await task.action();
      _completedTaskCount++;
    } catch (_) {
    } finally {
      _isProcessing = false;
      if (_queue.isNotEmpty) {
        _processNext();
      }
    }
  }
}
