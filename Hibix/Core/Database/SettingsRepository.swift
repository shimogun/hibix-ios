import Foundation
import GRDB

protocol SettingsRepositoryProtocol: Sendable {
    func string(forKey key: SettingsKey) async throws -> String?
    func bool(forKey key: SettingsKey) async throws -> Bool
    func setString(_ value: String, forKey key: SettingsKey, now: Date) async throws
    func setBool(_ value: Bool, forKey key: SettingsKey, now: Date) async throws
    func ensureDefaults(now: Date) async throws
}

enum SettingsKey: String, CaseIterable, Sendable {
    case watchMode = "watch_mode"
    case watchDays = "watch_days"
    case morningNotify = "morning_notify"
    case eveningNotify = "evening_notify"
    case appLockEnabled = "app_lock_enabled"
    case onboardingDone = "onboarding_done"
    case lastSyncedAt = "last_synced_at"

    nonisolated var defaultValue: String? {
        switch self {
        case .watchMode: return "solo"
        case .watchDays: return "2"
        case .morningNotify: return "09:00"
        case .eveningNotify: return "21:00"
        case .appLockEnabled: return "false"
        case .onboardingDone: return "false"
        case .lastSyncedAt: return nil
        }
    }
}

/// 'HH:mm' 形式の通知時刻、または通知無効を表す 'off'。
enum NotifyTime: Equatable, Sendable {
    case time(hour: Int, minute: Int)
    case off

    static func parse(_ raw: String?) -> NotifyTime? {
        guard let raw else { return nil }
        if raw == "off" { return .off }
        let parts = raw.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return .time(hour: hour, minute: minute)
    }

    var stringValue: String {
        switch self {
        case .off: return "off"
        case .time(let hour, let minute):
            return String(format: "%02d:%02d", hour, minute)
        }
    }
}

final class SettingsRepository: SettingsRepositoryProtocol {
    private let writer: any DatabaseWriter

    nonisolated init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    nonisolated func string(forKey key: SettingsKey) async throws -> String? {
        try await writer.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT value FROM settings WHERE key = ?",
                arguments: [key.rawValue]
            )
        }
    }

    nonisolated func bool(forKey key: SettingsKey) async throws -> Bool {
        let raw = try await string(forKey: key)
        return raw == "true"
    }

    nonisolated func setString(_ value: String,
                               forKey key: SettingsKey,
                               now: Date = Date()) async throws {
        let timestamp = HibixDate.iso8601String(from: now)
        try await writer.write { db in
            try db.execute(sql: """
                INSERT INTO settings (key, value, updated_at)
                VALUES (?, ?, ?)
                ON CONFLICT(key) DO UPDATE SET
                    value = excluded.value,
                    updated_at = excluded.updated_at
                """, arguments: [key.rawValue, value, timestamp])
        }
    }

    nonisolated func setBool(_ value: Bool,
                             forKey key: SettingsKey,
                             now: Date = Date()) async throws {
        try await setString(value ? "true" : "false", forKey: key, now: now)
    }

    nonisolated func ensureDefaults(now: Date = Date()) async throws {
        let timestamp = HibixDate.iso8601String(from: now)
        try await writer.write { db in
            try Self.insertDefaults(db: db, timestamp: timestamp)
        }
    }

    nonisolated func ensureDefaultsSync(now: Date = Date()) throws {
        let timestamp = HibixDate.iso8601String(from: now)
        try writer.write { db in
            try Self.insertDefaults(db: db, timestamp: timestamp)
        }
    }

    nonisolated private static func insertDefaults(db: Database, timestamp: String) throws {
        for key in SettingsKey.allCases {
            guard let defaultValue = key.defaultValue else { continue }
            try db.execute(sql: """
                INSERT OR IGNORE INTO settings (key, value, updated_at)
                VALUES (?, ?, ?)
                """, arguments: [key.rawValue, defaultValue, timestamp])
        }
    }
}
