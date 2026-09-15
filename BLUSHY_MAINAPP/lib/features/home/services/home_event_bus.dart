import 'dart:async';
import 'package:flutter/foundation.dart';

abstract class HomeEvent {
  final DateTime timestamp;
  HomeEvent([DateTime? time]) : timestamp = time ?? DateTime.now();
}

class KitItemToggledEvent extends HomeEvent {
  final String itemKey;
  final bool isPacked;
  final int totalPacked;
  final int totalCount;

  KitItemToggledEvent({
    required this.itemKey,
    required this.isPacked,
    required this.totalPacked,
    required this.totalCount,
  });
}

class CheckinLoggedEvent extends HomeEvent {
  final String mood;
  final double energy;

  CheckinLoggedEvent({required this.mood, required this.energy});
}

class PeriodLoggedEvent extends HomeEvent {
  final String flowIntensity;
  final DateTime date;

  PeriodLoggedEvent({required this.flowIntensity, required this.date});
}

class LessonCompletedEvent extends HomeEvent {
  final String lessonId;
  final String title;

  LessonCompletedEvent({required this.lessonId, required this.title});
}

class SiaQuestionAskedEvent extends HomeEvent {
  final String prompt;
  final String? extractedTopic;

  SiaQuestionAskedEvent({required this.prompt, this.extractedTopic});
}

class TimeSlotChangedEvent extends HomeEvent {
  final String newWindowName;

  TimeSlotChangedEvent(this.newWindowName);
}

class StageChangedEvent extends HomeEvent {
  final String newStageKey;

  StageChangedEvent(this.newStageKey);
}

class HomeEventBus {
  static final HomeEventBus _instance = HomeEventBus._internal();
  factory HomeEventBus() => _instance;
  HomeEventBus._internal();

  final StreamController<HomeEvent> _eventController = StreamController<HomeEvent>.broadcast();
  final ValueNotifier<int> revisionNotifier = ValueNotifier<int>(0);

  Stream<HomeEvent> get onEvent => _eventController.stream;

  void emit(HomeEvent event) {
    _eventController.add(event);
    revisionNotifier.value++;
  }

  void dispose() {
    _eventController.close();
  }
}
