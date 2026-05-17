import Foundation

/// 有料機能の単一 enum (PRD §6 F-13)。新機能追加時はここに 1 ケース足すだけ。
enum Feature: Sendable {
    case modeSwitch        // F-06 3モード切替
    case emergencyContact  // F-07 緊急連絡先メール通知
    case appLock           // F-08 Face ID / パスコードロック
    case reminders         // F-09 2段階リマインダー
    case fullPixelHistory  // F-04 全期間ピクセルカレンダー
}

/// `EntitlementManager.isPro` を読んで Feature の有効可否を判定する薄いゲート。
///
/// PRD v2.2.0 §6 F-13:
/// - サーバー側での再チェック不要
/// - 機能追加時は `Feature` enum を増やすだけ
struct FeatureGate {
    let provider: any EntitlementProviding

    init(provider: any EntitlementProviding) {
        self.provider = provider
    }

    /// `Feature` が現在の Entitlement 下で許可されるか。
    /// v0.1 では全ての有料機能は単純に isPro 連動。
    func isAllowed(_ feature: Feature) async -> Bool {
        switch feature {
        case .modeSwitch, .emergencyContact, .appLock, .reminders, .fullPixelHistory:
            return await provider.isPro
        }
    }
}
