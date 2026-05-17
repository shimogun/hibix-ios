import Foundation

enum NotificationIdentifier {
    static let dailyMorning = "hibix.daily.morning"
    static let dailyEvening = "hibix.daily.evening"
    static let reminder48h = "hibix.reminder.48h"
    static let reminder24h = "hibix.reminder.24h"
}

enum NotificationUserInfoKey {
    static let kind = "hibix.kind"
}

enum NotificationKind: String {
    case dailyMorning
    case dailyEvening
    case reminder48h
    case reminder24h
}

enum NotificationContent {
    static let dailyMorningTitle = "Hibix"
    static let dailyMorningBody = "今日のひとピクセル、つけにいきましょう"
    static let dailyEveningTitle = "Hibix"
    static let dailyEveningBody = "今日のヒビ、ぽちっと記録"
}
