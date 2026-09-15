import 'package:flutter/material.dart';

enum MicroInteractionType {
  placementBounce,
  tapeSettle,
  photoLift,
  deleteShrink,
  duplicateSlide,
  savePulse,
}

class ActiveMicroInteraction {
  final String id;
  final MicroInteractionType type;
  final DateTime startTime;

  ActiveMicroInteraction({
    required this.id,
    required this.type,
    required this.startTime,
  });
}

class MicroInteractionManager extends ChangeNotifier {
  final Map<String, ActiveMicroInteraction> _activeInteractions = {};
  bool _isSavePulseActive = false;

  bool get isSavePulseActive => _isSavePulseActive;

  void triggerItemInteraction(String itemId, MicroInteractionType type) {
    _activeInteractions[itemId] = ActiveMicroInteraction(
      id: itemId,
      type: type,
      startTime: DateTime.now(),
    );
    notifyListeners();
  }

  void triggerSavePulse() {
    _isSavePulseActive = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 1800), () {
      _isSavePulseActive = false;
      notifyListeners();
    });
  }

  ActiveMicroInteraction? getInteraction(String itemId) {
    final interaction = _activeInteractions[itemId];
    if (interaction == null) return null;
    final elapsed = DateTime.now().difference(interaction.startTime).inMilliseconds;
    if (elapsed > 600) {
      _activeInteractions.remove(itemId);
      return null;
    }
    return interaction;
  }
}
