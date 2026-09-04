import Foundation
import Testing
@testable import KiroUsageKit

struct UsageSnapshotTests {
    @Test func computesSnapshotValues() {
        let snapshot = UsageSnapshot(
            used: 250,
            limit: 1000,
            overages: 0,
            planName: "Kiro Pro",
            resourceName: "Credits",
            resetDate: nil
        )

        #expect(snapshot.remaining == 750)
        #expect(snapshot.progress == 0.25)
    }

    @Test func computesInclusiveMonthlyPaceInUTC() throws {
        let resetDate = try #require(
            ISO8601DateFormatter().date(from: "2026-10-01T00:00:00Z")
        )
        let fourthDay = try #require(
            ISO8601DateFormatter().date(from: "2026-09-04T19:00:00Z")
        )
        let snapshot = UsageSnapshot(
            used: 242.69,
            limit: 1000,
            overages: 0,
            planName: "Kiro Pro",
            resourceName: "Credits",
            resetDate: resetDate
        )

        let allowed = try #require(snapshot.allowedUsageThroughToday(asOf: fourthDay))
        let difference = try #require(snapshot.paceDifference(asOf: fourthDay))

        #expect(abs(allowed - 133.333333) < 0.001)
        #expect(abs(difference - 109.356667) < 0.001)
        #expect(snapshot.paceStatus(asOf: fourthDay) == .overLimit)
    }

    @Test func marksUsageWithinDailyPace() throws {
        let resetDate = try #require(
            ISO8601DateFormatter().date(from: "2026-10-01T00:00:00Z")
        )
        let fourthDay = try #require(
            ISO8601DateFormatter().date(from: "2026-09-04T19:00:00Z")
        )
        let snapshot = UsageSnapshot(
            used: 100,
            limit: 1000,
            overages: 0,
            planName: "Kiro Pro",
            resourceName: "Credits",
            resetDate: resetDate
        )

        #expect(snapshot.paceStatus(asOf: fourthDay) == .belowLimit)
    }

    @Test func marksUsageExactlyOnDailyPace() throws {
        let resetDate = try #require(
            ISO8601DateFormatter().date(from: "2026-10-01T00:00:00Z")
        )
        let fourthDay = try #require(
            ISO8601DateFormatter().date(from: "2026-09-04T19:00:00Z")
        )
        let snapshot = UsageSnapshot(
            used: 100,
            limit: 750,
            overages: 0,
            planName: "Kiro",
            resourceName: "Credits",
            resetDate: resetDate
        )

        #expect(snapshot.paceStatus(asOf: fourthDay) == .onLimit)
    }

    @Test func roundTripsThroughJSON() throws {
        let resetDate = try #require(
            ISO8601DateFormatter().date(from: "2026-10-01T00:00:00Z")
        )
        let snapshot = UsageSnapshot(
            used: 82.35,
            limit: 1000,
            overages: 0,
            planName: "Kiro Pro",
            resourceName: "Credits",
            resetDate: resetDate
        )
        let payload = SharedUsagePayload(snapshot: snapshot, lastUpdated: resetDate)

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(SharedUsagePayload.self, from: data)

        #expect(decoded == payload)
    }
}
