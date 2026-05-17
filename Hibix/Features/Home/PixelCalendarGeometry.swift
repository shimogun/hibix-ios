import Foundation

struct PixelCalendarGeometry: Sendable {
    static let rowCount: Int = 7
    static let columnCount: Int = 53
    static let windowDays: Int = 365

    let today: Date
    let calendar: Calendar
    let startOfTodayDay: Date
    let earliestVisibleDay: Date

    init(today: Date, calendar: Calendar = .current) {
        self.today = today
        self.calendar = calendar
        let startOfTodayDay = calendar.startOfDay(for: today)
        self.startOfTodayDay = startOfTodayDay
        self.earliestVisibleDay = calendar.date(byAdding: .day,
                                                value: -(Self.windowDays - 1),
                                                to: startOfTodayDay) ?? startOfTodayDay
    }

    /// 指定 (column, row) のセルが表現する日付。column 0 = 52週前、column 52 = 当週。
    /// row 0 = 当該週の先頭日（Calendar.firstWeekday に従う）、row 6 = 末尾日。
    func date(forColumn col: Int, row: Int) -> Date {
        let weeksAgo = (Self.columnCount - 1) - col
        let weekdayIndex = weekdayIndex(of: startOfTodayDay)
        guard let startOfCurrentWeek = calendar.date(byAdding: .day,
                                                    value: -weekdayIndex,
                                                    to: startOfTodayDay),
              let startOfTargetWeek = calendar.date(byAdding: .day,
                                                   value: -(weeksAgo * Self.rowCount),
                                                   to: startOfCurrentWeek),
              let cellDate = calendar.date(byAdding: .day,
                                           value: row,
                                           to: startOfTargetWeek) else {
            return startOfTodayDay
        }
        return cellDate
    }

    func isInVisibleWindow(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        return day >= earliestVisibleDay && day <= startOfTodayDay
    }

    func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.startOfDay(for: lhs) == calendar.startOfDay(for: rhs)
    }

    func entryDateString(for date: Date) -> String {
        HibixDate.todayString(now: date, calendar: calendar)
    }

    func monthComponent(of date: Date) -> Int {
        calendar.component(.month, from: date)
    }

    func monthLabel(for date: Date) -> String {
        "\(monthComponent(of: date))月"
    }

    func accessibilityLabel(for date: Date, mood: MoodLevel?) -> String {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        if let mood {
            return "\(month)月\(day)日、気分\(mood.rawValue)、\(mood.displayName)"
        } else {
            return "\(month)月\(day)日、記録なし"
        }
    }

    private func weekdayIndex(of date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        let firstWeekday = calendar.firstWeekday
        return (weekday - firstWeekday + Self.rowCount) % Self.rowCount
    }
}
