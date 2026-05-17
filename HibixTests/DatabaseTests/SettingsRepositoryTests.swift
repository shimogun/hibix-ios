import Testing
import Foundation
import GRDB
@testable import Hibix

@Suite("SettingsRepository")
struct SettingsRepositoryTests {

    private func makeRepository() throws -> (SettingsRepository, DatabaseQueue) {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)
        return (SettingsRepository(writer: dbQueue), dbQueue)
    }

    @Test
    func ensureDefaults_insertsAllKnownDefaults() async throws {
        let (repo, _) = try makeRepository()
        try await repo.ensureDefaults(now: Date(timeIntervalSince1970: 0))

        #expect(try await repo.string(forKey: .watchMode) == "solo")
        #expect(try await repo.string(forKey: .watchDays) == "2")
        #expect(try await repo.string(forKey: .morningNotify) == "09:00")
        #expect(try await repo.string(forKey: .eveningNotify) == "21:00")
        #expect(try await repo.string(forKey: .appLockEnabled) == "false")
        #expect(try await repo.string(forKey: .onboardingDone) == "false")
    }

    @Test
    func ensureDefaults_doesNotOverwriteExistingValues() async throws {
        let (repo, _) = try makeRepository()
        try await repo.ensureDefaults(now: Date(timeIntervalSince1970: 0))
        try await repo.setBool(true, forKey: .onboardingDone, now: Date(timeIntervalSince1970: 100))
        try await repo.setString("07:30", forKey: .morningNotify, now: Date(timeIntervalSince1970: 100))

        try await repo.ensureDefaults(now: Date(timeIntervalSince1970: 200))

        #expect(try await repo.bool(forKey: .onboardingDone) == true)
        #expect(try await repo.string(forKey: .morningNotify) == "07:30")
    }

    @Test
    func setBool_andBool_roundTrip() async throws {
        let (repo, _) = try makeRepository()
        try await repo.setBool(true, forKey: .onboardingDone, now: Date())
        #expect(try await repo.bool(forKey: .onboardingDone) == true)
        try await repo.setBool(false, forKey: .onboardingDone, now: Date())
        #expect(try await repo.bool(forKey: .onboardingDone) == false)
    }

    @Test
    func setString_updatesExistingRow() async throws {
        let (repo, _) = try makeRepository()
        try await repo.setString("09:00", forKey: .morningNotify, now: Date())
        try await repo.setString("08:15", forKey: .morningNotify, now: Date())
        #expect(try await repo.string(forKey: .morningNotify) == "08:15")
    }

    @Test
    func ensureDefaultsSync_writesDefaults() throws {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)
        let repo = SettingsRepository(writer: dbQueue)
        try repo.ensureDefaultsSync(now: Date())

        try dbQueue.read { db in
            let value = try String.fetchOne(db,
                                            sql: "SELECT value FROM settings WHERE key = ?",
                                            arguments: ["watch_mode"])
            #expect(value == "solo")
        }
    }
}

@Suite("NotifyTime parsing")
struct NotifyTimeTests {

    @Test
    func parse_validTime_returnsTimeCase() {
        let parsed = NotifyTime.parse("09:00")
        #expect(parsed == .time(hour: 9, minute: 0))
    }

    @Test
    func parse_off_returnsOff() {
        #expect(NotifyTime.parse("off") == .off)
    }

    @Test
    func parse_nil_returnsNil() {
        #expect(NotifyTime.parse(nil) == nil)
    }

    @Test
    func parse_invalidFormats_returnNil() {
        #expect(NotifyTime.parse("") == nil)
        #expect(NotifyTime.parse("9:00") == .time(hour: 9, minute: 0))
        #expect(NotifyTime.parse("24:00") == nil)
        #expect(NotifyTime.parse("12:60") == nil)
        #expect(NotifyTime.parse("foo") == nil)
        #expect(NotifyTime.parse("12-30") == nil)
    }

    @Test
    func stringValue_roundTripsTimeAndOff() {
        #expect(NotifyTime.time(hour: 9, minute: 0).stringValue == "09:00")
        #expect(NotifyTime.time(hour: 21, minute: 5).stringValue == "21:05")
        #expect(NotifyTime.off.stringValue == "off")
    }
}
