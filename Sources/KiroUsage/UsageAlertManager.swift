import Foundation
import KiroUsageKit
import UserNotifications

@MainActor
final class UsageAlertManager {
    private static let alertedCyclesKey = "alertedThresholdCycles"
    private static let legacyThresholdKey = "alertThresholdPercent"

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    /// One-time migration from the earlier single-threshold preference to the new
    /// per-threshold toggles, so a user's existing choice isn't silently dropped.
    func migrateLegacyThresholdIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Self.legacyThresholdKey) != nil else { return }
        let legacyPercent = Int(defaults.double(forKey: Self.legacyThresholdKey))
        if MenuBarPreferences.alertThresholdPercents.contains(legacyPercent) {
            defaults.set(true, forKey: MenuBarPreferences.alertThresholdKey(for: legacyPercent))
        }
        defaults.removeObject(forKey: Self.legacyThresholdKey)
    }

    func evaluate(snapshot: UsageSnapshot, thresholdPercents: [Int]) {
        guard snapshot.limit > 0, !thresholdPercents.isEmpty else { return }

        let defaults = UserDefaults.standard
        let cyclePrefix = cycleIdentifier(resetDate: snapshot.resetDate)

        var alerted = Set(
            (defaults.stringArray(forKey: Self.alertedCyclesKey) ?? [])
                .filter { $0.hasPrefix("\(cyclePrefix)-") }
        )

        let crossed = thresholdPercents
            .filter { snapshot.progress >= Double($0) / 100 }
            .sorted()

        for percent in crossed {
            let key = "\(cyclePrefix)-\(percent)"
            guard !alerted.contains(key) else { continue }
            alerted.insert(key)
            sendNotification(snapshot: snapshot, thresholdPercent: percent)
        }

        defaults.set(Array(alerted), forKey: Self.alertedCyclesKey)
    }

    private func cycleIdentifier(resetDate: Date?) -> String {
        resetDate.map { String(Int($0.timeIntervalSince1970)) } ?? "unknown"
    }

    private func sendNotification(snapshot: UsageSnapshot, thresholdPercent: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Kiro Usage"
        let percentUsed = Int((snapshot.progress * 100).rounded())
        content.body = "Você já usou \(percentUsed)% dos seus créditos (\(UsageFormatter.format(snapshot.used)) de \(UsageFormatter.format(snapshot.limit)))."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "dev.raffael.kiro-usage.threshold-\(thresholdPercent)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
