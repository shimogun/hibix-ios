import Foundation
import os.log

/// LINE 連携コード方式（友だち追加→6桁コード→push）のクライアント側オーケストレータ。
///
/// - issue-code / status はサーバー contact UUID(`server_id`)が前提。未取得なら先に contacts を同期する。
/// - 連携状態はローカル `line_link_status` に反映する。
/// - PRD v1.1 §8.12（C案: email/LINE 同列）。
@MainActor
final class LineLinkService {
    /// 発行された連携コードと友だち追加リンク。
    struct LineLinkCode: Equatable {
        let code: String
        let expiresAt: Date
        let addFriendURL: URL?
    }

    enum LineLinkError: Error {
        /// 同期しても server_id を得られなかった（連絡先が未保存等）。
        case notSynced
    }

    @ObservationIgnored private let apiClient: APIClient
    @ObservationIgnored private let contactsRepo: EmergencyContactsRepository
    @ObservationIgnored private let contactsSync: ContactsSyncService

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "LineLink")

    init(apiClient: APIClient,
         contactsRepo: EmergencyContactsRepository,
         contactsSync: ContactsSyncService) {
        self.apiClient = apiClient
        self.contactsRepo = contactsRepo
        self.contactsSync = contactsSync
    }

    /// 連携コードを発行する。server_id 未取得なら先に contacts を同期して解決する。
    func issueCode(localContactID: Int64) async throws -> LineLinkCode {
        let serverID = try await resolveServerID(localContactID: localContactID)
        let response: LineIssueCodeResponse = try await apiClient.request(.lineIssueCode(serverContactID: serverID))
        try await contactsRepo.updateLineLinkStatus(localID: localContactID, status: .pending)
        return LineLinkCode(
            code: response.code,
            expiresAt: Date(timeIntervalSince1970: TimeInterval(response.expires_at)),
            addFriendURL: response.add_friend_url.flatMap(URL.init(string:))
        )
    }

    /// 連携ステータスを取得し、ローカルへ反映する。
    @discardableResult
    func fetchStatus(localContactID: Int64) async throws -> LineLinkStatus {
        let serverID = try await resolveServerID(localContactID: localContactID)
        let response: LineStatusResponse = try await apiClient.request(.lineStatus(serverContactID: serverID))
        let status = LineLinkStatus.fromStoredValue(response.status)
        try await contactsRepo.updateLineLinkStatus(localID: localContactID, status: status)
        return status
    }

    // MARK: - Private

    private func resolveServerID(localContactID: Int64) async throws -> String {
        if let serverID = try await serverID(for: localContactID) {
            return serverID
        }
        try await contactsSync.syncContactsThrowing()
        guard let serverID = try await serverID(for: localContactID) else {
            throw LineLinkError.notSynced
        }
        return serverID
    }

    private func serverID(for localContactID: Int64) async throws -> String? {
        try await contactsRepo.list().first(where: { $0.id == localContactID })?.serverID
    }
}
