import AppKit
import Foundation
import KiroUsageKit
import OSLog
import WidgetKit

@MainActor
final class UsageStore: ObservableObject {
    private static let logger = Logger(subsystem: "dev.raffael.kiro-usage", category: "usage")
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    private let client: KiroClient
    private let alertManager = UsageAlertManager()
    private var refreshLoop: Task<Void, Never>?

    init(client: KiroClient = KiroClient()) {
        self.client = client
        alertManager.migrateLegacyThresholdIfNeeded()
        refreshLoop = Self.makeRefreshLoop(for: self)
    }

    deinit {
        refreshLoop?.cancel()
    }

    /// Cancels the current refresh loop and starts a new one, so a change to the
    /// refresh interval takes effect immediately instead of waiting out whatever
    /// sleep is already in progress.
    func restartRefreshLoop() {
        refreshLoop?.cancel()
        refreshLoop = Self.makeRefreshLoop(for: self)
    }

    private static func makeRefreshLoop(for store: UsageStore) -> Task<Void, Never> {
        Task { [weak store] in
            await store?.refresh()
            while !Task.isCancelled {
                let minutes = UserDefaults.standard.object(forKey: MenuBarPreferences.refreshIntervalKey) as? Int
                    ?? MenuBarPreferences.defaultRefreshIntervalMinutes
                try? await Task.sleep(for: .seconds(max(minutes, 1) * 60))
                guard !Task.isCancelled else { break }
                await store?.refresh(silently: true)
            }
        }
    }

    var menuBarText: String {
        guard let snapshot else { return isLoading ? "…" : "Kiro —" }
        return "\(Self.format(snapshot.used))/\(Self.format(snapshot.limit))"
    }

    var statusSymbol: String {
        guard let snapshot else { return errorMessage == nil ? "sparkles" : "exclamationmark.triangle" }

        switch snapshot.paceStatus() {
        case .belowLimit:
            return "arrow.down.circle.fill"
        case .onLimit:
            return "equal.circle.fill"
        case .overLimit:
            return "arrow.up.circle.fill"
        case nil:
            break
        }

        switch snapshot.progress {
        case ..<0.8: return "sparkles"
        case ..<1: return "exclamationmark.circle"
        default: return "exclamationmark.triangle.fill"
        }
    }

    func refresh(silently: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        if !silently { errorMessage = nil }

        do {
            snapshot = try await client.fetchUsage()
            lastUpdated = Date()
            errorMessage = nil
            if let snapshot, let lastUpdated {
                Self.logger.info("Uso atualizado: \(snapshot.used, privacy: .public) de \(snapshot.limit, privacy: .public)")
                SharedSnapshotStore.save(SharedUsagePayload(snapshot: snapshot, lastUpdated: lastUpdated))
                WidgetCenter.shared.reloadAllTimelines()

                let enabledThresholds = MenuBarPreferences.alertThresholdPercents.filter {
                    UserDefaults.standard.bool(forKey: MenuBarPreferences.alertThresholdKey(for: $0))
                }
                alertManager.evaluate(snapshot: snapshot, thresholdPercents: enabledThresholds)

                alertManager.evaluateDailyPace(
                    snapshot: snapshot,
                    alertNear: UserDefaults.standard.bool(forKey: MenuBarPreferences.alertNearDailyPaceKey),
                    alertOver: UserDefaults.standard.bool(forKey: MenuBarPreferences.alertOverDailyPaceKey)
                )
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            Self.logger.error("Falha ao atualizar: \(self.errorMessage ?? "erro desconhecido", privacy: .public)")
        }

        isLoading = false
    }

    func openKiro() {
        let appURL = URL(fileURLWithPath: "/Applications/Kiro.app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { [weak self] _, error in
            guard error == nil else { return }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(4))
                await self?.refresh()
            }
        }
    }

    func openAccount() {
        guard let url = URL(string: "https://app.kiro.dev/settings/account") else { return }
        NSWorkspace.shared.open(url)
    }

    static func format(_ value: Double) -> String {
        UsageFormatter.format(value)
    }
}
