import Foundation
import KiroUsageKit
import UserNotifications

@MainActor
final class UsageAlertManager {
    private static let alertedCyclesKey = "alertedThresholdCycles"
    private static let alertedDailyPaceKey = "alertedDailyPaceDays"
    private static let legacyThresholdKey = "alertThresholdPercent"
    private static let nearDailyPaceRatio = 0.9

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

    /// Fires at most once per UTC day per alert type, since pace status (unlike a monthly
    /// % milestone) can move back below the threshold and cross it again as days pass.
    func evaluateDailyPace(snapshot: UsageSnapshot, alertNear: Bool, alertOver: Bool, asOf date: Date = Date()) {
        guard alertNear || alertOver else { return }
        guard let allowed = snapshot.allowedUsageThroughToday(asOf: date), allowed > 0 else { return }

        let dayPrefix = Self.dayIdentifier(date)
        let defaults = UserDefaults.standard
        var alertedDays = Set(
            (defaults.stringArray(forKey: Self.alertedDailyPaceKey) ?? [])
                .filter { $0.hasPrefix("\(dayPrefix)-") }
        )

        if alertOver, snapshot.paceStatus(asOf: date) == .overLimit {
            let key = "\(dayPrefix)-over"
            if !alertedDays.contains(key) {
                alertedDays.insert(key)
                sendDailyPaceNotification(snapshot: snapshot, allowed: allowed, over: true)
            }
        } else if alertNear, snapshot.used / allowed >= Self.nearDailyPaceRatio {
            let key = "\(dayPrefix)-near"
            if !alertedDays.contains(key) {
                alertedDays.insert(key)
                sendDailyPaceNotification(snapshot: snapshot, allowed: allowed, over: false)
            }
        }

        defaults.set(Array(alertedDays), forKey: Self.alertedDailyPaceKey)
    }

    private func cycleIdentifier(resetDate: Date?) -> String {
        resetDate.map { String(Int($0.timeIntervalSince1970)) } ?? "unknown"
    }

    private static func dayIdentifier(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
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

    private func sendDailyPaceNotification(snapshot: UsageSnapshot, allowed: Double, over: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "Kiro Usage"
        content.sound = .default
        if over {
            content.body = "Você ultrapassou o ritmo diário recomendado: \(UsageFormatter.format(snapshot.used)) usados, \(UsageFormatter.format(allowed)) permitidos até hoje."
        } else {
            content.body = "Você está perto do ritmo diário recomendado: \(UsageFormatter.format(snapshot.used)) de \(UsageFormatter.format(allowed)) créditos permitidos até hoje."
        }

        let request = UNNotificationRequest(
            identifier: "dev.raffael.kiro-usage.daily-\(over ? "over" : "near")",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
