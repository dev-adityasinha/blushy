import 'dart:async';
import 'package:flutter/material.dart';

enum AiTaskPriority { p1Immediate, p2NearImmediate, p3Deferred, p4IdleBatch }

class AiQueueTask {
  final String id;
  final AiTaskPriority priority;
  final Future<dynamic> Function() task;
  final Completer<dynamic> completer;

  AiQueueTask({
    required this.id,
    required this.priority,
    required this.task,
    required this.completer,
  });
}

class InsightScheduler extends ChangeNotifier {
  bool enableTitles = true;
  bool enableSearch = true;
  bool enableMemoryLinks = true;
  bool enableWeeklySummary = true;
  bool enableCloudAi = true;

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final List<AiQueueTask> _taskQueue = [];
  bool _isProcessingQueue = false;

  /// Check cache for valid non-expired entry
  dynamic getCached(String key, {Duration maxAge = const Duration(hours: 12)}) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp != null && DateTime.now().difference(timestamp) < maxAge) {
      return _cache[key];
    }
    return null;
  }

  /// Write result to cache
  void setCache(String key, dynamic value) {
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Invalidate cache for a specific key or pattern
  void invalidateCache(String keyPrefix) {
    _cache.removeWhere((k, _) => k.startsWith(keyPrefix));
    _cacheTimestamps.removeWhere((k, _) => k.startsWith(keyPrefix));
  }

  /// Enqueue an AI task with priority scheduling
  Future<T?> scheduleTask<T>({
    required String taskId,
    required AiTaskPriority priority,
    required Future<T> Function() task,
  }) async {
    if (!enableCloudAi) {
      return null;
    }

    final completer = Completer<T>();
    final queueTask = AiQueueTask(
      id: taskId,
      priority: priority,
      task: task,
      completer: completer,
    );

    _taskQueue.add(queueTask);
    _taskQueue.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    _processNextQueueTask();
    
    try {
      final result = await completer.future;
      return result as T?;
    } catch (_) {
      return null;
    }
  }

  void _processNextQueueTask() async {
    if (_isProcessingQueue || _taskQueue.isEmpty) return;

    _isProcessingQueue = true;
    final current = _taskQueue.removeAt(0);

    try {
      final res = await current.task();
      if (!current.completer.isCompleted) {
        current.completer.complete(res);
      }
    } catch (e) {
      if (!current.completer.isCompleted) {
        current.completer.completeError(e);
      }
    } finally {
      _isProcessingQueue = false;
      if (_taskQueue.isNotEmpty) {
        _processNextQueueTask();
      }
    }
  }

  void updatePrivacySettings({
    bool? titles,
    bool? search,
    bool? memoryLinks,
    bool? weeklySummary,
    bool? cloudAi,
  }) {
    if (titles != null) enableTitles = titles;
    if (search != null) enableSearch = search;
    if (memoryLinks != null) enableMemoryLinks = memoryLinks;
    if (weeklySummary != null) enableWeeklySummary = weeklySummary;
    if (cloudAi != null) enableCloudAi = cloudAi;
    notifyListeners();
  }
}
