import Foundation
import Observation
import UserNotifications
import os.log

@MainActor
@Observable
final class AppDependencies {
    let database: DatabaseManager
    let keychain: KeychainStore
    let anonymousUUID: String
    let moodEntryRepository: MoodEntryRepository
    let settingsRepository: SettingsRepository
    let notificationScheduler: NotificationScheduler
    let notificationTapCoordinator: NotificationTapCoordinator

    /// オンボーディング完了済みか。未ロード時は nil（RootView は読み込み待ち画面を出す）。
    private(set) var onboardingDone: Bool?

    @ObservationIgnored
    private let notificationDelegateAdapter: NotificationDelegateAdapter

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "App")

    init() throws {
        let databaseURL = try DatabaseManager.defaultURL()
        let database = try DatabaseManager(databaseURL: databaseURL)
        self.database = database
        let store = KeychainStore()
        self.keychain = store
        self.anonymousUUID = try store.loadOrIssueAnonymousUUID()
        self.moodEntryRepository = MoodEntryRepository(writer: database.dbPool)
        let settings = SettingsRepository(writer: database.dbPool)
        try settings.ensureDefaultsSync()
        self.settingsRepository = settings
        self.notificationScheduler = NotificationScheduler(settings: settings)
        let coordinator = NotificationTapCoordinator()
        self.notificationTapCoordinator = coordinator
        self.notificationDelegateAdapter = NotificationDelegateAdapter(coordinator: coordinator)
        Self.logger.info("AppDependencies bootstrapped")
    }

    /// 起動直後に呼び出すウォームアップ処理。
    /// - 通知 delegate を装着
    /// - settings.onboarding_done を読み込み observable state へ反映
    /// - 朝/夜通知の予約状態を整える
    func warmUp() async {
        UNUserNotificationCenter.current().delegate = notificationDelegateAdapter
        do {
            onboardingDone = try await settingsRepository.bool(forKey: .onboardingDone)
        } catch {
            Self.logger.error("Load onboarding_done failed: \(error.localizedDescription, privacy: .public)")
            onboardingDone = false
        }
        await notificationScheduler.rescheduleDailyNotifications()
    }

    func markOnboardingDone() {
        onboardingDone = true
    }
}
