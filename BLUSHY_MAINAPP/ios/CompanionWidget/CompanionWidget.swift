// Companion home/lock-screen widget ("today's vibe + golden rule").
//
// This file is the WidgetKit view. It is NOT auto-added to the Xcode project —
// see README.md in this folder for the one-time Xcode setup (create a Widget
// Extension target, add the App Group, then add this file to that target).
//
// It reads the three strings the Flutter side (CompanionWidgetService) writes
// via the home_widget plugin into the shared App Group UserDefaults.

import WidgetKit
import SwiftUI

private let appGroupId = "group.com.blushy.blushy_love_app.companion"

struct CompanionEntry: TimelineEntry {
    let date: Date
    let title: String
    let vibe: String
    let goldenRule: String
}

struct CompanionProvider: TimelineProvider {
    func placeholder(in context: Context) -> CompanionEntry {
        CompanionEntry(date: Date(), title: "Blushy", vibe: "Open Blushy to see how to show up today.", goldenRule: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (CompanionEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CompanionEntry>) -> Void) {
        let entry = readEntry()
        // Refresh a few times a day; the app also nudges an update on open.
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(21600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func readEntry() -> CompanionEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let title = defaults?.string(forKey: "companion_widget_title") ?? ""
        let vibe = defaults?.string(forKey: "companion_widget_vibe") ?? ""
        let rule = defaults?.string(forKey: "companion_widget_golden_rule") ?? ""
        if title.isEmpty && vibe.isEmpty {
            return CompanionEntry(date: Date(), title: "Blushy", vibe: "Open Blushy to see how to show up today.", goldenRule: "")
        }
        return CompanionEntry(date: Date(), title: title, vibe: vibe, goldenRule: rule)
    }
}

struct CompanionWidgetEntryView: View {
    var entry: CompanionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(red: 0.76, green: 0.09, blue: 0.36))
                .lineLimit(1)
            Text(entry.vibe)
                .font(.system(size: 13))
                .foregroundColor(Color(red: 0.13, green: 0.08, blue: 0.06))
                .lineLimit(2)
            if !entry.goldenRule.isEmpty {
                Text(entry.goldenRule)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.05, green: 0.48, blue: 0.42))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@main
struct CompanionWidget: Widget {
    // The `kind` must match iOSName in CompanionWidgetService (dart): "CompanionWidget".
    let kind: String = "CompanionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CompanionProvider()) { entry in
            if #available(iOS 17.0, *) {
                CompanionWidgetEntryView(entry: entry)
                    .containerBackground(.white, for: .widget)
            } else {
                CompanionWidgetEntryView(entry: entry)
                    .background(Color.white)
            }
        }
        .configurationDisplayName("Blushy Companion")
        .description("Today's vibe and one golden rule for supporting someone you care about.")
        .supportedFamilies([.systemMedium, .accessoryRectangular])
    }
}
