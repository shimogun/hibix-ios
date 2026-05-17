import Foundation
import DeviceCheck

/// `DCAppAttestService` の薄いラッパー。テストで差し替え可能にする。
protocol AppAttestServiceWrapping: Sendable {
    var isSupported: Bool { get }
    func generateKey() async throws -> String
    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data
    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data
}

final class DefaultAppAttestService: AppAttestServiceWrapping, @unchecked Sendable {
    private let service: DCAppAttestService

    init(service: DCAppAttestService = .shared) {
        self.service = service
    }

    var isSupported: Bool {
        service.isSupported
    }

    func generateKey() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            service.generateKey { keyId, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let keyId {
                    continuation.resume(returning: keyId)
                } else {
                    continuation.resume(throwing: AppAttestServiceError.emptyResult)
                }
            }
        }
    }

    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            service.attestKey(keyId, clientDataHash: clientDataHash) { attestation, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let attestation {
                    continuation.resume(returning: attestation)
                } else {
                    continuation.resume(throwing: AppAttestServiceError.emptyResult)
                }
            }
        }
    }

    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            service.generateAssertion(keyId, clientDataHash: clientDataHash) { assertion, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let assertion {
                    continuation.resume(returning: assertion)
                } else {
                    continuation.resume(throwing: AppAttestServiceError.emptyResult)
                }
            }
        }
    }
}

enum AppAttestServiceError: Error, LocalizedError {
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .emptyResult:
            return "DCAppAttestService が値もエラーも返しませんでした"
        }
    }
}
