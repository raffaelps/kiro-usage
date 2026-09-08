import Foundation

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
    }
}

@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var latestVersion: String?
    @Published private(set) var releaseURL: URL?

    private static let apiURL = URL(string: "https://api.github.com/repos/raffaelps/kiro-usage/releases/latest")!
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    private let session: URLSession
    private var loopTask: Task<Void, Never>?

    init(session: URLSession = .shared) {
        self.session = session
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.check()
                try? await Task.sleep(for: .seconds(Self.checkInterval))
            }
        }
    }

    deinit {
        loopTask?.cancel()
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    var isUpdateAvailable: Bool {
        guard let latestVersion else { return false }
        return Self.isVersion(latestVersion, newerThan: currentVersion)
    }

    private func check() async {
        var request = URLRequest(url: Self.apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            latestVersion = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
            releaseURL = URL(string: release.htmlUrl)
        } catch {
            // Best-effort background check — a network hiccup just means we try again next cycle.
        }
    }

    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(partsA.count, partsB.count) {
            let x = i < partsA.count ? partsA[i] : 0
            let y = i < partsB.count ? partsB[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
