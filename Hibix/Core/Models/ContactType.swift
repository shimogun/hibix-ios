import Foundation

/// 緊急連絡先の通信種別 (F-07 v0.2)。v0.1 では email のみ実送信、
/// line / phone は登録のみで送信は v0.2 で対応予定。
enum ContactType: String, CaseIterable, Codable, Sendable {
    case email
    case line
    case phone

    var displayName: String {
        switch self {
        case .email: return "メール"
        case .line:  return "LINE"
        case .phone: return "電話"
        }
    }

    var iconName: String {
        switch self {
        case .email: return "envelope.fill"
        case .line:  return "message.fill"
        case .phone: return "phone.fill"
        }
    }

    var fieldLabel: String {
        switch self {
        case .email: return "メールアドレス"
        case .line:  return "LINE ID または URL"
        case .phone: return "電話番号"
        }
    }

    var placeholder: String {
        switch self {
        case .email: return "example@email.com"
        case .line:  return "@friend_id または https://line.me/..."
        case .phone: return "090-1234-5678"
        }
    }

    /// v0.1 で実送信されるかどうか。false の場合は UI 上で v0.2 注記を表示する。
    var isDeliveredInV01: Bool {
        self == .email
    }

    /// DB に保存されている文字列から復元する。未知の値は email にフォールバック。
    static func fromStoredValue(_ raw: String?) -> ContactType {
        guard let raw, let value = ContactType(rawValue: raw) else { return .email }
        return value
    }
}
