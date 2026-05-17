import Foundation

/// Hibix Backend のエンドポイント定義（PRD v2.2.0 §8）。
///
/// `requiresAttest = true` のものは App Attest assertion 4 ヘッダ必須。
/// `false` は `X-Hibix-UUID` のみ(または認証不要)。
enum APIEndpoint {
    case checkin(checkinAt: Date)
    case settings(SettingsPatchBody)
    case contacts(ContactsPutBody)
    case account
    case attestChallenge
    case attestRegister(AttestRegisterBody)
    case storekitVerify(StoreKitVerifyBody)
    case cancelDeletion
    case health

    var path: String {
        switch self {
        case .checkin: return "/api/checkin"
        case .settings: return "/api/settings"
        case .contacts: return "/api/contacts"
        case .account: return "/api/account"
        case .attestChallenge: return "/api/attest/challenge"
        case .attestRegister: return "/api/attest/register"
        case .storekitVerify: return "/api/storekit/verify"
        case .cancelDeletion: return "/api/account/cancel-deletion"
        case .health: return "/api/health"
        }
    }

    var method: String {
        switch self {
        case .checkin, .attestChallenge, .attestRegister, .storekitVerify, .cancelDeletion:
            return "POST"
        case .settings:
            return "PATCH"
        case .contacts:
            return "PUT"
        case .account:
            return "DELETE"
        case .health:
            return "GET"
        }
    }

    var requiresAttest: Bool {
        switch self {
        case .checkin, .settings, .contacts, .account, .storekitVerify, .cancelDeletion:
            return true
        case .attestChallenge, .attestRegister, .health:
            return false
        }
    }

    /// `register` は `X-Hibix-UUID` + `X-Hibix-Attest-Challenge` のみ必要(§8.1 例外)。
    var requiresChallengeOnly: Bool {
        if case .attestRegister = self { return true }
        return false
    }

    func makeBody() throws -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        switch self {
        case .checkin(let checkinAt):
            return try encoder.encode(CheckinBody(checkin_at: checkinAt))
        case .settings(let body):
            return try encoder.encode(body)
        case .contacts(let body):
            return try encoder.encode(body)
        case .attestRegister(let body):
            return try encoder.encode(body)
        case .storekitVerify(let body):
            return try encoder.encode(body)
        case .account, .attestChallenge, .cancelDeletion, .health:
            return nil
        }
    }
}

// MARK: - Request bodies

nonisolated struct CheckinBody: Encodable {
    let checkin_at: Date
}

nonisolated struct SettingsPatchBody: Encodable {
    let watch_days: Int?
    let watch_mode: String?
}

nonisolated struct ContactInputBody: Encodable {
    let email: String
    let label: String?
}

nonisolated struct ContactsPutBody: Encodable {
    let contacts: [ContactInputBody]
}

nonisolated struct AttestRegisterBody: Encodable, Sendable {
    let key_id: String
    let attestation: String
    let client_data_hash: String
}

nonisolated struct StoreKitVerifyBody: Encodable {
    let jws: String
}

// MARK: - Response bodies

nonisolated struct CheckinResponse: Decodable {
    let last_checkin_at: Date
}

nonisolated struct SettingsResponse: Decodable {
    let watch_days: Int
    let watch_mode: String
    let is_pro: Bool
}

nonisolated struct ContactsResponse: Decodable {
    let contacts: [ContactOutput]
}

nonisolated struct ContactOutput: Decodable {
    let id: String
    let label: String?
}

nonisolated struct AccountDeleteResponse: Decodable {
    let deletion_request_id: String
    let scheduled_deletion_by: Date
}

nonisolated struct AttestChallengeResponse: Decodable, Sendable {
    let challenge: String
    let expires_at: Date
}

nonisolated struct AttestRegisterResponse: Decodable, Sendable {
    let ok: Bool
}

nonisolated struct StoreKitVerifyResponse: Decodable {
    let is_pro: Bool
    let product_id: String
    let original_transaction_id: String
    let verified_at: Date
}

nonisolated struct CancelDeletionResponse: Decodable {
    let cancelled_deletion_request_id: String
}

nonisolated struct HealthResponse: Decodable {
    let status: String
}
