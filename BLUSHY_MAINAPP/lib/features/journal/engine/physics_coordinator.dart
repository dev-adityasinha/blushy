import 'package:flutter/material.dart';

enum DeskLightingMode { morning, afternoon, evening, night }

class PhysicsCoordinator extends ChangeNotifier {
  DeskLightingMode lightingMode = DeskLightingMode.afternoon;
  final Map<String, double> _itemLiftHeights = {}; // 0.0 to 1.0

  void setLightingMode(DeskLightingMode mode) {
    if (lightingMode != mode) {
      lightingMode = mode;
      notifyListeners();
    }
  }

  void setItemLift(String itemId, double liftHeight) {
    _itemLiftHeights[itemId] = liftHeight.clamp(0.0, 1.0);
    notifyListeners();
  }

  double getItemLift(String itemId) {
    return _itemLiftHeights[itemId] ?? 0.0;
  }

  /// Calculates directional shadow offset based on lighting mode and item lift height
  Offset getShadowOffset(String itemId) {
    final lift = getItemLift(itemId);
    final baseDistance = 3.0 + (lift * 12.0);

    switch (lightingMode) {
      case DeskLightingMode.morning: // Sun from top-left -> shadow to bottom-right
        return Offset(baseDistance * 1.2, baseDistance * 1.0);
      case DeskLightingMode.evening: // Warm golden sun from right -> shadow to left
        return Offset(-baseDistance * 1.2, baseDistance * 0.8);
      case DeskLightingMode.night: // Lamp from top-right -> shadow to bottom-left
        return Offset(-baseDistance * 0.8, baseDistance * 1.2);
      case DeskLightingMode.afternoon: // Overhead sun -> subtle downward shadow
      default:
        return Offset(0, baseDistance);
    }
  }

  /// Calculates shadow blur radius based on lift height
  double getShadowBlurRadius(String itemId) {
    final lift = getItemLift(itemId);
    return 6.0 + (lift * 16.0);
  }

  /// Calculates shadow color intensity based on lift height & lighting mode
  Color getShadowColor(String itemId) {
    final lift = getItemLift(itemId);
    final opacity = (0.22 - (lift * 0.08)).clamp(0.08, 0.3);

    switch (lightingMode) {
      case DeskLightingMode.morning:
        return Color.fromRGBO(60, 40, 20, opacity);
      case DeskLightingMode.evening:
        return Color.fromRGBO(80, 45, 15, opacity);
      case DeskLightingMode.night:
        return Color.fromRGBO(20, 25, 45, opacity);
      case DeskLightingMode.afternoon:
      default:
        return Color.fromRGBO(0, 0, 0, opacity);
    }
  }
}
