import SwiftUI

struct PixelCalendarView: View {
    let today: Date
    let entries: [String: MoodEntry]
    let onSelectDate: (String) -> Void

    private static let cellSize: CGFloat = 32
    private static let cellSpacing: CGFloat = 4
    private static let monthHeaderHeight: CGFloat = 18

    private let geometry: PixelCalendarGeometry

    init(today: Date,
         entries: [String: MoodEntry],
         calendar: Calendar = .current,
         onSelectDate: @escaping (String) -> Void) {
        self.today = today
        self.entries = entries
        self.geometry = PixelCalendarGeometry(today: today, calendar: calendar)
        self.onSelectDate = onSelectDate
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                monthHeader
                grid
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
        }
        .defaultScrollAnchor(.trailing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("ピクセルカレンダー、直近365日")
    }

    private var monthHeader: some View {
        HStack(alignment: .bottom, spacing: Self.cellSpacing) {
            ForEach(0..<PixelCalendarGeometry.columnCount, id: \.self) { col in
                Color.clear
                    .frame(width: Self.cellSize, height: Self.monthHeaderHeight)
                    .overlay(alignment: .topLeading) {
                        if let label = monthLabelIfTransition(at: col) {
                            Text(label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
            }
        }
        .accessibilityHidden(true)
    }

    private func monthLabelIfTransition(at col: Int) -> String? {
        let date = geometry.date(forColumn: col, row: 0)
        guard geometry.isInVisibleWindow(date) else { return nil }
        if col == 0 {
            return geometry.monthLabel(for: date)
        }
        let prevDate = geometry.date(forColumn: col - 1, row: 0)
        let currentMonth = geometry.monthComponent(of: date)
        let prevMonth = geometry.monthComponent(of: prevDate)
        return currentMonth != prevMonth ? geometry.monthLabel(for: date) : nil
    }

    private var grid: some View {
        HStack(alignment: .top, spacing: Self.cellSpacing) {
            ForEach(0..<PixelCalendarGeometry.columnCount, id: \.self) { col in
                VStack(spacing: Self.cellSpacing) {
                    ForEach(0..<PixelCalendarGeometry.rowCount, id: \.self) { row in
                        cellView(col: col, row: row)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(col: Int, row: Int) -> some View {
        let date = geometry.date(forColumn: col, row: row)
        if geometry.isInVisibleWindow(date) {
            let dateString = geometry.entryDateString(for: date)
            let entry = entries[dateString]
            let mood = entry?.mood
            let isToday = geometry.isSameDay(date, today)
            Button {
                onSelectDate(dateString)
            } label: {
                CalendarCell(color: mood.map { Color.moodColor(for: $0) } ?? Color.moodEmptyCell,
                             isToday: isToday)
                    .frame(width: Self.cellSize, height: Self.cellSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(geometry.accessibilityLabel(for: date, mood: mood))
            .accessibilityAddTraits(.isButton)
        } else {
            Color.clear.frame(width: Self.cellSize, height: Self.cellSize)
        }
    }
}

private struct CalendarCell: View {
    let color: Color
    let isToday: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
            if isToday {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary, lineWidth: 2)
            }
        }
    }
}

#Preview {
    PixelCalendarView(today: Date(), entries: [:], onSelectDate: { _ in })
        .padding()
}
