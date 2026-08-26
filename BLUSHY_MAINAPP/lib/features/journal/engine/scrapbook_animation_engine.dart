import 'package:flutter/material.dart';
import 'sticker_animation_manager.dart';
import 'particle_manager.dart';
import 'micro_interaction_manager.dart';
import 'physics_coordinator.dart';

class ScrapbookAnimationEngine extends ChangeNotifier {
  late final StickerAnimationManager stickerManager;
  late final ParticleManager particleManager;
  late final MicroInteractionManager microInteractionManager;
  late final PhysicsCoordinator physicsCoordinator;

  bool _isGlobalPaused = false;
  bool get isGlobalPaused => _isGlobalPaused;

  ScrapbookAnimationEngine() {
    stickerManager = StickerAnimationManager();
    particleManager = ParticleManager();
    microInteractionManager = MicroInteractionManager();
    physicsCoordinator = PhysicsCoordinator();

    stickerManager.addListener(notifyListeners);
    particleManager.addListener(notifyListeners);
    microInteractionManager.addListener(notifyListeners);
    physicsCoordinator.addListener(notifyListeners);
  }

  /// Pause all ambient and loop animations during typing, recording, or dragging
  void setEditingOrInteractingState({
    required bool isTyping,
    required bool isRecording,
    required bool isDragging,
  }) {
    final shouldPause = isTyping || isRecording || isDragging;
    if (_isGlobalPaused != shouldPause) {
      _isGlobalPaused = shouldPause;
      stickerManager.setPaused(shouldPause);
      particleManager.setPaused(shouldPause);
      notifyListeners();
    }
  }

  /// Update accessibility settings across all sub-managers
  void setReducedMotion(bool reduced) {
    stickerManager.setReducedMotion(reduced);
    particleManager.setReducedMotion(reduced);
  }

  @override
  void dispose() {
    stickerManager.removeListener(notifyListeners);
    particleManager.removeListener(notifyListeners);
    microInteractionManager.removeListener(notifyListeners);
    physicsCoordinator.removeListener(notifyListeners);
    super.dispose();
  }
}
