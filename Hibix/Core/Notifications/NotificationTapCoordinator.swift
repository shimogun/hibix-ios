import Foundation
import Observation
import UserNotifications

/// 通知タップでアプリが起動した（またはフォアグラウンドへ遷移した）ことを
/// View 層に伝える @Observable コーディネータ。
///
/// PRD §6 F-05: 通知タップでアプリ起動 → ホーム画面（タップ未完了なら気分ピッカーをモーダル表示）。
@MainActor
@Observable
final class NotificationTapCoordinator {
    /// 通知タップごとに ID が更新される。
    /// View 側はこの ID を `.onChange` で監視し、毎回モーダルを開く判断をする。
    private(set) var lastTapId: UUID?

    /// 直近タップ通知の種別（朝/夜のどちらか）を保持しておく。今は UI 分岐に未使用だが将来用。
    private(set) var lastTapKind: NotificationKind?

    func handleNotificationTap(kind: NotificationKind?) {
        lastTapKind = kind
        lastTapId = UUID()
    }
}
