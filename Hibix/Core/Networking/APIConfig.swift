import Foundation

/// Hibix Backend API のベース URL と固定値。
///
/// `HIBIX_API_BASE_URL` キーが Info.plist に存在すればそれを使用。無ければ
/// ローカル開発の `wrangler dev` デフォルトにフォールバック。
///
/// 本番デプロイ時はオーナーが Xcode の Build Settings で
/// `INFOPLIST_KEY_HIBIX_API_BASE_URL = https://api.hibix.app` を追加する。
enum APIConfig {
    nonisolated static let baseURL: URL = {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "HIBIX_API_BASE_URL") as? String,
           let url = URL(string: raw) {
            return url
        }
        guard let fallback = URL(string: "http://127.0.0.1:8787") else {
            fatalError("Hibix API: invalid fallback URL literal")
        }
        return fallback
    }()

    /// App Attest の `rpId = <APPLE_TEAM_ID>.<bundleId>` 用の Bundle ID 部分。
    nonisolated static let bundleIdentifier = "com.shimogun.hibix"

    /// クライアント側ネットワークタイムアウト(秒)。
    nonisolated static let requestTimeout: TimeInterval = 15
}

enum APIHeader {
    static let uuid = "X-Hibix-UUID"
    static let attestKeyId = "X-Hibix-Attest-Key-Id"
    static let attestAssertion = "X-Hibix-Attest-Assertion"
    static let attestChallenge = "X-Hibix-Attest-Challenge"
    static let contentType = "Content-Type"
}
