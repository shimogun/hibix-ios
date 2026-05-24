import Foundation
import Observation
import os.log

@MainActor
@Observable
final class HomeViewModel {
    private(set) var calendarEntries: [String: MoodEntry] = [:]
    private(set) var earliestEntryDate: Date?
    private(set) var lastErrorMessage: String?
    private(set) var isSaving: Bool = false
    var isMemoSheetPresented: Bool = false
    var isPaywallPresented: Bool = false
    var selectedDetailDate: String?

    private let repository: any MoodEntryRepositoryProtocol
    private let checkinService: CheckinService?
    private let now: @Sendable () -> Date

    /// 過去エントリ読み込み用のセンチネル。1970-01-01 を起点にすれば実質「全期間」。
    nonisolated static let allHistoryEarliestDate = "1970-01-01"

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Home")

    init(repository: any MoodEntryRepositoryProtocol,
         checkinService: CheckinService? = nil,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.repository = repository
        self.checkinService = checkinService
        self.now = now
    }

    var todayEntry: MoodEntry? {
        calendarEntries[HibixDate.todayString(now: now())]
    }

    func load(isPro: Bool) async {
        let today = HibixDate.todayString(now: now())
        let earliest = isPro ? Self.allHistoryEarliestDate : HibixDate.dayString(offsetDays: -364, from: now())
        do {
            let entries = try await repository.entries(from: earliest, to: today)
            calendarEntries = Dictionary(uniqueKeysWithValues: entries.map { ($0.entryDate, $0) })
            earliestEntryDate = Self.firstEntryDate(in: entries)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
            Self.logger.error("Load calendar failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func recordMood(_ level: MoodLevel) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        let date = HibixDate.todayString(now: now())
        let preservedMemo = calendarEntries[date]?.memo
        do {
            let tapAt = now()
            let entry = try await repository.upsert(date: date,
                                                    level: level,
                                                    memo: preservedMemo,
                                                    now: tapAt)
            calendarEntries[date] = entry
            updateEarliestEntryDateOnInsert(entry: entry)
            lastErrorMessage = nil
            isMemoSheetPresented = true
            Self.logger.info("Recorded mood level=\(level.rawValue, privacy: .public) date=\(date, privacy: .public)")
            if let checkinService {
                Task { await checkinService.reportCheckin(at: tapAt) }
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            Self.logger.error("Record mood failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 長押し起動: memo なしで気分のみ即保存する (F1)。
    /// `recordMood` と異なり MemoSheet を提示しない。
    func recordMoodWithoutMemo(_ level: MoodLevel) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        let date = HibixDate.todayString(now: now())
        do {
            let tapAt = now()
            let entry = try await repository.upsert(date: date,
                                                    level: level,
                                                    memo: nil,
                                                    now: tapAt)
            calendarEntries[date] = entry
            updateEarliestEntryDateOnInsert(entry: entry)
            lastErrorMessage = nil
            Self.logger.info("Recorded mood (no memo) level=\(level.rawValue, privacy: .public) date=\(date, privacy: .public)")
            if let checkinService {
                Task { await checkinService.reportCheckin(at: tapAt) }
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            Self.logger.error("Record mood without memo failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveMemo(_ rawText: String) async {
        let date = HibixDate.todayString(now: now())
        do {
            try await repository.updateMemo(on: date, memo: rawText, now: now())
            if let updated = try await repository.entry(on: date) {
                calendarEntries[date] = updated
            }
            lastErrorMessage = nil
            isMemoSheetPresented = false
            Self.logger.info("Saved memo for date=\(date, privacy: .public)")
        } catch {
            lastErrorMessage = error.localizedDescription
            Self.logger.error("Save memo failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func dismissMemoSheet() {
        isMemoSheetPresented = false
    }

    func presentPaywall() {
        isPaywallPresented = true
    }

    func editEntry(date: String, level: MoodLevel, memo: String?) async {
        guard date <= HibixDate.todayString(now: now()) else {
            lastErrorMessage = "未来日は記録できません"
            return
        }
        do {
            let entry = try await repository.upsert(date: date,
                                                    level: level,
                                                    memo: memo,
                                                    now: now())
            calendarEntries[date] = entry
            updateEarliestEntryDateOnInsert(entry: entry)
            lastErrorMessage = nil
            Self.logger.info("Edited entry date=\(date, privacy: .public) level=\(level.rawValue, privacy: .public)")
        } catch {
            lastErrorMessage = error.localizedDescription
            Self.logger.error("Edit entry failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Private helpers

    private func updateEarliestEntryDateOnInsert(entry: MoodEntry) {
        guard let entryDate = Self.parseEntryDate(entry.entryDate) else { return }
        if let current = earliestEntryDate {
            if entryDate < current { earliestEntryDate = entryDate }
        } else {
            earliestEntryDate = entryDate
        }
    }

    nonisolated private static func firstEntryDate(in entries: [MoodEntry]) -> Date? {
        let dates = entries.compactMap { parseEntryDate($0.entryDate) }
        return dates.min()
    }

    nonisolated private static func parseEntryDate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }
}
