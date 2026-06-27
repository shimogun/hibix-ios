import Foundation

/// LINE 連携状態（backend `line_link_status` のローカルキャッシュ）。
/// PRD v1.1 §8.12（C案: email/LINE 同列）。
enum LineLinkStatus: String, CaseIterable, Codable, Sendable {
    case unlinked
    case pending
    case linked

    var badgeText: String {
        switch self {
        case .unlinked: return "未連携"
        case .pending:  return "連携待ち"
        case .linked:   return "連携済み"
        }
    }

    /// DB 保存値からの復元。未知 / nil は unlinked にフォールバック。
    static func fromStoredValue(_ raw: String?) -> LineLinkStatus {
        guard let raw, let value = LineLinkStatus(rawValue: raw) else { return .unlinked }
        return value
    }
}
