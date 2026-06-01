import SwiftUI

struct PixelCalendarView: View {
    let today: Date
    let entries: [String: MoodEntry]
    let isPro: Bool
    let earliestEntryDate: Date?
    let onSelectDate: (String) -> Void
    let onUpgradeRequest: () -> Void

    private static let cellSize: CGFloat = 32
    private static let cellSpacing: CGFloat = 4
    private static let monthHeaderHeight: CGFloat = 18
    private static let upgradeStripWidth: CGFloat = 96

    private let geometry: PixelCalendarGeometry

    init(today: Date,
         entries: [String: MoodEntry],
         isPro: Bool,
         earliestEntryDate: Date?,
         calendar: Calendar = .current,
         onSelectDate: @escaping (String) -> Void,
         onUpgradeRequest: @escaping () -> Void) {
        self.today = today
        self.entries = entries
        self.isPro = isPro
        self.earliestEntryDate = earliestEntryDate
        self.geometry = PixelCalendarGeometry(
            today: today,
            calendar: calendar,
            earliestEntryDate: earliestEntryDate,
            isPro: isPro
        )
        self.onSelectDate = onSelectDate
        self.onUpgradeRequest = onUpgradeRequest
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Self.cellSpacing) {
                if !isPro {
                    upgradeStrip
                }
                VStack(alignment: .leading, spacing: 4) {
                    monthHeader
                    grid
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
        }
        .defaultScrollAnchor(.trailing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isPro ? "ピクセルカレンダー、全期間" : "ピクセルカレンダー、直近365日")
    }

    private var upgradeStrip: some View {
        Button(action: onUpgradeRequest) {
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(Color.hibixSubNavy)
                Text("全期間を見る")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.hibixSubText)
                    .multilineTextAlignment(.center)
            }
            .frame(width: Self.upgradeStripWidth,
                   height: CGFloat(PixelCalendarGeometry.rowCount) * Self.cellSize
                        + CGFloat(PixelCalendarGeometry.rowCount - 1) * Self.cellSpacing
                        + Self.monthHeaderHeight + 4)
            .hibixGlassCard(cornerRadius: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pro にアップグレードして全期間を表示")
    }

    private var monthHeader: some View {
        HStack(alignment: .bottom, spacing: Self.cellSpacing) {
            ForEach(0..<geometry.columnCount, id: \.self) { col in
                Color.clear
                    .frame(width: Self.cellSize, height: Self.monthHeaderHeight)
                    .overlay(alignment: .topLeading) {
                        if let label = monthLabelIfTransition(at: col) {
                            Text(label)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.hibixPeriwinkle)
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
            ForEach(0..<geometry.columnCount, id: \.self) { col in
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
                CalendarCell(color: mood.map { Color.moodColor(for: $0) } ?? Color.hibixCellBase.opacity(0.8),
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

    private static let cornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .fill(color)
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(Color.hibixCellBorder, lineWidth: 1)
            if isToday {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(Color.hibixPeriwinkle, lineWidth: 2)
            }
        }
    }
}

#Preview {
    PixelCalendarView(today: Date(),
                      entries: [:],
                      isPro: false,
                      earliestEntryDate: nil,
                      onSelectDate: { _ in },
                      onUpgradeRequest: {})
        .padding()
}
