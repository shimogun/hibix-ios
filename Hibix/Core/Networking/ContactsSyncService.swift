import Foundation
import os.log

/// contacts / settings をサーバーへ同期し、PUT レスポンスの id をローカル row へ書き戻す。
///
/// - 失敗は best-effort（次回起動時に resync）。LINE フローからは `syncContactsThrowing()` を使う。
/// - App Attest 未登録なら read-only としてスキップ（CheckinService と同方針）。
/// - PRD v1.1 §8.3 / §8.4 / §8.12（C案: email/LINE 同列）。
@MainActor
final class ContactsSyncService {
    @ObservationIgnored private let apiClient: APIClient
    @ObservationIgnored private let contactsRepo: EmergencyContactsRepository
    @ObservationIgnored private let settings: SettingsRepository
    @ObservationIgnored private let attest: AppAttestClient
    @ObservationIgnored private weak var deletionPending: DeletionPendingCoordinator?

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "ContactsSync")

    init(apiClient: APIClient,
         contactsRepo: EmergencyContactsRepository,
         settings: SettingsRepository,
         attest: AppAttestClient,
         deletionPending: DeletionPendingCoordinator? = nil) {
        self.apiClient = apiClient
        self.contactsRepo = contactsRepo
        self.settings = settings
        self.attest = attest
        self.deletionPending = deletionPending
    }

    func attach(deletionPending: DeletionPendingCoordinator) {
        self.deletionPending = deletionPending
    }

    /// best-effort 同期（失敗はログのみ）。
    func syncContacts() async {
        do {
            try await syncContactsThrowing()
        } catch let error as APIError {
            Self.logger.error("syncContacts failed: \(error.localizedDescription, privacy: .public)")
            if error.isDeletionPending { deletionPending?.report(error) }
        } catch {
            Self.logger.error("syncContacts failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 同期を実行し失敗時は throw（LINE フロー用）。
    func syncContactsThrowing() async throws {
        guard attest.isSupported, attest.isRegistered else {
            Self.logger.notice("Skip contacts sync: attest unavailable (read-only mode)")
            return
        }
        let local = try await contactsRepo.list()   // sort_order 昇順
        let body = ContactsPutBody(contacts: local.map { contact in
            ContactInputBody(
                id: contact.serverID,
                contact_type: contact.contactType.rawValue,
                email: contact.contactType == .email ? contact.email : nil,
                label: contact.label
            )
        })
        let response: ContactsResponse = try await apiClient.request(.contacts(body))
        // リクエスト順＝レスポンス sort_order 順。index 対応で server_id を書き戻す。
        let pairs: [(localID: Int64, serverID: String)] = zip(local, response.contacts).map {
            (localID: $0.0.id, serverID: $0.1.id)
        }
        if !pairs.isEmpty {
            try await contactsRepo.updateServerMapping(pairs)
        }
    }

    /// 見守り設定をサーバーへ反映。`EMAIL_CONTACT_REQUIRED` 等は呼び出し元へ伝播。
    func syncSettings(watchMode: String, watchDays: Int) async throws {
        guard attest.isSupported, attest.isRegistered else {
            Self.logger.notice("Skip settings sync: attest unavailable (read-only mode)")
            return
        }
        let body = SettingsPatchBody(watch_days: watchDays, watch_mode: watchMode)
        let _: SettingsResponse = try await apiClient.request(.settings(body))
    }

    /// 起動時 / ネット復帰時の best-effort 同期。
    func resyncOnLaunch() async {
        await syncContacts()
    }
}
