import Foundation
import UserNotifications
import os.log

protocol UserNotificationCenter: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func notificationSettings() async -> UNNotificationSettings
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func pendingNotificationRequests() async -> [UNNotificationRequest]
}

extension UNUserNotificationCenter: UserNotificationCenter {}

/// 朝/夜のチェックイン通知（F-05）スケジューラ。
///
/// 2段階リマインダー（F-09）は STEP5 で別途追加する。
final class NotificationScheduler {
    private let center: any UserNotificationCenter
    private let settings: SettingsRepository

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Notifications")

    init(center: any UserNotificationCenter = UNUserNotificationCenter.current(),
         settings: SettingsRepository) {
        self.center = center
        self.settings = settings
    }

    /// オンボーディング Page3 で 1 度だけ呼び出す。拒否されても false を返すのみ。
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            Self.logger.error("requestAuthorization failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// 設定テーブルの morning_notify / evening_notify を読み、朝/夜通知を再スケジュールする。
    /// 値が "off" または不正な場合は該当通知をキャンセル。
    func rescheduleDailyNotifications() async {
        await schedule(kind: .dailyMorning,
                       key: .morningNotify,
                       identifier: NotificationIdentifier.dailyMorning,
                       title: NotificationContent.dailyMorningTitle,
                       body: NotificationContent.dailyMorningBody)
        await schedule(kind: .dailyEvening,
                       key: .eveningNotify,
                       identifier: NotificationIdentifier.dailyEvening,
                       title: NotificationContent.dailyEveningTitle,
                       body: NotificationContent.dailyEveningBody)
    }

    func cancelDailyNotifications() {
        center.removePendingNotificationRequests(withIdentifiers: [
            NotificationIdentifier.dailyMorning,
            NotificationIdentifier.dailyEvening
        ])
    }

    private func schedule(kind: NotificationKind,
                          key: SettingsKey,
                          identifier: String,
                          title: String,
                          body: String) async {
        let raw: String?
        do {
            raw = try await settings.string(forKey: key)
        } catch {
            Self.logger.error("settings read failed for \(key.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }

        guard let notify = NotifyTime.parse(raw), case .time(let hour, let minute) = notify else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }

        // 通知許可が無い場合はスケジュールしてもユーザーには見えないが、許可後に有効化される。
        // ここでは許可状態を見ずに常に予約する（PRD §6 F-05 受け入れ基準: 未許可でも設定操作は可）。

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [NotificationUserInfoKey.kind: kind.rawValue]

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        do {
            try await center.add(request)
        } catch {
            Self.logger.error("schedule failed for \(identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
