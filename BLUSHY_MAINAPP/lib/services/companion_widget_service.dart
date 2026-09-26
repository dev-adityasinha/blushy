import 'package:home_widget/home_widget.dart';

import '../features/partner/companion_widget_data.dart';

/// Writes the companion home-screen widget payload ("today's vibe + golden
/// rule") into the native widget store and asks the OS to refresh the widget.
///
/// Pure data comes from [buildCompanionWidgetData]; this is only the native
/// bridge. It must never throw into the app — a widget update is best-effort.
class CompanionWidgetService {
  /// Android AppWidgetProvider class simple name (see CompanionWidgetProvider.kt).
  static const String _androidName = 'CompanionWidgetProvider';

  /// iOS WidgetKit widget kind (the `kind` string in the Swift widget).
  static const String _iOSName = 'CompanionWidget';

  /// iOS App Group shared between the app and the widget extension. Must match
  /// the App Group configured on both targets in Xcode.
  static const String _appGroupId = 'group.com.blushy.blushy_love_app.companion';

  static const List<String> _keys = [
    'companion_widget_title',
    'companion_widget_vibe',
    'companion_widget_golden_rule',
  ];

  /// Push the latest guidance for the companion's connection to the widget.
  /// When nothing is shared (no phase), the keys are cleared so the widget shows
  /// its own neutral empty state instead of stale data.
  static Future<void> update({
    required String partnerName,
    required String? phase,
  }) async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      final data = buildCompanionWidgetData(partnerName: partnerName, phase: phase);
      if (data == null) {
        for (final k in _keys) {
          await HomeWidget.saveWidgetData<String>(k, '');
        }
      } else {
        for (final entry in data.toStore().entries) {
          await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
        }
      }
      await HomeWidget.updateWidget(
        name: _androidName,
        androidName: _androidName,
        iOSName: _iOSName,
      );
    } catch (_) {
      // A widget failure must never disrupt the app.
    }
  }
}
