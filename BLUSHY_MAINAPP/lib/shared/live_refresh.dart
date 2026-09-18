import 'dart:async';

import 'package:flutter/widgets.dart';

/// Keeps a partner screen showing what is true now, without being asked.
///
/// Every partner surface fetched once in `initState` and then never again, so
/// what was on screen was "as of whenever this opened" with nothing saying so.
/// A mood she logged, a permission she changed, a cycle day that rolled over
/// at midnight -- none of it appeared until the app was killed and reopened.
/// Reported as "some refresh are not taking place", and it was all of them.
///
/// Three triggers, which between them cover how these screens are actually
/// used: coming back to the app, a poll while it is open, and a pull down.
/// They all go through [refreshNow], and all three are skipped while one is
/// already running -- a slow request on a cold Render instance must not stack
/// up behind itself.
///
/// Mixed in rather than copied per screen: four near-identical timers, each
/// with its own chance of outliving its State, is how this becomes a crash
/// later.
mixin LiveRefresh<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  Timer? _liveTimer;
  bool _refreshInFlight = false;

  /// Fetches whatever this screen shows. Implemented per screen.
  ///
  /// Must not show a full-screen loading state: this runs on a timer, and a
  /// spinner every interval makes a working screen look like a failing one.
  Future<void> refreshNow();

  /// Slow enough not to spend a battery or a free-tier request budget on an
  /// idle screen, quick enough that something she logs is there before he has
  /// finished reading the card above it.
  Duration get refreshInterval => const Duration(seconds: 45);

  /// Call from `initState`, after the first fetch is started.
  void startLiveRefresh() {
    WidgetsBinding.instance.addObserver(this);
    _liveTimer = Timer.periodic(refreshInterval, (_) => refreshQuietly());
  }

  /// Call from `dispose`. A timer that outlives its State keeps firing into a
  /// disposed widget.
  void stopLiveRefresh() {
    _liveTimer?.cancel();
    _liveTimer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Safe to call from anywhere, including a pull-to-refresh.
  Future<void> refreshQuietly() async {
    if (_refreshInFlight || !mounted) return;
    _refreshInFlight = true;
    try {
      await refreshNow();
    } catch (_) {
      // A failed refresh leaves the last good values on screen. The next tick
      // tries again; there is nothing useful to say about one dropped poll.
    } finally {
      _refreshInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The phone has been in a pocket; whatever is on screen is stale by
    // however long it was there.
    if (state == AppLifecycleState.resumed) {
      refreshQuietly();
    }
  }
}
