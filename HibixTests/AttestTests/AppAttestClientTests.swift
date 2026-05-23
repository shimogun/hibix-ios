import Testing
import Foundation
import CryptoKit
@testable import Hibix

/// `AppAttestClient` の orchestration ロジック単体テスト。
/// DCAppAttestService は実機/シミュレータでも統合困難なため `FakeAppAttestService` で差し替える。
@Suite("AppAttestClient")
@MainActor
struct AppAttestClientTests {

    private func makeClient(
        service: FakeAppAttestService,
        challenge: String = "Y2hhbGxlbmdl",
        registerThrows: Bool = false,
        challengeCallCount: ChallengeCounter = ChallengeCounter()
    ) -> (AppAttestClient, AppAttestKeyStore, ChallengeCounter) {
        let store = AppAttestKeyStore(service: UUID().uuidString)
        let counter = challengeCallCount
        let challengeValue = challenge
        let willRegisterThrow = registerThrows
        let client = AppAttestClient(
            service: service,
            store: store,
            fetchChallenge: { @Sendable in
                await counter.increment()
                return AttestChallengeResponse(challenge: challengeValue, expires_at: Date().addingTimeInterval(300))
            },
            register: { @Sendable _, _ in
                if willRegisterThrow {
                    throw APIError.server(status: 400, code: .attestationInvalid, message: "bad", scheduledDeletionBy: nil)
                }
            }
        )
        return (client, store, counter)
    }

    @Test
    func ensureRegistered_whenSupported_succeeds_andPersists() async throws {
        let service = FakeAppAttestService()
        let (client, store, _) = makeClient(service: service)
        let result = await client.ensureRegistered()
        #expect(result)
        #expect(store.isRegistered)
        #expect(store.loadKeyId() != nil)
        try store.reset()
    }

    @Test
    func ensureRegistered_isIdempotent() async throws {
        let service = FakeAppAttestService()
        let (client, store, counter) = makeClient(service: service)
        _ = await client.ensureRegistered()
        let countAfterFirst = await counter.value
        _ = await client.ensureRegistered()
        let countAfterSecond = await counter.value
        #expect(countAfterFirst == countAfterSecond)
        try store.reset()
    }

    @Test
    func ensureRegistered_whenNotSupported_returnsFalse() async {
        let service = FakeAppAttestService(supported: false)
        let (client, store, _) = makeClient(service: service)
        let result = await client.ensureRegistered()
        #expect(!result)
        #expect(!store.isRegistered)
    }

    @Test
    func ensureRegistered_whenRegisterFails_returnsFalse() async throws {
        let service = FakeAppAttestService()
        let (client, store, _) = makeClient(service: service, registerThrows: true)
        let result = await client.ensureRegistered()
        #expect(!result)
        #expect(!store.isRegistered)
        try store.reset()
    }

    @Test
    func makeAssertionHeaders_returnsHeadersWhenRegistered() async throws {
        let service = FakeAppAttestService()
        let (client, store, _) = makeClient(service: service)
        _ = await client.ensureRegistered()
        let headers = try await client.makeAssertionHeaders(for: Data("body".utf8))
        #expect(headers.keyId == store.loadKeyId())
        #expect(headers.challenge == "Y2hhbGxlbmdl")
        #expect(!headers.assertion.isEmpty)
        try store.reset()
    }

    @Test
    func makeAssertionHeaders_clientDataHash_isSha256OfChallengeAndBody() async throws {
        let service = FakeAppAttestService()
        let (client, store, _) = makeClient(service: service)
        _ = await client.ensureRegistered()

        let body = Data("body-bytes".utf8)
        _ = try await client.makeAssertionHeaders(for: body)

        // FakeAppAttestService が記録した clientDataHash を検証
        let challengeBytes = Data(base64Encoded: "Y2hhbGxlbmdl")!
        var combined = challengeBytes
        combined.append(body)
        let expected = Data(SHA256.hash(data: combined))

        #expect(service.lastAssertionClientDataHash == expected)
        try store.reset()
    }

    @Test
    func makeAssertionHeaders_throwsWhenNotRegistered() async {
        let service = FakeAppAttestService()
        let (client, _, _) = makeClient(service: service)
        do {
            _ = try await client.makeAssertionHeaders(for: nil)
            Issue.record("Expected attestUnavailable error")
        } catch let APIError.attestUnavailable(reason) {
            #expect(reason.contains("not registered"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func makeAssertionHeaders_throwsWhenNotSupported() async {
        let service = FakeAppAttestService(supported: false)
        let (client, _, _) = makeClient(service: service)
        do {
            _ = try await client.makeAssertionHeaders(for: nil)
            Issue.record("Expected attestUnavailable error")
        } catch let APIError.attestUnavailable(reason) {
            #expect(reason.contains("not supported"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func makeAssertionHeaders_recoversWhenAssertionFails() async throws {
        let service = FakeAppAttestService()
        let (client, store, _) = makeClient(service: service)
        _ = await client.ensureRegistered()
        let initialGenerateKeyCount = service.generateKeyCallCount

        // Apple 側で旧鍵が無効化された状況を模擬: 最初の assertion を 1 回だけ失敗させる
        service.failNextAssertions(1)
        // 再登録後の新しい key_id (Apple が新規発行する想定)
        service.generateKeyResult = "recovered-key-id"

        let headers = try await client.makeAssertionHeaders(for: Data("body".utf8))

        #expect(headers.keyId == "recovered-key-id")
        #expect(store.loadKeyId() == "recovered-key-id")
        #expect(store.isRegistered)
        // 復旧で generateKey が 1 回追加で呼ばれている
        #expect(service.generateKeyCallCount == initialGenerateKeyCount + 1)
        // 1 回失敗 + 1 回成功 = 2
        #expect(service.assertionCallCount == 2)
        try store.reset()
    }

    @Test
    func makeAssertionHeaders_throwsWhenRecoveryAssertionAlsoFails() async throws {
        let service = FakeAppAttestService()
        let (client, store, _) = makeClient(service: service)
        _ = await client.ensureRegistered()

        // 復旧後も失敗するパターン: 2 回連続失敗
        service.failNextAssertions(2)

        do {
            _ = try await client.makeAssertionHeaders(for: nil)
            Issue.record("Expected attestUnavailable error after failed recovery")
        } catch let APIError.attestUnavailable(reason) {
            #expect(reason == "assertion generation failed")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        try store.reset()
    }

    @Test
    func makeAssertionHeaders_throwsWhenRecoveryRegistrationFails() async throws {
        let service = FakeAppAttestService()
        let (client, store, _) = makeClient(service: service, registerThrows: false)
        _ = await client.ensureRegistered()

        // assertion を失敗させ、復旧時の register も失敗させる
        service.failNextAssertions(1)
        // register を失敗させるため、新しい client を作り直す（registerThrows=true）
        let failingRegisterClient = AppAttestClient(
            service: service,
            store: store,
            fetchChallenge: { @Sendable in
                AttestChallengeResponse(challenge: "Y2hhbGxlbmdl", expires_at: Date().addingTimeInterval(300))
            },
            register: { @Sendable _, _ in
                throw APIError.server(status: 400, code: .attestationInvalid, message: "bad", scheduledDeletionBy: nil)
            }
        )

        do {
            _ = try await failingRegisterClient.makeAssertionHeaders(for: nil)
            Issue.record("Expected attestUnavailable error after recovery registration failed")
        } catch let APIError.attestUnavailable(reason) {
            #expect(reason == "recovery registration failed")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        try store.reset()
    }
}

@Suite("AppAttestKeyStore")
@MainActor
struct AppAttestKeyStoreTests {

    @Test
    func saveAndLoadKeyId_roundTrip() throws {
        let store = AppAttestKeyStore(service: UUID().uuidString)
        try store.saveKeyId("hello-key")
        #expect(store.loadKeyId() == "hello-key")
        try store.reset()
    }

    @Test
    func registeredFlag_persistence() throws {
        let store = AppAttestKeyStore(service: UUID().uuidString)
        #expect(!store.isRegistered)
        try store.setRegistered(true)
        #expect(store.isRegistered)
        try store.setRegistered(false)
        #expect(!store.isRegistered)
        try store.reset()
    }

    @Test
    func reset_clearsBoth() throws {
        let store = AppAttestKeyStore(service: UUID().uuidString)
        try store.saveKeyId("k")
        try store.setRegistered(true)
        try store.reset()
        #expect(store.loadKeyId() == nil)
        #expect(!store.isRegistered)
    }
}

// MARK: - Fakes

actor ChallengeCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

final class FakeAppAttestService: AppAttestServiceWrapping, @unchecked Sendable {
    let isSupportedFlag: Bool
    var generateKeyResult: String = "fake-key-id"
    var attestKeyResult: Data = Data("fake-attestation".utf8)
    var assertionResult: Data = Data("fake-assertion".utf8)

    private let lock = NSLock()
    private var _lastAssertionClientDataHash: Data?
    private var _lastAttestClientDataHash: Data?
    private var _assertionFailuresRemaining: Int = 0
    private var _generateKeyCallCount: Int = 0
    private var _assertionCallCount: Int = 0

    init(supported: Bool = true) {
        self.isSupportedFlag = supported
    }

    var isSupported: Bool { isSupportedFlag }

    var lastAssertionClientDataHash: Data? {
        lock.lock(); defer { lock.unlock() }
        return _lastAssertionClientDataHash
    }

    var lastAttestClientDataHash: Data? {
        lock.lock(); defer { lock.unlock() }
        return _lastAttestClientDataHash
    }

    var generateKeyCallCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _generateKeyCallCount
    }

    var assertionCallCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _assertionCallCount
    }

    /// 次の N 回の `generateAssertion` を `FakeAttestError.invalidKey` で失敗させる。
    /// それを超えると `assertionResult` を返す。
    func failNextAssertions(_ count: Int) {
        lock.lock(); _assertionFailuresRemaining = count; lock.unlock()
    }

    func generateKey() async throws -> String {
        lock.lock(); _generateKeyCallCount += 1; lock.unlock()
        return generateKeyResult
    }

    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        lock.lock(); _lastAttestClientDataHash = clientDataHash; lock.unlock()
        return attestKeyResult
    }

    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data {
        lock.lock()
        _assertionCallCount += 1
        _lastAssertionClientDataHash = clientDataHash
        let shouldFail = _assertionFailuresRemaining > 0
        if shouldFail { _assertionFailuresRemaining -= 1 }
        lock.unlock()
        if shouldFail { throw FakeAttestError.invalidKey }
        return assertionResult
    }
}

enum FakeAttestError: Error { case invalidKey }
