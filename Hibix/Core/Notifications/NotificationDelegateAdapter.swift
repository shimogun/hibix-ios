import Foundation
import UserNotifications

/// `UNUserNotificationCenter` の delegate を `NotificationTapCoordinator` に橋渡しする NSObject アダプタ。
///
/// `UNUserNotificationCenterDelegate` は `NSObjectProtocol` を要求するため、
/// `@Observable` クラスとは分離してアダプタを用意する。
final class NotificationDelegateAdapter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let coordinator: NotificationTapCoordinator

    init(coordinator: NotificationTapCoordinator) {
        self.coordinator = coordinator
        super.init()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // フォアグラウンド表示時もバナーで表示。
        [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let rawKind = response.notification.request.content.userInfo[NotificationUserInfoKey.kind] as? String
        let kind = rawKind.flatMap { NotificationKind(rawValue: $0) }
        await MainActor.run {
            coordinator.handleNotificationTap(kind: kind)
        }
    }
}
