import Testing
import Foundation
import GRDB
@testable import Hibix

@Suite("EmergencyContactsRepository")
struct EmergencyContactsRepositoryTests {

    private func makeRepository() throws -> (EmergencyContactsRepository, DatabaseQueue) {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)
        let repo = EmergencyContactsRepository(writer: dbQueue)
        return (repo, dbQueue)
    }

    private let fixedNow = Date(timeIntervalSince1970: 1_747_440_000)

    @Test
    func add_persistsEmailContact() async throws {
        let (repo, _) = try makeRepository()
        let contact = try await repo.add(contactType: .email,
                                         value: "mom@example.com",
                                         label: "お母さん",
                                         now: fixedNow)
        #expect(contact.contactType == .email)
        #expect(contact.email == "mom@example.com")
        #expect(contact.label == "お母さん")
        #expect(contact.sortOrder == 0)
    }

    @Test
    func add_persistsLineContact() async throws {
        let (repo, _) = try makeRepository()
        let contact = try await repo.add(contactType: .line,
                                         value: "https://line.me/ti/p/xyz",
                                         label: "兄",
                                         now: fixedNow)
        #expect(contact.contactType == .line)
        #expect(contact.email == "https://line.me/ti/p/xyz")
    }

    @Test
    func list_returnsContactsInSortOrder_withMixedTypes() async throws {
        let (repo, _) = try makeRepository()
        _ = try await repo.add(contactType: .email, value: "a@example.com", label: "A", now: fixedNow)
        _ = try await repo.add(contactType: .line, value: "@line_b", label: "B", now: fixedNow)
        _ = try await repo.add(contactType: .email, value: "c@example.com", label: "C", now: fixedNow)
        let list = try await repo.list()
        #expect(list.count == 3)
        #expect(list[0].contactType == .email)
        #expect(list[1].contactType == .line)
        #expect(list[2].contactType == .email)
    }

    @Test
    func legacyRecord_withoutContactType_decodesAsEmail() async throws {
        // v1 互換: contact_type カラムが migration v2 で default 'email' になることを検証
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)
        try await dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO emergency_contacts (email, label, sort_order, created_at)
                VALUES ('legacy@example.com', 'legacy', 0, ?)
                """, arguments: [HibixDate.iso8601String(from: self.fixedNow)])
        }
        let repo = EmergencyContactsRepository(writer: dbQueue)
        let list = try await repo.list()
        #expect(list.count == 1)
        #expect(list.first?.contactType == .email)
        #expect(list.first?.email == "legacy@example.com")
    }

    @Test
    func update_changesContactType() async throws {
        let (repo, _) = try makeRepository()
        let contact = try await repo.add(contactType: .email,
                                         value: "old@example.com",
                                         label: nil,
                                         now: fixedNow)
        try await repo.update(id: contact.id,
                              contactType: .line,
                              value: "@new_line",
                              label: "切替後")
        let list = try await repo.list()
        #expect(list.first?.contactType == .line)
        #expect(list.first?.email == "@new_line")
        #expect(list.first?.label == "切替後")
    }
}
