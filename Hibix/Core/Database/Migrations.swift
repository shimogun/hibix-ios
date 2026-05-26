import Foundation
import GRDB

enum Migrations {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            try db.execute(sql: """
                CREATE TABLE mood_entries (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    entry_date TEXT NOT NULL UNIQUE,
                    mood_level INTEGER NOT NULL CHECK(mood_level BETWEEN 1 AND 7),
                    memo TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """)
            try db.execute(sql: "CREATE INDEX idx_mood_entries_date ON mood_entries(entry_date)")
            try db.execute(sql: """
                CREATE TABLE settings (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """)
            try db.execute(sql: """
                CREATE TABLE emergency_contacts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    email TEXT NOT NULL,
                    label TEXT,
                    sort_order INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL
                )
                """)
        }

        migrator.registerMigration("v2_emergency_contact_add_kind") { db in
            try db.execute(sql: """
                ALTER TABLE emergency_contacts
                ADD COLUMN contact_type TEXT NOT NULL DEFAULT 'email'
                """)
        }

        return migrator
    }
}
