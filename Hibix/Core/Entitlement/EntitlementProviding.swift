import Foundation

/// `EntitlementManager` の最小読み取り口。テスト時に Fake で差し替え可能にする。
protocol EntitlementProviding: Sendable {
    var isPro: Bool { get async }
}
