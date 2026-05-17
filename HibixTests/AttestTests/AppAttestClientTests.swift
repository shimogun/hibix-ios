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
            register: { @Sendable _ in
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

    func generateKey() async throws -> String {
        generateKeyResult
    }

    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        lock.lock(); _lastAttestClientDataHash = clientDataHash; lock.unlock()
        return attestKeyResult
    }

    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data {
        lock.lock(); _lastAssertionClientDataHash = clientDataHash; lock.unlock()
        return assertionResult
    }
}
