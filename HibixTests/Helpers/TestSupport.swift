import Foundation
@testable import Hibix

/// 同期/LINE サービス系テスト共通のスタブ生成ヘルパ。
/// App Attest は `FakeAppAttestService`(isSupported=true)＋登録済み Keychain で「登録済み」状態を作る。
enum TestSupport {
    @MainActor
    static func makeRegisteredAttestClient() throws -> AppAttestClient {
        let store = AppAttestKeyStore(service: UUID().uuidString)
        try store.saveKeyId("test-key-id")
        try store.setRegistered(true)
        return AppAttestClient(
            service: FakeAppAttestService(),
            store: store,
            fetchChallenge: { @Sendable in
                AttestChallengeResponse(challenge: "Y2hhbGxlbmdl", expires_at: Date().addingTimeInterval(300))
            },
            register: { @Sendable _, _ in }
        )
    }

    @MainActor
    static func makeStubAPIClient(
        handler: @escaping @Sendable (URLRequest) -> (HTTPURLResponse, Data)
    ) -> APIClient {
        // 並列実行される複数 Suite が StubURLProtocol を共有するため、UUID ごとに handler を分離。
        let uuid = "test-\(UUID().uuidString)"
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.setHandler(forUUID: uuid, handler)
        let session = URLSession(configuration: config)
        guard let url = URL(string: "http://test.invalid") else { fatalError("invalid test URL") }
        return APIClient(baseURL: url, anonymousUUID: uuid, session: session)
    }

    /// 200 OK レスポンスの簡易生成。
    static func ok(_ request: URLRequest, _ json: String) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
    }
}
