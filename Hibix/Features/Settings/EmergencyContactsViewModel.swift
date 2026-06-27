import Foundation
import Observation
import os.log

/// PRD v2.2.0 §6 F-07 緊急連絡先一覧。
///
/// - 表示・削除は全層
/// - 追加/編集の「保存」は有料のみ(`EmergencyContactEditViewModel` 側でゲート)
/// - 最大 3 件
@MainActor
@Observable
final class EmergencyContactsViewModel {
    static let maxContacts = 3

    private(set) var contacts: [EmergencyContact] = []
    private(set) var lastErrorMessage: String?
    var editingTarget: EditingTarget?
    /// gentle/daily 中に最後の email 連絡先を削除しようとしたとき true（先回りバリデーション）。
    var blockedByEmailRequirement: Bool = false

    @ObservationIgnored private let repo: EmergencyContactsRepository
    @ObservationIgnored private let contactsSync: ContactsSyncService
    @ObservationIgnored private let settings: SettingsRepository

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "EmergencyContacts")

    init(repo: EmergencyContactsRepository,
         contactsSync: ContactsSyncService,
         settings: SettingsRepository) {
        self.repo = repo
        self.contactsSync = contactsSync
        self.settings = settings
    }

    var canAdd: Bool {
        contacts.count < Self.maxContacts
    }

    func load() async {
        do {
            contacts = try await repo.list()
        } catch {
            Self.logger.error("List contacts failed: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = "連絡先の読み込みに失敗しました"
        }
    }

    func presentAddSheet() {
        guard canAdd else { return }
        editingTarget = .new
    }

    func presentEditSheet(_ contact: EmergencyContact) {
        editingTarget = .existing(contact)
    }

    func dismissEditSheet() {
        editingTarget = nil
    }

    func delete(at offsets: IndexSet) async {
        let targets = offsets.compactMap { contacts.indices.contains($0) ? contacts[$0] : nil }

        // gentle/daily 中に最後の email 連絡先を失う削除はブロック（サーバー M-01 先回り）。
        let notifying = WatchMode.isNotifyingRawValue(try? await settings.string(forKey: .watchMode))
        if notifying {
            let totalEmails = contacts.filter { $0.contactType == .email }.count
            let deletedEmails = targets.filter { $0.contactType == .email }.count
            if totalEmails - deletedEmails == 0 {
                blockedByEmailRequirement = true
                return
            }
        }

        for contact in targets {
            do {
                try await repo.delete(id: contact.id)
            } catch {
                Self.logger.error("Delete contact failed: \(error.localizedDescription, privacy: .public)")
                lastErrorMessage = "削除に失敗しました"
            }
        }
        await load()
        await contactsSync.syncContacts()
    }

    enum EditingTarget: Identifiable, Equatable {
        case new
        case existing(EmergencyContact)

        var id: String {
            switch self {
            case .new: return "new"
            case .existing(let contact): return "existing-\(contact.id)"
            }
        }
    }
}
