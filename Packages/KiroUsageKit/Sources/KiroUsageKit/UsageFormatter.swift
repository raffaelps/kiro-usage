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

    private static let resetDateShortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("dM")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    /// Kiro's monthly cycle resets at UTC midnight, so the reset date must always be
    /// rendered in UTC — formatting it in the device's local time zone can show the wrong day.
    public static func resetDateString(_ date: Date) -> String {
        resetDateFormatter.string(from: date)
    }

    /// Compact numeric day/month variant of `resetDateString` (e.g. 01/11), also in UTC, for tight layouts like the widget.
    public static func resetDateShortString(_ date: Date) -> String {
        resetDateShortFormatter.string(from: date)
    }
}
