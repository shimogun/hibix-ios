import Testing
import GRDB
@testable import Hibix

@Suite("Migrations v1")
struct MigrationsTests {

    @Test
    func v1Initial_createsExpectedSchema() throws {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)

        try dbQueue.read { db in
            let moodExists = try db.tableExists("mood_entries")
            let settingsExists = try db.tableExists("settings")
            let contactsExists = try db.tableExists("emergency_contacts")
            #expect(moodExists)
            #expect(settingsExists)
            #expect(contactsExists)

            let moodColumns = Set(try db.columns(in: "mood_entries").map(\.name))
            #expect(moodColumns == ["id", "entry_date", "mood_level", "memo", "created_at", "updated_at"])

            let settingsColumns = Set(try db.columns(in: "settings").map(\.name))
            #expect(settingsColumns == ["key", "value", "updated_at"])

            let contactsColumns = Set(try db.columns(in: "emergency_contacts").map(\.name))
            #expect(contactsColumns == ["id", "email", "label", "sort_order", "created_at"])

            let indexNames = try db.indexes(on: "mood_entries").map(\.name)
            #expect(indexNames.contains("idx_mood_entries_date"))
        }
    }

    @Test
    func moodLevelCheckConstraint_rejectsOutOfRange() throws {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)

        #expect(throws: (any Error).self) {
            try dbQueue.write { db in
                try db.execute(sql: """
                    INSERT INTO mood_entries (entry_date, mood_level, created_at, updated_at)
                    VALUES ('2026-01-01', 8, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
                    """)
            }
        }

        #expect(throws: (any Error).self) {
            try dbQueue.write { db in
                try db.execute(sql: """
                    INSERT INTO mood_entries (entry_date, mood_level, created_at, updated_at)
                    VALUES ('2026-01-02', 0, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
                    """)
            }
        }
    }

    @Test
    func entryDateUnique_preventsDuplicate() throws {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)

        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO mood_entries (entry_date, mood_level, created_at, updated_at)
                VALUES ('2026-01-01', 5, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
                """)
        }

        #expect(throws: (any Error).self) {
            try dbQueue.write { db in
                try db.execute(sql: """
                    INSERT INTO mood_entries (entry_date, mood_level, created_at, updated_at)
                    VALUES ('2026-01-01', 3, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
                    """)
            }
        }
    }

    @Test
    func migrator_isIdempotent() throws {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)
        try Migrations.migrator.migrate(dbQueue)

        try dbQueue.read { db in
            let moodExists = try db.tableExists("mood_entries")
            let settingsExists = try db.tableExists("settings")
            let contactsExists = try db.tableExists("emergency_contacts")
            #expect(moodExists)
            #expect(settingsExists)
            #expect(contactsExists)
        }
    }
}
