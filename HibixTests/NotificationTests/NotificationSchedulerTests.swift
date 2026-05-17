import Testing
import Foundation
import GRDB
import UserNotifications
@testable import Hibix

@Suite("NotificationScheduler")
struct NotificationSchedulerTests {

    private func makeContext() throws -> (NotificationScheduler, FakeNotificationCenter, SettingsRepository) {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)
        let settings = SettingsRepository(writer: dbQueue)
        try settings.ensureDefaultsSync(now: Date())
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(center: center, settings: settings)
        return (scheduler, center, settings)
    }

    @Test
    func reschedule_defaults_addsMorningAndEvening() async throws {
        let (scheduler, center, _) = try makeContext()
        await scheduler.rescheduleDailyNotifications()

        let added = await center.addedRequests()
        let ids = added.map(\.identifier)
        #expect(ids.contains(NotificationIdentifier.dailyMorning))
        #expect(ids.contains(NotificationIdentifier.dailyEvening))

        let morning = added.first(where: { $0.identifier == NotificationIdentifier.dailyMorning })
        #expect(morning?.content.body == NotificationContent.dailyMorningBody)
        let morningTrigger = morning?.trigger as? UNCalendarNotificationTrigger
        #expect(morningTrigger?.repeats == true)
        #expect(morningTrigger?.dateComponents.hour == 9)
        #expect(morningTrigger?.dateComponents.minute == 0)

        let evening = added.first(where: { $0.identifier == NotificationIdentifier.dailyEvening })
        let eveningTrigger = evening?.trigger as? UNCalendarNotificationTrigger
        #expect(eveningTrigger?.dateComponents.hour == 21)
        #expect(eveningTrigger?.dateComponents.minute == 0)
    }

    @Test
    func reschedule_morningOff_cancelsMorning_keepsEvening() async throws {
        let (scheduler, center, settings) = try makeContext()
        try await settings.setString("off", forKey: .morningNotify, now: Date())

        await scheduler.rescheduleDailyNotifications()
        let added = await center.addedRequests()
        let ids = added.map(\.identifier)
        #expect(ids.contains(NotificationIdentifier.dailyEvening))
        #expect(!ids.contains(NotificationIdentifier.dailyMorning))

        let removed = await center.removedIdentifiers()
        #expect(removed.contains(NotificationIdentifier.dailyMorning))
    }

    @Test
    func reschedule_replacesExistingRequest() async throws {
        let (scheduler, center, settings) = try makeContext()
        await scheduler.rescheduleDailyNotifications()
        try await settings.setString("06:30", forKey: .morningNotify, now: Date())
        await scheduler.rescheduleDailyNotifications()

        let morningRequests = await center.addedRequests()
            .filter { $0.identifier == NotificationIdentifier.dailyMorning }
        #expect(morningRequests.count == 2)
        let latest = morningRequests.last
        let trigger = latest?.trigger as? UNCalendarNotificationTrigger
        #expect(trigger?.dateComponents.hour == 6)
        #expect(trigger?.dateComponents.minute == 30)
    }

    @Test
    func reschedule_invalidTime_cancelsRequest() async throws {
        let (scheduler, center, settings) = try makeContext()
        try await settings.setString("zzz", forKey: .morningNotify, now: Date())

        await scheduler.rescheduleDailyNotifications()
        let ids = await center.addedRequests().map(\.identifier)
        #expect(!ids.contains(NotificationIdentifier.dailyMorning))
        let removed = await center.removedIdentifiers()
        #expect(removed.contains(NotificationIdentifier.dailyMorning))
    }

    @Test
    func cancelDailyNotifications_removesBoth() async throws {
        let (scheduler, center, _) = try makeContext()
        scheduler.cancelDailyNotifications()
        let removed = await center.removedIdentifiers()
        #expect(removed.contains(NotificationIdentifier.dailyMorning))
        #expect(removed.contains(NotificationIdentifier.dailyEvening))
    }
}

// MARK: - Fakes

final class FakeNotificationCenter: UserNotificationCenter, @unchecked Sendable {
    private let lock = NSLock()
    private var added: [UNNotificationRequest] = []
    private var removed: [String] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        true
    }

    func notificationSettings() async -> UNNotificationSettings {
        fatalError("notificationSettings() not used in tests")
    }

    func add(_ request: UNNotificationRequest) async throws {
        lock.lock(); defer { lock.unlock() }
        added.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        lock.lock(); defer { lock.unlock() }
        removed.append(contentsOf: identifiers)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        lock.lock(); defer { lock.unlock() }
        return added
    }

    func addedRequests() async -> [UNNotificationRequest] {
        lock.lock(); defer { lock.unlock() }
        return added
    }

    func removedIdentifiers() async -> [String] {
        lock.lock(); defer { lock.unlock() }
        return removed
    }
}
