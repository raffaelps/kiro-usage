import SwiftUI

@main
struct KiroUsageApp: App {
    @StateObject private var usageStore = UsageStore()
    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @AppStorage(MenuBarPreferences.iconOnlyKey) private var iconOnly = false

    var body: some Scene {
        MenuBarExtra {
            UsageMenuView()
                .environmentObject(usageStore)
                .environmentObject(launchAtLogin)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: usageStore.statusSymbol)
                if !iconOnly {
                    Text(usageStore.menuBarText)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

enum MenuBarPreferences {
    static let iconOnlyKey = "menuBarIconOnly"
    static let alertThresholdPercents = [50, 75, 90, 100]
    static let alertNearDailyPaceKey = "alertNearDailyPace"
    static let alertOverDailyPaceKey = "alertOverDailyPace"
    static let refreshIntervalKey = "refreshIntervalMinutes"
    static let refreshIntervalOptions = [1, 5, 10, 15, 30]
    static let defaultRefreshIntervalMinutes = 5

    static func alertThresholdKey(for percent: Int) -> String {
        "alertThreshold\(percent)"
    }
}
