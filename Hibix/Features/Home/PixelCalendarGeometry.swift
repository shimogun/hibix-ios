import Foundation

struct PixelCalendarGeometry: Sendable {
    static let rowCount: Int = 7
    static let defaultColumnCount: Int = 53
    static let defaultWindowDays: Int = 365
    static let minimumColumnCount: Int = 53

    let today: Date
    let calendar: Calendar
    let startOfTodayDay: Date
    let earliestVisibleDay: Date
    let columnCount: Int

    init(today: Date,
         calendar: Calendar = .current,
         earliestEntryDate: Date? = nil,
         isPro: Bool = false) {
        self.today = today
        self.calendar = calendar
        let startOfTodayDay = calendar.startOfDay(for: today)
        self.startOfTodayDay = startOfTodayDay

        if isPro {
            // 有料: 「最古エントリ」と「365日前」のどちらか古い方を起点。
            // 初回記録(=earliestEntryDate が今日)でも365日分のグリッドが見えるようにする。
            let defaultEarliest = calendar.date(byAdding: .day,
                                                value: -(Self.defaultWindowDays - 1),
                                                to: startOfTodayDay) ?? startOfTodayDay
            let earliestCandidate = earliestEntryDate.map { calendar.startOfDay(for: $0) }
            let earliest: Date
            if let earliestCandidate, earliestCandidate <= startOfTodayDay {
                earliest = min(earliestCandidate, defaultEarliest)
            } else {
                earliest = defaultEarliest
            }
            self.earliestVisibleDay = earliest
            let days = (calendar.dateComponents([.day], from: earliest, to: startOfTodayDay).day ?? 0) + 1
            let weeks = (days + Self.rowCount - 1) / Self.rowCount
            self.columnCount = max(Self.minimumColumnCount, weeks)
        } else {
            // 無料: 365 日ローリングウィンドウ固定
            self.earliestVisibleDay = calendar.date(byAdding: .day,
                                                    value: -(Self.defaultWindowDays - 1),
                                                    to: startOfTodayDay) ?? startOfTodayDay
            self.columnCount = Self.defaultColumnCount
        }
    }

    /// 指定 (column, row) のセルが表現する日付。column 0 = 最古列、column (columnCount-1) = 当週。
    /// row 0 = 当該週の先頭日(Calendar.firstWeekday に従う)、row 6 = 末尾日。
    func date(forColumn col: Int, row: Int) -> Date {
        let weeksAgo = (columnCount - 1) - col
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
