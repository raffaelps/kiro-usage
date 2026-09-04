import Foundation

public enum UsageFormatter {
    public static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value.rounded() == value ? 0 : 2)))
    }

    private static let resetDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    /// Kiro's monthly cycle resets at UTC midnight, so the reset date must always be
    /// rendered in UTC — formatting it in the device's local time zone can show the wrong day.
    public static func resetDateString(_ date: Date) -> String {
        resetDateFormatter.string(from: date)
    }
}
