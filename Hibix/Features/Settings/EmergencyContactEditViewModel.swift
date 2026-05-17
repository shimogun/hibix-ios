import Foundation
import Observation
import os.log

/// `EmergencyContactEditView` の状態管理。新規/編集を 1 つの ViewModel で扱う。
/// 保存実行時に Entitlement を判定し、無料なら Paywall を起動する(F-07: Entitlement = 有料のみ)。
@MainActor
@Observable
final class EmergencyContactEditViewModel {
    enum Mode: Equatable {
        case new
        case existing(EmergencyContact)

        var existingId: Int64? {
            if case .existing(let contact) = self { return contact.id }
            return nil
        }
    }

    var email: String
    var label: String

    var isPaywallPresented: Bool = false
    private(set) var saveErrorMessage: String?
    private(set) var isSaving: Bool = false

    @ObservationIgnored private let mode: Mode
    @ObservationIgnored private let repo: EmergencyContactsRepository
    @ObservationIgnored private let entitlement: EntitlementManager

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "EmergencyContactEdit")

    init(mode: Mode,
         repo: EmergencyContactsRepository,
         entitlement: EntitlementManager) {
        self.mode = mode
        self.repo = repo
        self.entitlement = entitlement
        switch mode {
        case .new:
            self.email = ""
            self.label = ""
        case .existing(let contact):
            self.email = contact.email
            self.label = contact.label ?? ""
        }
    }

    var isExisting: Bool {
        if case .existing = mode { return true }
        return false
    }

    var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isInputValid: Bool {
        Self.isValidEmail(trimmedEmail)
    }

    /// 保存を試みる。無料なら Paywall を出して return。成功で true。
    func save() async -> Bool {
        guard isInputValid else {
            saveErrorMessage = "メールアドレスの形式が正しくありません"
            return false
        }
        if !entitlement.isPro {
            isPaywallPresented = true
            return false
        }
        isSaving = true
        defer { isSaving = false }
        saveErrorMessage = nil
        do {
            switch mode {
            case .new:
                _ = try await repo.add(email: trimmedEmail, label: label, now: Date())
            case .existing(let contact):
                try await repo.update(id: contact.id, email: trimmedEmail, label: label)
            }
            return true
        } catch {
            Self.logger.error("Save contact failed: \(error.localizedDescription, privacy: .public)")
            saveErrorMessage = "保存に失敗しました。時間を置いて再度お試しください"
            return false
        }
    }

    /// 削除(編集モードのみ)。
    func delete() async -> Bool {
        guard case .existing(let contact) = mode else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await repo.delete(id: contact.id)
            return true
        } catch {
            Self.logger.error("Delete contact failed: \(error.localizedDescription, privacy: .public)")
            saveErrorMessage = "削除に失敗しました"
            return false
        }
    }

    private static func isValidEmail(_ s: String) -> Bool {
        guard !s.isEmpty, s.count <= 254 else { return false }
        // ローカル部: @ と空白を含まない 1 文字以上
        // ドメイン部: @ と空白とドットを含まない 1 文字以上 + . + 英字 2 文字以上の TLD
        let pattern = #"^[^@\s]+@[^@\s.]+\.[A-Za-z]{2,}$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }
}
