import Foundation

private func parseKiroISO8601Date(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) {
        return date
    }

    return ISO8601DateFormatter().date(from: value)
}

struct KiroCredentials: Decodable, Sendable {
    let accessToken: String
    let expiresAt: String
    let provider: String?
    let authMethod: String?
    let region: String?
    let refreshToken: String?
    let clientIdHash: String?
    let profileArn: String?

    var expirationDate: Date? {
        parseKiroISO8601Date(expiresAt)
    }

    var isExpired: Bool {
        guard let expirationDate else { return true }
        return expirationDate <= Date().addingTimeInterval(30)
    }
}

struct KiroClientRegistration: Decodable, Sendable {
    let clientId: String
    let clientSecret: String
    let expiresAt: String

    var isExpired: Bool {
        guard let date = parseKiroISO8601Date(expiresAt) else { return true }
        return date <= Date().addingTimeInterval(30)
    }
}

struct KiroRefreshResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Double
    let profileArn: String?
}

struct KiroProfile: Decodable, Sendable {
    let arn: String
    let name: String?
}

struct KiroUsageResponse: Decodable, Sendable {
    let nextDateReset: Double?
    let subscriptionInfo: SubscriptionInfo?
    let usageBreakdownList: [UsageBreakdown]?

    struct SubscriptionInfo: Decodable, Sendable {
        let subscriptionTitle: String?
        let type: String?
    }

    struct UsageBreakdown: Decodable, Sendable {
        let resourceType: String?
        let displayName: String?
        let displayNamePlural: String?
        let currentUsage: Double?
        let currentUsageWithPrecision: Double?
        let usageLimit: Double?
        let usageLimitWithPrecision: Double?
        let currentOverages: Double?
        let currentOveragesWithPrecision: Double?

        var used: Double {
            currentUsageWithPrecision ?? currentUsage ?? 0
        }

        var limit: Double {
            usageLimitWithPrecision ?? usageLimit ?? 0
        }

        var overages: Double {
            currentOveragesWithPrecision ?? currentOverages ?? 0
        }

        var title: String {
            displayNamePlural ?? displayName ?? resourceType ?? "Créditos"
        }
    }

    var primaryBreakdown: UsageBreakdown? {
        let visible = (usageBreakdownList ?? []).filter {
            $0.resourceType != "AGENTIC_REQUEST" && ($0.limit > 0 || $0.used > 0)
        }

        return visible.first(where: { $0.resourceType?.uppercased().contains("CREDIT") == true })
            ?? visible.max(by: { $0.limit < $1.limit })
    }

    var resetDate: Date? {
        nextDateReset.map(Date.init(timeIntervalSince1970:))
    }
}

enum KiroUsageError: LocalizedError, Equatable {
    case credentialsNotFound
    case profileNotFound
    case sessionExpired
    case refreshUnavailable
    case invalidEndpoint
    case server(status: Int, message: String)
    case noUsageData
    case unreadableData(String)

    var errorDescription: String? {
        switch self {
        case .credentialsNotFound:
            return "Sessão do Kiro não encontrada."
        case .profileNotFound:
            return "Perfil ativo do Kiro não encontrado."
        case .sessionExpired:
            return "A credencial local do Kiro expirou. Abra o aplicativo Kiro e entre novamente."
        case .refreshUnavailable:
            return "A sessão existe, mas não pode ser renovada. Abra o aplicativo Kiro e entre novamente."
        case .invalidEndpoint:
            return "Não foi possível montar o endereço do serviço do Kiro."
        case let .server(status, message):
            return "O Kiro respondeu com erro \(status): \(message)"
        case .noUsageData:
            return "O Kiro não retornou dados de créditos para esta conta."
        case let .unreadableData(message):
            return "Não foi possível ler os dados do Kiro: \(message)"
        }
    }
}
