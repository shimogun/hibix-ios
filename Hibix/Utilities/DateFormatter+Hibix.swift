import Foundation

enum HibixDate {
    nonisolated static func todayString(now: Date = Date(), calendar: Calendar = .current) -> String {
        formatEntryDate(now, calendar: calendar)
    }

    nonisolated static func dayString(offsetDays: Int,
                                      from now: Date = Date(),
                                      calendar: Calendar = .current) -> String {
        let base = calendar.date(byAdding: .day, value: offsetDays, to: now) ?? now
        return formatEntryDate(base, calendar: calendar)
    }

    nonisolated static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    nonisolated static func iso8601Date(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    nonisolated private static func formatEntryDate(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
