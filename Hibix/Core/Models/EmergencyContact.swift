import Foundation

/// PRD v2.2.0 §6 F-07 の緊急連絡先。端末側ローカル DB には平文保存、
/// サーバー側は AES-256-GCM 暗号化保存(STEP7 で実装)。
struct EmergencyContact: Identifiable, Equatable, Sendable {
    let id: Int64
    var contactType: ContactType
    var email: String
    var label: String?
    var sortOrder: Int
    var createdAt: Date

    /// 一覧で表示するための見出し。label があれば優先、なければ contact value (email カラム流用)。
    var displayTitle: String {
        if let label, !label.isEmpty { return label }
        return email
    }
}
