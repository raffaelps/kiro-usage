import Foundation
import KiroUsageKit

struct KiroCredentialStore: Sendable {
    private let homeDirectory: URL

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.homeDirectory = homeDirectory
    }

    func loadCredentials() throws -> KiroCredentials {
        let url = homeDirectory
            .appendingPathComponent(".aws/sso/cache/kiro-auth-token.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw KiroUsageError.credentialsNotFound
        }

        do {
            return try JSONDecoder().decode(KiroCredentials.self, from: Data(contentsOf: url))
        } catch {
            throw KiroUsageError.unreadableData(error.localizedDescription)
        }
    }

    func loadProfile() throws -> KiroProfile {
        let candidates = [
            "Library/Application Support/Kiro/User/globalStorage/kiro.kiroagent/profile.json",
            "Library/Application Support/Kiro/User/globalStorage/kiro.kiro-agent/profile.json"
        ]

        guard let url = candidates
            .map({ homeDirectory.appendingPathComponent($0) })
            .first(where: { FileManager.default.fileExists(atPath: $0.path) })
        else {
            throw KiroUsageError.profileNotFound
        }

        do {
            return try JSONDecoder().decode(KiroProfile.self, from: Data(contentsOf: url))
        } catch {
            throw KiroUsageError.unreadableData(error.localizedDescription)
        }
    }

    func loadClientRegistration(hash: String) throws -> KiroClientRegistration {
        let url = homeDirectory.appendingPathComponent(".aws/sso/cache/\(hash).json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw KiroUsageError.refreshUnavailable
        }

        do {
            return try JSONDecoder().decode(KiroClientRegistration.self, from: Data(contentsOf: url))
        } catch {
            throw KiroUsageError.unreadableData(error.localizedDescription)
        }
    }
}

actor KiroClient {
    private let session: URLSession
    private let credentialStore: KiroCredentialStore
    private var refreshedCredentials: KiroCredentials?

    init(
        session: URLSession = .shared,
        credentialStore: KiroCredentialStore = KiroCredentialStore()
    ) {
        self.session = session
        self.credentialStore = credentialStore
    }

    func fetchUsage() async throws -> UsageSnapshot {
        let credentials = try await validCredentials()
        let profile = try credentialStore.loadProfile()
        let profileARN = credentials.profileArn ?? profile.arn
        let region = credentials.region ?? regionFromARN(profileARN) ?? "us-east-1"
        guard ["us-east-1", "eu-central-1"].contains(region) else {
            throw KiroUsageError.invalidEndpoint
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "management.\(region).kiro.dev"
        components.path = "/getUsageLimits"
        components.queryItems = [
            URLQueryItem(name: "profileArn", value: profileARN),
            URLQueryItem(name: "origin", value: "AI_EDITOR"),
            URLQueryItem(name: "resourceType", value: "AGENTIC_REQUEST"),
            URLQueryItem(name: "isEmailRequired", value: "true")
        ]

        guard let url = components.url else { throw KiroUsageError.invalidEndpoint }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("KiroUsage/1.0 macOS", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if credentials.authMethod == "external_idp" {
            request.setValue("EXTERNAL_IDP", forHTTPHeaderField: "TokenType")
        }
        if credentials.provider == "Internal" {
            request.setValue("true", forHTTPHeaderField: "redirect-for-internal")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KiroUsageError.unreadableData("resposta HTTP inválida")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "sem detalhes"
            throw KiroUsageError.server(status: httpResponse.statusCode, message: String(body.prefix(180)))
        }

        let responsePayload: KiroUsageResponse
        do {
            responsePayload = try JSONDecoder().decode(KiroUsageResponse.self, from: data)
        } catch {
            throw KiroUsageError.unreadableData(error.localizedDescription)
        }

        guard let breakdown = responsePayload.primaryBreakdown else {
            throw KiroUsageError.noUsageData
        }

        return UsageSnapshot(
            used: breakdown.used,
            limit: breakdown.limit,
            overages: breakdown.overages,
            planName: responsePayload.subscriptionInfo?.subscriptionTitle ?? "Kiro",
            resourceName: breakdown.title,
            resetDate: responsePayload.resetDate
        )
    }

    private func validCredentials() async throws -> KiroCredentials {
        if let refreshedCredentials, !refreshedCredentials.isExpired {
            return refreshedCredentials
        }

        let stored = try credentialStore.loadCredentials()
        guard stored.isExpired else { return stored }
        guard stored.refreshToken?.isEmpty == false else {
            throw KiroUsageError.sessionExpired
        }

        let refreshed: KiroCredentials
        switch stored.authMethod {
        case "IdC":
            refreshed = try await refreshIDCCredentials(stored)
        case "social":
            refreshed = try await refreshSocialCredentials(stored)
        default:
            throw KiroUsageError.refreshUnavailable
        }

        refreshedCredentials = refreshed
        return refreshed
    }

    private func refreshIDCCredentials(_ credentials: KiroCredentials) async throws -> KiroCredentials {
        guard
            let hash = credentials.clientIdHash,
            let refreshToken = credentials.refreshToken,
            let region = credentials.region
        else {
            throw KiroUsageError.refreshUnavailable
        }

        let registration = try credentialStore.loadClientRegistration(hash: hash)
        guard !registration.isExpired else { throw KiroUsageError.refreshUnavailable }
        guard let url = URL(string: "https://oidc.\(region).amazonaws.com/token") else {
            throw KiroUsageError.invalidEndpoint
        }

        let payload: [String: String] = [
            "clientId": registration.clientId,
            "clientSecret": registration.clientSecret,
            "grantType": "refresh_token",
            "refreshToken": refreshToken
        ]
        let response: KiroRefreshResponse = try await postRefresh(url: url, payload: payload)
        return makeCredentials(from: response, preserving: credentials)
    }

    private func refreshSocialCredentials(_ credentials: KiroCredentials) async throws -> KiroCredentials {
        guard let refreshToken = credentials.refreshToken else {
            throw KiroUsageError.refreshUnavailable
        }
        guard let url = URL(string: "https://prod.us-east-1.auth.desktop.kiro.dev/refreshToken") else {
            throw KiroUsageError.invalidEndpoint
        }

        let response: KiroRefreshResponse = try await postRefresh(
            url: url,
            payload: ["refreshToken": refreshToken]
        )
        return makeCredentials(from: response, preserving: credentials)
    }

    private func postRefresh(
        url: URL,
        payload: [String: String]
    ) async throws -> KiroRefreshResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("KiroUsage/1.1 macOS", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw KiroUsageError.refreshUnavailable
        }
        guard (200..<300).contains(http.statusCode) else {
            throw KiroUsageError.refreshUnavailable
        }

        do {
            return try JSONDecoder().decode(KiroRefreshResponse.self, from: data)
        } catch {
            throw KiroUsageError.unreadableData(error.localizedDescription)
        }
    }

    private func makeCredentials(
        from response: KiroRefreshResponse,
        preserving old: KiroCredentials
    ) -> KiroCredentials {
        KiroCredentials(
            accessToken: response.accessToken,
            expiresAt: Date().addingTimeInterval(response.expiresIn).formatted(.iso8601),
            provider: old.provider,
            authMethod: old.authMethod,
            region: old.region,
            refreshToken: response.refreshToken ?? old.refreshToken,
            clientIdHash: old.clientIdHash,
            profileArn: response.profileArn ?? old.profileArn
        )
    }

    private func regionFromARN(_ arn: String) -> String? {
        let parts = arn.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count > 3 else { return nil }
        return String(parts[3])
    }
}
