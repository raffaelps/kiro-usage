import Foundation

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public enum PaceStatus: Equatable, Sendable {
        case belowLimit
        case onLimit
        case overLimit
    }

    public let used: Double
    public let limit: Double
    public let overages: Double
    public let planName: String
    public let resourceName: String
    public let resetDate: Date?

    public init(
        used: Double,
        limit: Double,
        overages: Double,
        planName: String,
        resourceName: String,
        resetDate: Date?
    ) {
        self.used = used
        self.limit = limit
        self.overages = overages
        self.planName = planName
        self.resourceName = resourceName
        self.resetDate = resetDate
    }

    public var remaining: Double { max(0, limit - used) }
    public var progress: Double { limit > 0 ? min(used / limit, 1) : 0 }

    public func allowedUsageThroughToday(asOf date: Date = Date()) -> Double? {
        guard let resetDate else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        guard
            let cycleStart = calendar.date(byAdding: .month, value: -1, to: resetDate),
            let totalDays = calendar.dateComponents([.day], from: cycleStart, to: resetDate).day,
            totalDays > 0
        else {
            return nil
        }

        let today = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: cycleStart)
        let elapsedDays = (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1
        let daysThroughToday = min(max(elapsedDays, 0), totalDays)

        return limit * Double(daysThroughToday) / Double(totalDays)
    }

    public func paceDifference(asOf date: Date = Date()) -> Double? {
        allowedUsageThroughToday(asOf: date).map { used - $0 }
    }

    public func paceStatus(asOf date: Date = Date()) -> PaceStatus? {
        guard let difference = paceDifference(asOf: date) else { return nil }
        if difference > 0.01 { return .overLimit }
        if difference < -0.01 { return .belowLimit }
        return .onLimit
    }
}
