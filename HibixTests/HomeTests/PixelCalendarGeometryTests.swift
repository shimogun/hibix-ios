import Testing
import Foundation
@testable import Hibix

@Suite("PixelCalendarGeometry")
struct PixelCalendarGeometryTests {

    private var sundayStartCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }

    private func date(year: Int, month: Int, day: Int) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return try #require(sundayStartCalendar.date(from: components))
    }

    @Test
    func todayCell_isAtRightmostColumnOnTodayWeekdayRow() throws {
        let today = try date(year: 2026, month: 5, day: 17) // 2026-05-17 is Sunday
        let geom = PixelCalendarGeometry(today: today, calendar: sundayStartCalendar)
        let dateAtTodayCell = geom.date(forColumn: geom.columnCount - 1, row: 0)
        #expect(geom.isSameDay(dateAtTodayCell, today))
    }

    @Test
    func earliestColumn_isVisibleBoundary() throws {
        let today = try date(year: 2026, month: 5, day: 17)
        let geom = PixelCalendarGeometry(today: today, calendar: sundayStartCalendar)
        let earliest = try date(year: 2025, month: 5, day: 18)
        #expect(geom.isInVisibleWindow(earliest))
        let oneBefore = try date(year: 2025, month: 5, day: 17)
        #expect(geom.isInVisibleWindow(oneBefore) == false)
    }

    @Test
    func todayIsVisible_butNextDayIsNot() throws {
        let today = try date(year: 2026, month: 5, day: 17)
        let geom = PixelCalendarGeometry(today: today, calendar: sundayStartCalendar)
        #expect(geom.isInVisibleWindow(today))
        let tomorrow = try date(year: 2026, month: 5, day: 18)
        #expect(geom.isInVisibleWindow(tomorrow) == false)
    }

    @Test
    func entryDateString_matchesHibixFormat() throws {
        let today = try date(year: 2026, month: 5, day: 17)
        let geom = PixelCalendarGeometry(today: today, calendar: sundayStartCalendar)
        let target = try date(year: 2026, month: 1, day: 5)
        #expect(geom.entryDateString(for: target) == "2026-01-05")
    }

    @Test
    func accessibilityLabel_includesMoodWhenPresent() throws {
        let today = try date(year: 2026, month: 5, day: 17)
        let geom = PixelCalendarGeometry(today: today, calendar: sundayStartCalendar)
        let target = try date(year: 2026, month: 3, day: 1)
        let label = geom.accessibilityLabel(for: target, mood: .good)
        #expect(label == "3月1日、気分5、良い")
    }

    @Test
    func accessibilityLabel_fallsBackToNoEntry() throws {
        let today = try date(year: 2026, month: 5, day: 17)
        let geom = PixelCalendarGeometry(today: today, calendar: sundayStartCalendar)
        let target = try date(year: 2026, month: 3, day: 1)
        let label = geom.accessibilityLabel(for: target, mood: nil)
        #expect(label == "3月1日、記録なし")
    }

    @Test
    func midweekToday_placesTodayOnCorrectRow() throws {
        let today = try date(year: 2026, month: 5, day: 14) // 2026-05-14 is Thursday
        let geom = PixelCalendarGeometry(today: today, calendar: sundayStartCalendar)
        // Sunday=0, Mon=1, Tue=2, Wed=3, Thu=4
        let cell = geom.date(forColumn: geom.columnCount - 1, row: 4)
        #expect(geom.isSameDay(cell, today))
    }

    @Test
    func freeUser_alwaysUsesDefaultColumnCount() throws {
        let today = try date(year: 2026, month: 5, day: 17)
        let veryOld = try date(year: 2020, month: 1, day: 1)
        let geom = PixelCalendarGeometry(today: today,
                                         calendar: sundayStartCalendar,
                                         earliestEntryDate: veryOld,
                                         isPro: false)
        #expect(geom.columnCount == PixelCalendarGeometry.defaultColumnCount)
        #expect(!geom.isInVisibleWindow(veryOld))
    }

    @Test
    func proUser_extendsColumnCountForOlderEntries() throws {
        let today = try date(year: 2026, month: 5, day: 17)
        let twoYearsAgo = try date(year: 2024, month: 5, day: 17)
        let geom = PixelCalendarGeometry(today: today,
                                         calendar: sundayStartCalendar,
                                         earliestEntryDate: twoYearsAgo,
                                         isPro: true)
        #expect(geom.columnCount > PixelCalendarGeometry.defaultColumnCount)
        #expect(geom.isInVisibleWindow(twoYearsAgo))
    }

    @Test
    func proUser_withNoEntries_fallsBackToDefault() throws {
        let today = try date(year: 2026, month: 5, day: 17)
        let geom = PixelCalendarGeometry(today: today,
                                         calendar: sundayStartCalendar,
                                         earliestEntryDate: nil,
                                         isPro: true)
        #expect(geom.columnCount == PixelCalendarGeometry.defaultColumnCount)
    }

    @Test
    func proUser_withVeryRecentEntry_keepsMinimumColumnCount() throws {
        let today = try date(year: 2026, month: 5, day: 17)
        let yesterday = try date(year: 2026, month: 5, day: 16)
        let geom = PixelCalendarGeometry(today: today,
                                         calendar: sundayStartCalendar,
                                         earliestEntryDate: yesterday,
                                         isPro: true)
        #expect(geom.columnCount >= PixelCalendarGeometry.minimumColumnCount)
    }
}
