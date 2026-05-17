import Foundation
import GRDB

protocol MoodEntryRepositoryProtocol: Sendable {
    func upsert(date: String, level: MoodLevel, memo: String?, now: Date) async throws -> MoodEntry
    func entry(on date: String) async throws -> MoodEntry?
    func entries(from startDate: String, to endDate: String) async throws -> [MoodEntry]
    func updateMemo(on date: String, memo: String?, now: Date) async throws
    func deleteAll() async throws
}

enum MoodEntryRepositoryError: LocalizedError, Equatable {
    case memoTooLong(limit: Int)
    case fetchAfterUpsertFailed

    var errorDescription: String? {
        switch self {
        case .memoTooLong(let limit):
            return "メモは\(limit)文字以内で入力してください"
        case .fetchAfterUpsertFailed:
            return "気分の保存後にレコードを取得できませんでした"
        }
    }
}

final class MoodEntryRepository: MoodEntryRepositoryProtocol {
    nonisolated static let memoCharacterLimit: Int = 500

    private let writer: any DatabaseWriter

    nonisolated init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    nonisolated func upsert(date: String,
                            level: MoodLevel,
                            memo: String?,
                            now: Date = Date()) async throws -> MoodEntry {
        let normalized = try Self.validatedMemo(memo)
        let timestamp = Self.iso8601String(from: now)
        return try await writer.write { db in
            try db.execute(sql: """
                INSERT INTO mood_entries (entry_date, mood_level, memo, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(entry_date) DO UPDATE SET
                    mood_level = excluded.mood_level,
                    memo = excluded.memo,
                    updated_at = excluded.updated_at
                """, arguments: [date, level.rawValue, normalized, timestamp, timestamp])
            guard let entry = try MoodEntry
                .filter(Column("entry_date") == date)
                .fetchOne(db) else {
                throw MoodEntryRepositoryError.fetchAfterUpsertFailed
            }
            return entry
        }
    }

    nonisolated func entry(on date: String) async throws -> MoodEntry? {
        try await writer.read { db in
            try MoodEntry
                .filter(Column("entry_date") == date)
                .fetchOne(db)
        }
    }

    nonisolated func entries(from startDate: String, to endDate: String) async throws -> [MoodEntry] {
        try await writer.read { db in
            try MoodEntry
                .filter(Column("entry_date") >= startDate)
                .filter(Column("entry_date") <= endDate)
                .order(Column("entry_date"))
                .fetchAll(db)
        }
    }

    nonisolated func updateMemo(on date: String, memo: String?, now: Date = Date()) async throws {
        let normalized = try Self.validatedMemo(memo)
        let timestamp = Self.iso8601String(from: now)
        try await writer.write { db in
            try db.execute(sql: """
                UPDATE mood_entries
                SET memo = ?, updated_at = ?
                WHERE entry_date = ?
                """, arguments: [normalized, timestamp, date])
        }
    }

    nonisolated func deleteAll() async throws {
        try await writer.write { db in
            try db.execute(sql: "DELETE FROM mood_entries")
        }
    }

    nonisolated private static func validatedMemo(_ raw: String?) throws -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if raw.count > memoCharacterLimit {
            throw MoodEntryRepositoryError.memoTooLong(limit: memoCharacterLimit)
        }
        return raw
    }

    nonisolated private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
