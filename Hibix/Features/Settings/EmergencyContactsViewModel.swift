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

    @ObservationIgnored private let repo: EmergencyContactsRepository

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "EmergencyContacts")

    init(repo: EmergencyContactsRepository) {
        self.repo = repo
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
        for contact in targets {
            do {
                try await repo.delete(id: contact.id)
            } catch {
                Self.logger.error("Delete contact failed: \(error.localizedDescription, privacy: .public)")
                lastErrorMessage = "削除に失敗しました"
            }
        }
        await load()
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
