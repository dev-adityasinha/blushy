# Companion iOS widget — one-time Xcode setup

The Dart + Android sides are done. iOS needs a Widget Extension target, which
must be created in Xcode (it can't be scaffolded by editing files). Steps:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **File ▸ New ▸ Target… ▸ Widget Extension**. Name it **`CompanionWidget`**
   (uncheck "Include Configuration Intent"). This creates a new target + group.
3. **Delete** the placeholder `CompanionWidget.swift` Xcode generated, and
   **add the one in this folder** (`ios/CompanionWidget/CompanionWidget.swift`)
   to the new target (File ▸ Add Files…, tick the CompanionWidget target only).
4. **App Group** — add the same group to BOTH targets so they share storage:
   - Select **Runner** target ▸ Signing & Capabilities ▸ **+ Capability ▸ App Groups**
     ▸ add `group.com.blushy.blushy_love_app.companion`.
   - Select the **CompanionWidget** target ▸ do the same (identical group id).
   - This id must match `_appGroupId` in
     `lib/services/companion_widget_service.dart` and `appGroupId` in the Swift.
5. Set the widget target's **Deployment Target** to match Runner (iOS 13+;
   `containerBackground` uses an availability check so 17+ is optional).
6. Build & run on a device/simulator, then long-press the home screen ▸ add the
   **Blushy Companion** widget.

## Data contract
The Flutter app writes three strings into the App Group `UserDefaults` via the
`home_widget` plugin whenever a companion opens their home:

| key | shown as |
|---|---|
| `companion_widget_title` | eyebrow (name · phase) |
| `companion_widget_vibe` | today's vibe |
| `companion_widget_golden_rule` | the one golden rule |

Empty values → the widget shows a neutral "open Blushy" placeholder.

## Android
Android is fully wired (no Xcode-equivalent step): `CompanionWidgetProvider.kt`,
`res/layout/companion_widget.xml`, `res/xml/companion_widget_info.xml`, and the
`<receiver>` in `AndroidManifest.xml`. It works after a normal `flutter build apk`.
