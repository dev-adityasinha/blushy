import 'dart:math';
import 'package:flutter/material.dart';

enum AnimationQuality { performance, standard, high, ultra }

class StickerAnimationManager extends ChangeNotifier {
  AnimationQuality quality = AnimationQuality.standard;
  bool isPaused = false;
  bool reducedMotion = false;
  int maxConcurrentAnimations = 12;

  // Track placement timestamps for 2-second idle delay rule
  final Map<String, DateTime> _placementTimes = {};
  
  // Track round-robin rotation for concurrent sticker limit
  final Set<String> _activeAnimatedIds = {};
  DateTime _lastRoundRobinShift = DateTime.now();

  StickerAnimationManager() {
    _updateLimits();
  }

  void setQuality(AnimationQuality newQuality) {
    quality = newQuality;
    _updateLimits();
    notifyListeners();
  }

  void setPaused(bool paused) {
    if (isPaused != paused) {
      isPaused = paused;
      notifyListeners();
    }
  }

  void setReducedMotion(bool reduced) {
    if (reducedMotion != reduced) {
      reducedMotion = reduced;
      _updateLimits();
      notifyListeners();
    }
  }

  void _updateLimits() {
    if (reducedMotion || quality == AnimationQuality.performance) {
      maxConcurrentAnimations = 4;
    } else if (quality == AnimationQuality.ultra) {
      maxConcurrentAnimations = 20;
    } else if (quality == AnimationQuality.high) {
      maxConcurrentAnimations = 16;
    } else {
      maxConcurrentAnimations = 12;
    }
  }

  /// Register sticker placement timestamp to enforce 2-second delay
  void registerPlacement(String itemId) {
    _placementTimes[itemId] = DateTime.now();
    notifyListeners();
  }

  /// Check if sticker has completed the 2-second idle delay
  bool isPlacementDelayPassed(String itemId) {
    final placed = _placementTimes[itemId];
    if (placed == null) return true;
    return DateTime.now().difference(placed).inMilliseconds >= 2000;
  }

  /// Round-robin batching update called on canvas updates or frame ticks
  void updateActiveStickerBatch(List<String> visibleStickerIds) {
    if (isPaused || reducedMotion || visibleStickerIds.isEmpty) {
      if (_activeAnimatedIds.isNotEmpty) {
        _activeAnimatedIds.clear();
        notifyListeners();
      }
      return;
    }

    // Filter stickers that have passed 2-second idle delay
    final eligibleIds = visibleStickerIds.where(isPlacementDelayPassed).toList();
    if (eligibleIds.isEmpty) {
      _activeAnimatedIds.clear();
      return;
    }

    // Rotate active set every 4 seconds if eligible stickers exceed limit
    final now = DateTime.now();
    if (now.difference(_lastRoundRobinShift).inSeconds >= 4 || _activeAnimatedIds.isEmpty) {
      _lastRoundRobinShift = now;
      eligibleIds.shuffle(Random(now.millisecondsSinceEpoch));
      _activeAnimatedIds.clear();
      _activeAnimatedIds.addAll(eligibleIds.take(maxConcurrentAnimations));
      notifyListeners();
    }
  }

  /// Check if a given sticker should execute its live loop animation
  bool shouldAnimateSticker(String itemId, bool isInViewport) {
    if (isPaused || reducedMotion || !isInViewport) return false;
    if (!isPlacementDelayPassed(itemId)) return false;
    return _activeAnimatedIds.contains(itemId) || _activeAnimatedIds.length < maxConcurrentAnimations;
  }
}
