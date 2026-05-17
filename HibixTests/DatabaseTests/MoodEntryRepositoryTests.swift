import Testing
import Foundation
import GRDB
@testable import Hibix

@Suite("MoodEntryRepository")
struct MoodEntryRepositoryTests {

    private func makeRepository() throws -> (MoodEntryRepository, DatabaseQueue) {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)
        let repository = MoodEntryRepository(writer: dbQueue)
        return (repository, dbQueue)
    }

    private let fixedNow = Date(timeIntervalSince1970: 1_747_440_000)

    @Test
    func upsert_insertsNewEntry() async throws {
        let (repo, _) = try makeRepository()
        let entry = try await repo.upsert(date: "2026-05-17",
                                          level: .good,
                                          memo: "良い1日",
                                          now: fixedNow)
        #expect(entry.entryDate == "2026-05-17")
        #expect(entry.moodLevel == 5)
        #expect(entry.memo == "良い1日")
        #expect(entry.id != nil)
        #expect(entry.createdAt == entry.updatedAt)
    }

    @Test
    func upsert_updatesExistingEntry() async throws {
        let (repo, _) = try makeRepository()
        let first = try await repo.upsert(date: "2026-05-17",
                                          level: .good,
                                          memo: "初回",
                                          now: fixedNow)
        let updated = try await repo.upsert(date: "2026-05-17",
                                            level: .down,
                                            memo: "更新",
                                            now: fixedNow.addingTimeInterval(60))
        #expect(updated.id == first.id)
        #expect(updated.moodLevel == 1)
        #expect(updated.memo == "更新")
        #expect(updated.updatedAt != first.updatedAt)
    }

    @Test
    func upsert_emptyMemoStoredAsNil() async throws {
        let (repo, _) = try makeRepository()
        let entry = try await repo.upsert(date: "2026-05-17",
                                          level: .calm,
                                          memo: "   ",
                                          now: fixedNow)
        #expect(entry.memo == nil)
    }

    @Test
    func upsert_rejectsMemoOver500Characters() async throws {
        let (repo, _) = try makeRepository()
        let longMemo = String(repeating: "あ", count: 501)
        await #expect(throws: MoodEntryRepositoryError.memoTooLong(limit: 500)) {
            _ = try await repo.upsert(date: "2026-05-17",
                                      level: .calm,
                                      memo: longMemo,
                                      now: fixedNow)
        }
    }

    @Test
    func upsert_accepts500ExactCharacters() async throws {
        let (repo, _) = try makeRepository()
        let exact = String(repeating: "あ", count: 500)
        let entry = try await repo.upsert(date: "2026-05-17",
                                          level: .calm,
                                          memo: exact,
                                          now: fixedNow)
        #expect(entry.memo == exact)
    }

    @Test
    func entry_returnsNilWhenMissing() async throws {
        let (repo, _) = try makeRepository()
        let entry = try await repo.entry(on: "2026-05-17")
        #expect(entry == nil)
    }

    @Test
    func entries_returnsRangeOrderedAscending() async throws {
        let (repo, _) = try makeRepository()
        _ = try await repo.upsert(date: "2026-05-15", level: .good, memo: nil, now: fixedNow)
        _ = try await repo.upsert(date: "2026-05-17", level: .best, memo: nil, now: fixedNow)
        _ = try await repo.upsert(date: "2026-05-16", level: .calm, memo: nil, now: fixedNow)
        let result = try await repo.entries(from: "2026-05-15", to: "2026-05-16")
        #expect(result.map(\.entryDate) == ["2026-05-15", "2026-05-16"])
    }

    @Test
    func updateMemo_persistsChange() async throws {
        let (repo, _) = try makeRepository()
        _ = try await repo.upsert(date: "2026-05-17", level: .good, memo: "初回", now: fixedNow)
        try await repo.updateMemo(on: "2026-05-17",
                                  memo: "編集後",
                                  now: fixedNow.addingTimeInterval(120))
        let entry = try await repo.entry(on: "2026-05-17")
        #expect(entry?.memo == "編集後")
    }

    @Test
    func deleteAll_removesAllEntries() async throws {
        let (repo, _) = try makeRepository()
        _ = try await repo.upsert(date: "2026-05-15", level: .good, memo: nil, now: fixedNow)
        _ = try await repo.upsert(date: "2026-05-16", level: .calm, memo: nil, now: fixedNow)
        try await repo.deleteAll()
        let result = try await repo.entries(from: "2026-05-01", to: "2026-05-31")
        #expect(result.isEmpty)
    }
}
