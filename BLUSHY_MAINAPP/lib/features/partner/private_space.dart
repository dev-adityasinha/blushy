import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/storage.dart';
import '../../services/api_partner_service.dart';

/// Private Space: her personal updates stop reaching her partner.
///
/// The old Argument Mode was a boolean on her own device. It never reached the
/// server, and its only effect was to filter Docsy cards out of her own
/// messenger view -- her partner kept receiving her cycle, mood and sleep the
/// whole time. A screen promising otherwise would have been a privacy lie.
///
/// This turns the promise into something the server enforces, using the
/// permission matrix that already exists: taking space switches the personal
/// keys off, and resuming switches back on exactly the ones that were on
/// before. Nothing is deleted, nothing historical changes, and nothing is
/// retroactively exposed -- resuming restores what she had already chosen.
///
/// The keys it touches are the personal ones only. Messages, blooms, gifts and
/// shared memories are not permission-gated and are deliberately left alone,
/// so the connection stays open while the updates pause.
class PrivateSpace {
  const PrivateSpace._();

  /// The permission keys Private Space pauses.
  ///
  /// Named from DEFAULT_PERMISSIONS in partnerRepository.js. `shareOnboarding`
  /// is intentionally absent: it is who she is rather than how she is today,
  /// and pausing it would blank the partner's sense of her stage rather than
  /// her current state.
  ///
  /// `allowAiSuggestionsMan` and `allowDecoderMan` used to be here too, and
  /// they are the reason Private Space did nothing at all. Those two belong to
  /// his side of the connection, the server refuses any patch containing a key
  /// that is not the caller's to set, and it refuses the *whole* patch -- so
  /// including them meant none of her four were paused either. Every attempt
  /// came back 403 and the button appeared to do nothing.
  ///
  /// Leaving them out costs nothing: both drive suggestions computed from her
  /// mood, cycle, sleep and insights, and with those four paused there is
  /// nothing left for them to read.
  static const List<String> pausedKeys = [
    'shareMood',
    'shareCycle',
    'shareSleep',
    'shareInsights',
  ];

  /// What stays available while space is being taken. Not permission-gated,
  /// so nothing here is switched off -- this list is what the sheet promises,
  /// and it is true because these features never read the paused keys.
  static const List<String> stillAvailable = [
    'Messages',
    'Shared memories',
    'Blooms',
    'Gifts',
  ];

  static String _key(String connectionId) =>
      'partner_private_space_$connectionId.json';

  /// The state of Private Space for one connection, or null when it is off.
  static PrivateSpaceState? stateFor(String connectionId) {
    try {
      final raw = BlushyStorage.read(_key(connectionId));
      if (raw.isEmpty || raw['active'] != true) return null;
      return PrivateSpaceState.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  /// Switches the personal keys off, remembering exactly what was on.
  ///
  /// The snapshot is written before the call, not after: if the app dies
  /// between the two, resuming still knows what to restore. Returns false
  /// without changing anything when the server refuses.
  static Future<bool> take({
    required String connectionId,
    required Map<String, dynamic> currentPermissions,
    Duration? forDuration,
    String? note,
  }) async {
    final restore = <String, dynamic>{
      for (final key in pausedKeys)
        if (currentPermissions.containsKey(key)) key: currentPermissions[key],
    };

    final state = PrivateSpaceState(
      active: true,
      startedAt: DateTime.now(),
      until: forDuration == null ? null : DateTime.now().add(forDuration),
      note: note,
      restore: restore,
    );
    BlushyStorage.write(_key(connectionId), state.toJson());

    final paused = <String, dynamic>{for (final key in pausedKeys) key: false};
    final service = ApiPartnerService();
    final ok = await service.updatePermissions(connectionId, paused);
    if (!ok) {
      // Nothing was paused, so nothing is pending restoration.
      BlushyStorage.write(_key(connectionId), {'active': false});
      debugPrint('PrivateSpace: the pause was refused; nothing changed.');
      return false;
    }

    // Her words, sent as an ordinary message so they arrive where he already
    // reads her -- and so they are hers to see in the thread too, rather than
    // a system notice about her that she cannot look back at.
    //
    // Sent after the pause, never before: if the pause fails there is nothing
    // to explain, and a message announcing a boundary that was not applied
    // would be worse than silence. A send that fails does not undo the pause,
    // which is the part that matters.
    final message = note?.trim();
    if (message != null && message.isNotEmpty) {
      await service.sendMessage(connectionId, message);
    }
    return true;
  }

  /// Puts back exactly what was on before.
  static Future<bool> resume(String connectionId) async {
    final state = stateFor(connectionId);
    if (state == null) return true;

    final ok = await ApiPartnerService()
        .updatePermissions(connectionId, state.restore);
    if (ok) {
      BlushyStorage.write(_key(connectionId), {'active': false});
    }
    return ok;
  }

  /// Ends a timed space that has run out.
  ///
  /// Called on load rather than by a timer: a countdown that only runs while
  /// the app is open would leave her sharing paused for as long as the app
  /// stayed closed, which is the opposite of what she chose.
  static Future<void> resumeIfElapsed(String connectionId) async {
    final state = stateFor(connectionId);
    if (state == null || state.until == null) return;
    if (DateTime.now().isBefore(state.until!)) return;
    await resume(connectionId);
  }
}

/// One connection's Private Space record.
class PrivateSpaceState {
  const PrivateSpaceState({
    required this.active,
    required this.startedAt,
    required this.until,
    required this.note,
    required this.restore,
  });

  final bool active;
  final DateTime startedAt;

  /// When it lifts on its own, or null for "until I resume".
  final DateTime? until;

  /// What she chose to tell her partner, if anything. Always optional: she is
  /// never made to explain why she wanted space.
  final String? note;

  /// The permissions to put back, exactly as they were.
  final Map<String, dynamic> restore;

  /// What is left, or null when there is no end time.
  Duration? get remaining {
    if (until == null) return null;
    final left = until!.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// "2h 14m remaining", or "Until you resume".
  String get remainingLabel {
    final left = remaining;
    if (left == null) return 'Until you resume';
    if (left == Duration.zero) return 'Ending now';
    final hours = left.inHours;
    final minutes = left.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m remaining';
    return '${minutes}m remaining';
  }

  Map<String, dynamic> toJson() => {
        'active': active,
        'startedAt': startedAt.toIso8601String(),
        if (until != null) 'until': until!.toIso8601String(),
        if (note != null) 'note': note,
        'restore': jsonEncode(restore),
      };

  static PrivateSpaceState fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> restore = const {};
    final raw = json['restore'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) restore = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // A record that will not decode restores nothing rather than throwing;
        // she can set her sharing again, which is recoverable. Throwing here
        // would take the portal down.
      }
    } else if (raw is Map) {
      restore = Map<String, dynamic>.from(raw);
    }

    return PrivateSpaceState(
      active: json['active'] == true,
      startedAt:
          DateTime.tryParse(json['startedAt']?.toString() ?? '') ?? DateTime.now(),
      until: DateTime.tryParse(json['until']?.toString() ?? ''),
      note: (json['note'] as String?)?.trim().isEmpty == true
          ? null
          : json['note'] as String?,
      restore: restore,
    );
  }
}
