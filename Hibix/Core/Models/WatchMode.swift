import Foundation

/// PRD v2.2.0 §6 F-06 の 3 モード。サーバー側 `users.watch_mode` カラムと同じ raw value。
enum WatchMode: String, CaseIterable, Sendable, Identifiable {
    case solo
    case gentle
    case daily

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .solo:   return "おひとりさま"
        case .gentle: return "ゆるつながり"
        case .daily:  return "まいにち共有"
        }
    }

    /// 各モードの動作説明(設定画面下部に表示)。
    var description: String {
        switch self {
        case .solo:
            return "緊急連絡先メール通知は送信されません。自分用の記録として使えます。"
        case .gentle:
            return "しきい値日数の間チェックインがなかったとき、登録済みの緊急連絡先にお知らせメールを送信します。"
        case .daily:
            return "しきい値日数の間チェックインがなかったとき、登録済みの緊急連絡先にお知らせメールを送信します。"
        }
    }

    /// 有料のみ選択可能なモードか(F-06)。
    var requiresPro: Bool {
        self != .solo
    }
}
