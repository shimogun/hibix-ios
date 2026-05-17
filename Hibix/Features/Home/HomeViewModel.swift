import Foundation
import Observation
import os.log

@MainActor
@Observable
final class HomeViewModel {
    private(set) var calendarEntries: [String: MoodEntry] = [:]
    private(set) var lastErrorMessage: String?
    private(set) var isSaving: Bool = false
    var isMemoSheetPresented: Bool = false
    var selectedDetailDate: String?

    private let repository: any MoodEntryRepositoryProtocol
    private let now: @Sendable () -> Date

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Home")

    init(repository: any MoodEntryRepositoryProtocol,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.repository = repository
        self.now = now
    }

    var todayEntry: MoodEntry? {
        calendarEntries[HibixDate.todayString(now: now())]
    }

    func load() async {
        let today = HibixDate.todayString(now: now())
        let earliest = HibixDate.dayString(offsetDays: -364, from: now())
        do {
            let entries = try await repository.entries(from: earliest, to: today)
            calendarEntries = Dictionary(uniqueKeysWithValues: entries.map { ($0.entryDate, $0) })
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
            let entry = try await repository.upsert(date: date,
                                                    level: level,
                                                    memo: preservedMemo,
                                                    now: now())
            calendarEntries[date] = entry
            lastErrorMessage = nil
            isMemoSheetPresented = true
            Self.logger.info("Recorded mood level=\(level.rawValue, privacy: .public) date=\(date, privacy: .public)")
        } catch {
            lastErrorMessage = error.localizedDescription
            Self.logger.error("Record mood failed: \(error.localizedDescription, privacy: .public)")
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
            lastErrorMessage = nil
            Self.logger.info("Edited entry date=\(date, privacy: .public) level=\(level.rawValue, privacy: .public)")
        } catch {
            lastErrorMessage = error.localizedDescription
            Self.logger.error("Edit entry failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
