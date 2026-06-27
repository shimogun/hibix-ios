import Foundation
import GRDB

protocol EmergencyContactsRepositoryProtocol: Sendable {
    func count() async throws -> Int
    func list() async throws -> [EmergencyContact]
    func add(contactType: ContactType, value: String, label: String?, now: Date) async throws -> EmergencyContact
    func update(id: Int64, contactType: ContactType, value: String, label: String?) async throws
    func delete(id: Int64) async throws
    func updateServerMapping(_ pairs: [(localID: Int64, serverID: String)]) async throws
    func updateLineLinkStatus(localID: Int64, status: LineLinkStatus) async throws
}

/// `emergency_contacts` テーブルへのアクセス (PRD §6 F-07)。
/// サーバー暗号化(C-03 / AES-256-GCM)は PUT /api/contacts(backend)で扱う。
/// v0.2: contact_type カラム(email/line)。v1.1: server_id / line_link_status(C案: email/LINE 同列)。
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
                SELECT id, email, label, sort_order, created_at, contact_type, server_id, line_link_status
                FROM emergency_contacts
                ORDER BY sort_order ASC, id ASC
                """)
            return rows.compactMap(Self.decode(row:))
        }
    }

    nonisolated func add(contactType: ContactType,
                         value: String,
                         label: String?,
                         now: Date = Date()) async throws -> EmergencyContact {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLabel = (trimmedLabel?.isEmpty ?? true) ? nil : trimmedLabel
        let createdAt = HibixDate.iso8601String(from: now)
        return try await writer.write { db in
            let maxOrder = try Int.fetchOne(db, sql: "SELECT MAX(sort_order) FROM emergency_contacts") ?? -1
            let nextOrder = maxOrder + 1
            try db.execute(sql: """
                INSERT INTO emergency_contacts (email, label, sort_order, created_at, contact_type)
                VALUES (?, ?, ?, ?, ?)
                """, arguments: [trimmedValue, normalizedLabel, nextOrder, createdAt, contactType.rawValue])
            let id = db.lastInsertedRowID
            return EmergencyContact(
                id: id,
                contactType: contactType,
                email: trimmedValue,
                label: normalizedLabel,
                sortOrder: nextOrder,
                createdAt: now,
                serverID: nil,
                lineLinkStatus: .unlinked
            )
        }
    }

    nonisolated func update(id: Int64,
                            contactType: ContactType,
                            value: String,
                            label: String?) async throws {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLabel = (trimmedLabel?.isEmpty ?? true) ? nil : trimmedLabel
        try await writer.write { db in
            let currentRaw: String? = try String.fetchOne(
                db, sql: "SELECT contact_type FROM emergency_contacts WHERE id = ?", arguments: [id])
            let typeChanged = ContactType.fromStoredValue(currentRaw) != contactType
            if typeChanged {
                // 種別変更時は LINE 連携状態をリセット(server_id は upsert で保持)。
                try db.execute(sql: """
                    UPDATE emergency_contacts
                    SET email = ?, label = ?, contact_type = ?, line_link_status = 'unlinked'
                    WHERE id = ?
                    """, arguments: [trimmedValue, normalizedLabel, contactType.rawValue, id])
            } else {
                try db.execute(sql: """
                    UPDATE emergency_contacts
                    SET email = ?, label = ?, contact_type = ?
                    WHERE id = ?
                    """, arguments: [trimmedValue, normalizedLabel, contactType.rawValue, id])
            }
        }
    }

    nonisolated func delete(id: Int64) async throws {
        try await writer.write { db in
            try db.execute(sql: "DELETE FROM emergency_contacts WHERE id = ?", arguments: [id])
        }
    }

    /// PUT /api/contacts のレスポンス id をローカル row に書き戻す。
    nonisolated func updateServerMapping(_ pairs: [(localID: Int64, serverID: String)]) async throws {
        try await writer.write { db in
            for pair in pairs {
                try db.execute(sql: "UPDATE emergency_contacts SET server_id = ? WHERE id = ?",
                               arguments: [pair.serverID, pair.localID])
            }
        }
    }

    nonisolated func updateLineLinkStatus(localID: Int64, status: LineLinkStatus) async throws {
        try await writer.write { db in
            try db.execute(sql: "UPDATE emergency_contacts SET line_link_status = ? WHERE id = ?",
                           arguments: [status.rawValue, localID])
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
        let contactTypeRaw: String? = row["contact_type"]
        let contactType = ContactType.fromStoredValue(contactTypeRaw)
        let serverID: String? = row["server_id"]
        let lineLinkStatus = LineLinkStatus.fromStoredValue(row["line_link_status"])
        return EmergencyContact(
            id: id,
            contactType: contactType,
            email: email,
            label: label,
            sortOrder: sortOrder,
            createdAt: createdAt,
            serverID: serverID,
            lineLinkStatus: lineLinkStatus
        )
    }
}
