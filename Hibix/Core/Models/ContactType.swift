import Foundation

/// 緊急連絡先の通信種別 (F-07)。v1.0 では email のみ実送信、
/// line は登録のみで送信は v1.1 (Messaging API・公式アカウント方式) で対応予定。
/// phone (電話) は v1.0 で廃止。過去レコードは fromStoredValue で email にフォールバックする。
enum ContactType: String, CaseIterable, Codable, Sendable {
    case email
    case line

    var displayName: String {
        switch self {
        case .email: return "メール"
        case .line:  return "LINE"
        }
    }

    var iconName: String {
        switch self {
        case .email: return "envelope.fill"
        case .line:  return "message.fill"
        }
    }

    var fieldLabel: String {
        switch self {
        case .email: return "メールアドレス"
        case .line:  return "LINE ID または URL"
        }
    }

    var placeholder: String {
        switch self {
        case .email: return "example@email.com"
        case .line:  return "@friend_id または https://line.me/..."
        }
    }

    /// DB に保存されている文字列から復元する。未知の値 (廃止した phone を含む) は email にフォールバック。
    static func fromStoredValue(_ raw: String?) -> ContactType {
        guard let raw, let value = ContactType(rawValue: raw) else { return .email }
        return value
    }
}
