import Foundation
import CryptoKit
import os.log

/// App Attest assertion 4 ヘッダのうち、challenge / keyId / assertion をまとめた構造体。
/// `X-Hibix-UUID` は呼び出し側(APIClient)で別途付与する。
struct AppAttestHeaders: Sendable {
    let keyId: String
    let assertion: String
    let challenge: String
}

/// `DCAppAttestService` と Backend(`/api/attest/{challenge,register}`)を協調させ、
/// 全 mutating リクエストに必要な App Attest assertion ヘッダを生成するオーケストレータ。
///
/// PRD v2.2.0 §8.7 / §8.8 / §10.7 に準拠。
///
/// - 初回起動時に `ensureRegistered()` を 1 度だけ呼ぶ
/// - mutating リクエスト毎に `makeAssertionHeaders(for:)` を呼ぶ
/// - 端末非対応(`isSupported == false`)または登録失敗時は読み取り専用モードへフォールバック
@MainActor
@Observable
final class AppAttestClient {
    @ObservationIgnored private let service: any AppAttestServiceWrapping
    @ObservationIgnored private let store: AppAttestKeyStore
    @ObservationIgnored private let fetchChallenge: @Sendable () async throws -> AttestChallengeResponse
    @ObservationIgnored private let register: @Sendable (AttestRegisterBody) async throws -> Void

    private(set) var lastError: String?
    private var registrationTask: Task<Bool, Never>?

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Attest")

    init(service: any AppAttestServiceWrapping,
         store: AppAttestKeyStore,
         fetchChallenge: @escaping @Sendable () async throws -> AttestChallengeResponse,
         register: @escaping @Sendable (AttestRegisterBody) async throws -> Void) {
        self.service = service
        self.store = store
        self.fetchChallenge = fetchChallenge
        self.register = register
    }

    var isSupported: Bool {
        service.isSupported
    }

    var isRegistered: Bool {
        store.isRegistered
    }

    /// 端末が App Attest 非対応 or 登録失敗で読み取り専用モード相当か。
    var isReadOnlyMode: Bool {
        !isSupported || !isRegistered
    }

    /// 冪等な初回登録。すでに登録済みなら即座に true。
    /// 端末非対応・登録失敗時は false。
    @discardableResult
    func ensureRegistered() async -> Bool {
        if !isSupported {
            Self.logger.notice("DCAppAttestService is not supported on this device")
            return false
        }
        if isRegistered { return true }
        if let task = registrationTask { return await task.value }

        let task = Task { @MainActor [weak self] in
            guard let self else { return false }
            return await self.performRegistration()
        }
        registrationTask = task
        let result = await task.value
        registrationTask = nil
        return result
    }

    /// mutating リクエスト用の assertion ヘッダを生成する。
    /// 端末非対応 or 未登録 or サーバー疎通失敗時は throws。
    func makeAssertionHeaders(for body: Data?) async throws -> AppAttestHeaders {
        guard isSupported else {
            throw APIError.attestUnavailable("device not supported")
        }
        guard let keyId = store.loadKeyId(), store.isRegistered else {
            throw APIError.attestUnavailable("not registered")
        }

        let challenge = try await fetchChallenge()
        guard let challengeBytes = Data(base64Encoded: challenge.challenge) else {
            throw APIError.attestUnavailable("invalid challenge encoding")
        }

        var combined = challengeBytes
        if let body { combined.append(body) }
        let clientDataHash = Data(SHA256.hash(data: combined))

        let assertion: Data
        do {
            assertion = try await service.generateAssertion(keyId, clientDataHash: clientDataHash)
        } catch {
            Self.logger.error("generateAssertion failed: \(error.localizedDescription, privacy: .public)")
            throw APIError.attestUnavailable("assertion generation failed")
        }

        return AppAttestHeaders(
            keyId: keyId,
            assertion: assertion.base64EncodedString(),
            challenge: challenge.challenge
        )
    }

    /// 登録状態をリセット(データ削除 F-11 の一部として呼ばれる想定)。
    func reset() throws {
        try store.reset()
    }

    // MARK: - Private

    private func performRegistration() async -> Bool {
        do {
            let keyId = try await service.generateKey()
            try store.saveKeyId(keyId)

            let challenge = try await fetchChallenge()
            guard let challengeBytes = Data(base64Encoded: challenge.challenge) else {
                lastError = "invalid challenge encoding"
                return false
            }
            let clientDataHash = Data(SHA256.hash(data: challengeBytes))

            let attestation = try await service.attestKey(keyId, clientDataHash: clientDataHash)

            let body = AttestRegisterBody(
                key_id: keyId,
                attestation: attestation.base64EncodedString(),
                client_data_hash: clientDataHash.base64EncodedString()
            )
            try await register(body)

            try store.setRegistered(true)
            lastError = nil
            Self.logger.info("App Attest registration succeeded")
            return true
        } catch {
            lastError = error.localizedDescription
            Self.logger.error("App Attest registration failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
