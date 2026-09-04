import Foundation

public struct SharedUsagePayload: Codable, Equatable, Sendable {
    public let snapshot: UsageSnapshot
    public let lastUpdated: Date

    public init(snapshot: UsageSnapshot, lastUpdated: Date) {
        self.snapshot = snapshot
        self.lastUpdated = lastUpdated
    }
}

public enum SharedSnapshotStore {
    public static let appGroupIdentifier = "group.dev.raffael.kiro-usage"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("usage-snapshot.json")
    }

    public static func save(_ payload: SharedUsagePayload) {
        guard let fileURL else { return }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    public static func load() -> SharedUsagePayload? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(SharedUsagePayload.self, from: data)
    }
}
