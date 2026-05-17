import Foundation
import Observation
import StoreKit
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
    let apiClient: APIClient
    let appAttestClient: AppAttestClient
    let checkinService: CheckinService
    let entitlementManager: EntitlementManager
    let storeKitVerifyService: StoreKitVerifyService

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
        let uuid = try store.loadOrIssueAnonymousUUID()
        self.anonymousUUID = uuid
        let moodRepo = MoodEntryRepository(writer: database.dbPool)
        self.moodEntryRepository = moodRepo
        let settings = SettingsRepository(writer: database.dbPool)
        try settings.ensureDefaultsSync()
        self.settingsRepository = settings
        self.notificationScheduler = NotificationScheduler(settings: settings)
        let coordinator = NotificationTapCoordinator()
        self.notificationTapCoordinator = coordinator
        self.notificationDelegateAdapter = NotificationDelegateAdapter(coordinator: coordinator)

        let apiClient = APIClient(anonymousUUID: uuid)
        self.apiClient = apiClient

        let attestService = DefaultAppAttestService()
        let attestStore = AppAttestKeyStore()
        let attestClient = AppAttestClient(
            service: attestService,
            store: attestStore,
            fetchChallenge: { [weak apiClient] in
                guard let apiClient else { throw APIError.configuration("APIClient released") }
                return try await apiClient.request(.attestChallenge)
            },
            register: { [weak apiClient] body in
                guard let apiClient else { throw APIError.configuration("APIClient released") }
                let _: AttestRegisterResponse = try await apiClient.request(.attestRegister(body))
            }
        )
        self.appAttestClient = attestClient
        apiClient.attach(attestClient: attestClient)

        self.checkinService = CheckinService(
            apiClient: apiClient,
            settings: settings,
            moodEntries: moodRepo,
            attest: attestClient
        )

        let verifyService = StoreKitVerifyService(apiClient: apiClient, attest: attestClient)
        self.storeKitVerifyService = verifyService

        self.entitlementManager = EntitlementManager(
            keychain: store,
            onVerifyTransaction: { @Sendable [weak verifyService] transaction in
                await verifyService?.verify(transaction)
            }
        )

        Self.logger.info("AppDependencies bootstrapped")
    }

    /// 起動直後に呼び出すウォームアップ処理。
    /// - 通知 delegate を装着
    /// - settings.onboarding_done を読み込み observable state へ反映
    /// - 朝/夜通知の予約状態を整える
    /// - App Attest 登録(未登録のみ初回)
    /// - 未送信 checkin の resync
    /// - Entitlement 復元 + Transaction.updates 監視開始
    func warmUp() async {
        UNUserNotificationCenter.current().delegate = notificationDelegateAdapter
        do {
            onboardingDone = try await settingsRepository.bool(forKey: .onboardingDone)
        } catch {
            Self.logger.error("Load onboarding_done failed: \(error.localizedDescription, privacy: .public)")
            onboardingDone = false
        }
        await notificationScheduler.rescheduleDailyNotifications()

        await entitlementManager.warmUp()

        // App Attest 登録は backend 疎通を伴うため、失敗してもアプリ起動を阻害しない。
        let registered = await appAttestClient.ensureRegistered()
        if registered {
            await checkinService.resyncPendingCheckins()
        } else {
            Self.logger.notice("App Attest unavailable; running in read-only mode")
        }
    }

    func markOnboardingDone() {
        onboardingDone = true
    }
}
