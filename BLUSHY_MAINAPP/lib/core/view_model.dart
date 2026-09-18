import 'package:flutter/foundation.dart';

/// Base class for screen view models.
///
/// MVVM in Flutter has three layers with a one-way dependency: the View (a
/// widget) reads a ViewModel and forwards taps to it; the ViewModel holds the
/// screen's state and calls the Model (services/repositories); the Model knows
/// nothing about either. A ViewModel is a plain `ChangeNotifier` -- no widgets,
/// no `BuildContext` -- so it can be unit-tested without pumping a widget.
///
/// This base adds the one guard every async ViewModel needs: `notifyListeners`
/// must not fire after the view model has been disposed with the screen, or
/// Flutter throws. `safeNotify` drops the call once disposed.
abstract class BlushyViewModel extends ChangeNotifier {
  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// Notify listeners unless this view model has already been disposed.
  @protected
  void safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
