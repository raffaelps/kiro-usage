import Foundation
import Testing
@testable import KiroUsageKit

struct UsageFormatterTests {
    @Test func shortResetDateIsRenderedInUTC() throws {
        let reset = try #require(ISO8601DateFormatter().date(from: "2026-10-01T00:00:00Z"))

        let text = UsageFormatter.resetDateShortString(reset)

        #expect(text.contains("1"))
        #expect(!text.contains("30"))
    }
}
