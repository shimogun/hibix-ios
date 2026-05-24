import Testing
import Foundation
import GRDB
@testable import Hibix

@Suite("HomeViewModel")
@MainActor
struct HomeViewModelTests {

    private func makeViewModel(fixedDate: Date) throws -> (HomeViewModel, MoodEntryRepository) {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)
        let repository = MoodEntryRepository(writer: dbQueue)
        let viewModel = HomeViewModel(repository: repository, now: { fixedDate })
        return (viewModel, repository)
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 12) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return try #require(Calendar(identifier: .gregorian).date(from: components))
    }

    @Test
    func load_returnsEmptyWhenNoEntries() async throws {
        let fixed = try makeDate(year: 2026, month: 5, day: 17)
        let (viewModel, _) = try makeViewModel(fixedDate: fixed)
        await viewModel.load(isPro: false)
        #expect(viewModel.todayEntry == nil)
        #expect(viewModel.lastErrorMessage == nil)
    }

    @Test
    func recordMood_savesAndExposesEntry() async throws {
        let fixed = try makeDate(year: 2026, month: 5, day: 17)
        let (viewModel, _) = try makeViewModel(fixedDate: fixed)
        await viewModel.recordMood(.good)
        #expect(viewModel.todayEntry?.moodLevel == MoodLevel.good.rawValue)
        #expect(viewModel.todayEntry?.entryDate == "2026-05-17")
        #expect(viewModel.lastErrorMessage == nil)
        #expect(viewModel.isSaving == false)
    }

    @Test
    func recordMood_sameDayOverwritesLevel() async throws {
        let fixed = try makeDate(year: 2026, month: 5, day: 17)
        let (viewModel, _) = try makeViewModel(fixedDate: fixed)
        await viewModel.recordMood(.good)
        await viewModel.recordMood(.down)
        #expect(viewModel.todayEntry?.moodLevel == MoodLevel.down.rawValue)
    }

    @Test
    func recordMood_preservesExistingMemo() async throws {
        let fixed = try makeDate(year: 2026, month: 5, day: 17)
        let (viewModel, repository) = try makeViewModel(fixedDate: fixed)
        _ = try await repository.upsert(date: "2026-05-17",
                                        level: .calm,
                                        memo: "事前メモ",
                                        now: fixed)
        await viewModel.load(isPro: false)
        await viewModel.recordMood(.good)
        #expect(viewModel.todayEntry?.memo == "事前メモ")
        #expect(viewModel.todayEntry?.moodLevel == MoodLevel.good.rawValue)
    }

    @Test
    func recordMood_presentsMemoSheet() async throws {
        let fixed = try makeDate(year: 2026, month: 5, day: 17)
        let (viewModel, _) = try makeViewModel(fixedDate: fixed)
        #expect(viewModel.isMemoSheetPresented == false)
        await viewModel.recordMood(.good)
        #expect(viewModel.isMemoSheetPresented == true)
    }

    @Test
    func saveMemo_persistsAndDismissesSheet() async throws {
        let fixed = try makeDate(year: 2026, month: 5, day: 17)
        let (viewModel, _) = try makeViewModel(fixedDate: fixed)
        await viewModel.recordMood(.good)
        await viewModel.saveMemo("穏やかな1日でした")
        #expect(viewModel.todayEntry?.memo == "穏やかな1日でした")
        #expect(viewModel.isMemoSheetPresented == false)
        #expect(viewModel.lastErrorMessage == nil)
    }

    @Test
    func saveMemo_emptyTextStoresNil() async throws {
        let fixed = try makeDate(year: 2026, month: 5, day: 17)
        let (viewModel, repository) = try makeViewModel(fixedDate: fixed)
        _ = try await repository.upsert(date: "2026-05-17",
                                        level: .good,
                                        memo: "事前メモ",
                                        now: fixed)
        await viewModel.load(isPro: false)
        await viewModel.saveMemo("   ")
        #expect(viewModel.todayEntry?.memo == nil)
    }

    @Test
    func saveMemo_rejectsOver500Characters() async throws {
        let fixed = try makeDate(year: 2026, month: 5, day: 17)
        let (viewModel, _) = try makeViewModel(fixedDate: fixed)
        await viewModel.recordMood(.good)
        let tooLong = String(repeating: "あ", count: 501)
        await viewModel.saveMemo(tooLong)
        #expect(viewModel.lastErrorMessage != nil)
        #expect(viewModel.isMemoSheetPresented == true)
    }

    @Test
    func editEntry_pastDate_updatesCalendarEntries() async throws {
        let fixed = try makeDate(year: 2026, month: 5, day: 17)
        let (viewModel, _) = try makeViewModel(fixedDate: fixed)
        await viewModel.editEntry(date: "2026-05-10", level: .calm, memo: "過去日メモ")
        let entry = viewModel.calendarEntries["2026-05-10"]
        #expect(entry?.moodLevel == MoodLevel.calm.rawValue)
        #expect(entry?.memo == "過去日メモ")
        #expect(viewModel.lastErrorMessage == nil)
    }

    @Test
    func editEntry_futureDate_isRejected() async throws {
        let fixed = try makeDate(year: 2026, month: 5, day: 17)
        let (viewModel, _) = try makeViewModel(fixedDate: fixed)
        await viewModel.editEntry(date: "2026-05-18", level: .good, memo: nil)
        #expect(viewModel.calendarEntries["2026-05-18"] == nil)
        #expect(viewModel.lastErrorMessage != nil)
    }

    @Test
    func editEntry_overwritesExistingEntry() async throws {
        let fixed = try makeDate(year: 2026, month: 5, day: 17)
        let (viewModel, repository) = try makeViewModel(fixedDate: fixed)
        _ = try await repository.upsert(date: "2026-05-10",
                                        level: .down,
                                        memo: "古いメモ",
                                        now: fixed)
        await viewModel.load(isPro: false)
        await viewModel.editEntry(date: "2026-05-10", level: .best, memo: "新しいメモ")
        let entry = viewModel.calendarEntries["2026-05-10"]
        #expect(entry?.moodLevel == MoodLevel.best.rawValue)
        #expect(entry?.memo == "新しいメモ")
    }

    @Test
    func dismissMemoSheet_clearsFlag() async throws {
        let fixed = try makeDate(year: 2026, month: 5, day: 17)
        let (viewModel, _) = try makeViewModel(fixedDate: fixed)
        await viewModel.recordMood(.good)
        viewModel.dismissMemoSheet()
        #expect(viewModel.isMemoSheetPresented == false)
    }

    @Test
    func load_afterPriorEntryReturnsIt() async throws {
        let fixed = try makeDate(year: 2026, month: 5, day: 17)
        let (viewModel, repository) = try makeViewModel(fixedDate: fixed)
        _ = try await repository.upsert(date: "2026-05-17",
                                        level: .calm,
                                        memo: nil,
                                        now: fixed)
        await viewModel.load(isPro: false)
        #expect(viewModel.todayEntry?.moodLevel == MoodLevel.calm.rawValue)
    }
}
