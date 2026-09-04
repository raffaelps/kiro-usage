import KiroUsageKit
import SwiftUI
import WidgetKit

struct UsageEntry: TimelineEntry {
    let date: Date
    let payload: SharedUsagePayload?
}

struct UsageTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(
            date: Date(),
            payload: SharedUsagePayload(
                snapshot: UsageSnapshot(
                    used: 420,
                    limit: 1000,
                    overages: 0,
                    planName: "Kiro Pro",
                    resourceName: "Credits",
                    resetDate: nil
                ),
                lastUpdated: Date()
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(UsageEntry(date: Date(), payload: SharedSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let entry = UsageEntry(date: Date(), payload: SharedSnapshotStore.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 20, to: Date()) ?? Date().addingTimeInterval(1200)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct UsageWidget: Widget {
    let kind = "UsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageTimelineProvider()) { entry in
            UsageWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Kiro Usage")
        .description("Consumo de créditos do Kiro.")
        .supportedFamilies([.systemSmall])
    }
}
