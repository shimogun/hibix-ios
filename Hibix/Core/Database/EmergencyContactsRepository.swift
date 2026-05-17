import Foundation
import GRDB

protocol EmergencyContactsRepositoryProtocol: Sendable {
    func count() async throws -> Int
    func list() async throws -> [EmergencyContact]
    func add(email: String, label: String?, now: Date) async throws -> EmergencyContact
    func update(id: Int64, email: String, label: String?) async throws
    func delete(id: Int64) async throws
}

/// `emergency_contacts` テーブルへのアクセス (PRD v2.2.0 §6 F-07)。
/// サーバー暗号化(C-03 / AES-256-GCM)は STEP7 の PUT /api/contacts で扱う。
final class EmergencyContactsRepository: EmergencyContactsRepositoryProtocol {
    private let writer: any DatabaseWriter

    nonisolated init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    nonisolated func count() async throws -> Int {
        try await writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM emergency_contacts") ?? 0
        }
    }

    nonisolated func list() async throws -> [EmergencyContact] {
        try await writer.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT id, email, label, sort_order, created_at
                FROM emergency_contacts
                ORDER BY sort_order ASC, id ASC
                """)
            return rows.compactMap(Self.decode(row:))
        }
    }

    nonisolated func add(email: String, label: String?, now: Date = Date()) async throws -> EmergencyContact {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLabel = (trimmedLabel?.isEmpty ?? true) ? nil : trimmedLabel
        let createdAt = HibixDate.iso8601String(from: now)
        return try await writer.write { db in
            let maxOrder = try Int.fetchOne(db, sql: "SELECT MAX(sort_order) FROM emergency_contacts") ?? -1
            let nextOrder = maxOrder + 1
            try db.execute(sql: """
                INSERT INTO emergency_contacts (email, label, sort_order, created_at)
                VALUES (?, ?, ?, ?)
                """, arguments: [trimmedEmail, normalizedLabel, nextOrder, createdAt])
            let id = db.lastInsertedRowID
            return EmergencyContact(
                id: id,
                email: trimmedEmail,
                label: normalizedLabel,
                sortOrder: nextOrder,
                createdAt: now
            )
        }
    }

    nonisolated func update(id: Int64, email: String, label: String?) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLabel = (trimmedLabel?.isEmpty ?? true) ? nil : trimmedLabel
        try await writer.write { db in
            try db.execute(sql: """
                UPDATE emergency_contacts
                SET email = ?, label = ?
                WHERE id = ?
                """, arguments: [trimmedEmail, normalizedLabel, id])
        }
    }

    nonisolated func delete(id: Int64) async throws {
        try await writer.write { db in
            try db.execute(sql: "DELETE FROM emergency_contacts WHERE id = ?", arguments: [id])
        }
    }

    private static func decode(row: Row) -> EmergencyContact? {
        guard let id: Int64 = row["id"],
              let email: String = row["email"],
              let sortOrder: Int = row["sort_order"],
              let createdAtRaw: String = row["created_at"],
              let createdAt = HibixDate.iso8601Date(from: createdAtRaw) else {
            return nil
        }
        let label: String? = row["label"]
        return EmergencyContact(
            id: id,
            email: email,
            label: label,
            sortOrder: sortOrder,
            createdAt: createdAt
        )
    }
}
