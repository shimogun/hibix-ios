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

    var contactType: ContactType
    var value: String
    var label: String

    var isPaywallPresented: Bool = false
    private(set) var saveErrorMessage: String?
    private(set) var isSaving: Bool = false

    @ObservationIgnored private var mode: Mode
    @ObservationIgnored private let repo: EmergencyContactsRepository
    @ObservationIgnored private let entitlement: EntitlementManager
    @ObservationIgnored private let contactsSync: ContactsSyncService
    @ObservationIgnored private let settings: SettingsRepository

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "EmergencyContactEdit")

    init(mode: Mode,
         repo: EmergencyContactsRepository,
         entitlement: EntitlementManager,
         contactsSync: ContactsSyncService,
         settings: SettingsRepository) {
        self.mode = mode
        self.repo = repo
        self.entitlement = entitlement
        self.contactsSync = contactsSync
        self.settings = settings
        switch mode {
        case .new:
            self.contactType = .email
            self.value = ""
            self.label = ""
        case .existing(let contact):
            self.contactType = contact.contactType
            self.value = contact.email
            self.label = contact.label ?? ""
        }
    }

    var isExisting: Bool {
        if case .existing = mode { return true }
        return false
    }

    /// 編集中の既存連絡先（新規時は nil）。LINE 連携状態バッジ表示に使う。
    var editingContact: EmergencyContact? {
        if case .existing(let contact) = mode { return contact }
        return nil
    }

    var trimmedValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isInputValid: Bool {
        Self.isValid(contactType: contactType, value: trimmedValue)
    }

    /// 保存を試みる。無料なら Paywall を出して return。成功で true。
    func save() async -> Bool {
        guard isInputValid else {
            saveErrorMessage = Self.invalidMessage(for: contactType)
            return false
        }
        if !entitlement.isPro {
            isPaywallPresented = true
            return false
        }
        // 種別を email から別種別へ変える操作で、見守りモード中に email を0件にするのはブロック。
        if case .existing(let contact) = mode,
           contact.contactType == .email, contactType != .email,
           await removingEmailWouldViolate() {
            saveErrorMessage = Self.emailRequiredMessage
            return false
        }
        isSaving = true
        defer { isSaving = false }
        saveErrorMessage = nil
        do {
            switch mode {
            case .new:
                _ = try await repo.add(contactType: contactType,
                                       value: trimmedValue,
                                       label: label,
                                       now: Date())
            case .existing(let contact):
                try await repo.update(id: contact.id,
                                      contactType: contactType,
                                      value: trimmedValue,
                                      label: label)
            }
            await contactsSync.syncContacts()
            return true
        } catch {
            Self.logger.error("Save contact failed: \(error.localizedDescription, privacy: .public)")
            saveErrorMessage = "保存に失敗しました。時間を置いて再度お試しください"
            return false
        }
    }

    /// LINE 連携の前段: 入力を保存し contacts を同期して localContactID を返す。
    /// 新規連絡先は保存後に編集モードへ昇格させ、後続の「保存」で重複追加されないようにする。
    func prepareLineLink() async -> Int64? {
        guard isInputValid else {
            saveErrorMessage = Self.invalidMessage(for: contactType)
            return nil
        }
        if !entitlement.isPro {
            isPaywallPresented = true
            return nil
        }
        isSaving = true
        defer { isSaving = false }
        saveErrorMessage = nil
        do {
            switch mode {
            case .new:
                let created = try await repo.add(contactType: .line,
                                                 value: trimmedValue,
                                                 label: label,
                                                 now: Date())
                mode = .existing(created)
                try await contactsSync.syncContactsThrowing()
                return created.id
            case .existing(let contact):
                try await repo.update(id: contact.id,
                                      contactType: .line,
                                      value: trimmedValue,
                                      label: label)
                try await contactsSync.syncContactsThrowing()
                return contact.id
            }
        } catch {
            Self.logger.error("prepareLineLink failed: \(error.localizedDescription, privacy: .public)")
            saveErrorMessage = "連携の準備に失敗しました。通信状況を確認して、もう一度お試しください。"
            return nil
        }
    }

    /// 削除(編集モードのみ)。
    func delete() async -> Bool {
        guard case .existing(let contact) = mode else { return false }
        // 見守りモード中に最後の email 連絡先を削除するのはブロック（サーバー M-01 先回り）。
        if contact.contactType == .email, await removingEmailWouldViolate() {
            saveErrorMessage = Self.emailRequiredMessage
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await repo.delete(id: contact.id)
            await contactsSync.syncContacts()
            return true
        } catch {
            Self.logger.error("Delete contact failed: \(error.localizedDescription, privacy: .public)")
            saveErrorMessage = "削除に失敗しました"
            return false
        }
    }

    static let emailRequiredMessage =
        "見守りモード中はメールの緊急連絡先が最低1件必要です。先に別のメール連絡先を追加してください。"

    /// gentle/daily 中に email を1件失う操作が email を0件にするか（true ならブロック）。
    private func removingEmailWouldViolate() async -> Bool {
        let notifying = WatchMode.isNotifyingRawValue(try? await settings.string(forKey: .watchMode))
        guard notifying else { return false }
        let emailCount = (try? await repo.list())?.filter { $0.contactType == .email }.count ?? 0
        return emailCount <= 1
    }

    nonisolated static func isValid(contactType: ContactType, value: String) -> Bool {
        guard !value.isEmpty, value.count <= 254 else { return false }
        switch contactType {
        case .email:
            let pattern = #"^[^@\s]+@[^@\s.]+\.[A-Za-z]{2,}$"#
            return value.range(of: pattern, options: .regularExpression) != nil
        case .line:
            // v1.0 は緩めのバリデーション (空でなければOK・トリム後 1 文字以上)
            return true
        }
    }

    private static func invalidMessage(for type: ContactType) -> String {
        switch type {
        case .email: return "メールアドレスの形式が正しくありません"
        case .line:  return "お名前（表示名）を入力してください"
        }
    }
}
