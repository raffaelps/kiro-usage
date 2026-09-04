import Foundation

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var errorMessage: String?

    private let label = "dev.raffael.kiro-usage"

    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    init() {
        refreshStatus()
        enableAutomaticallyIfNeeded()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try installLaunchAgent()
            } else {
                try uninstallLaunchAgent()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Não foi possível alterar a inicialização automática: \(error.localizedDescription)"
        }
        refreshStatus()
    }

    private func enableAutomaticallyIfNeeded() {
        guard !isEnabled else { return }
        setEnabled(true)
    }

    private func refreshStatus() {
        isEnabled = FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    private func installLaunchAgent() throws {
        let fileManager = FileManager.default
        let directory = launchAgentURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", Bundle.main.bundleURL.path],
            "RunAtLoad": true,
            "ProcessType": "Interactive"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: launchAgentURL, options: .atomic)

        let result = runLaunchctl(["bootstrap", "gui/\(getuid())", launchAgentURL.path])
        if result != 0 && !isLaunchAgentLoaded() {
            throw KiroUsageError.unreadableData("o macOS recusou o item de início")
        }
    }

    private func uninstallLaunchAgent() throws {
        if isLaunchAgentLoaded() {
            _ = runLaunchctl(["bootout", "gui/\(getuid())/\(label)"])
        }
        if FileManager.default.fileExists(atPath: launchAgentURL.path) {
            try FileManager.default.removeItem(at: launchAgentURL)
        }
    }

    private func isLaunchAgentLoaded() -> Bool {
        runLaunchctl(["print", "gui/\(getuid())/\(label)"]) == 0
    }

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

}
