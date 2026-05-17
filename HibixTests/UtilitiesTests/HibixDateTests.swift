import Testing
import Foundation
@testable import Hibix

@Suite("HibixDate")
struct HibixDateTests {

    private func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        let calendar = Calendar(identifier: .gregorian)
        return try #require(calendar.date(from: components))
    }

    @Test
    func todayString_returnsLocalDate() throws {
        let now = try date(year: 2026, month: 5, day: 17, hour: 23, minute: 59)
        let calendar = Calendar(identifier: .gregorian)
        #expect(HibixDate.todayString(now: now, calendar: calendar) == "2026-05-17")
    }

    @Test
    func dayString_negativeOffset_returnsPastDate() throws {
        let now = try date(year: 2026, month: 5, day: 17)
        let calendar = Calendar(identifier: .gregorian)
        #expect(HibixDate.dayString(offsetDays: -364, from: now, calendar: calendar) == "2025-05-18")
    }

    @Test
    func dayString_zeroOffset_returnsToday() throws {
        let now = try date(year: 2026, month: 1, day: 1)
        let calendar = Calendar(identifier: .gregorian)
        #expect(HibixDate.dayString(offsetDays: 0, from: now, calendar: calendar) == "2026-01-01")
    }

    @Test
    func iso8601String_formatsWithSecondsAndZ() {
        let date = Date(timeIntervalSince1970: 1_747_440_000)
        let result = HibixDate.iso8601String(from: date)
        #expect(result.hasSuffix("Z"))
        #expect(result.contains("T"))
    }
}
