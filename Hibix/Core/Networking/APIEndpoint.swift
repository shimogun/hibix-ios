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
    case attestRegister(AttestRegisterBody, challenge: String)
    case storekitVerify(StoreKitVerifyBody)
    case cancelDeletion
    case health
    /// POST /api/contacts/:id/line/issue-code (v1.1 C案・App Attest 必須)。
    case lineIssueCode(serverContactID: String)
    /// GET /api/contacts/:id/line/status (v1.1 C案・App Attest 必須)。
    case lineStatus(serverContactID: String)

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
        case .lineIssueCode(let id): return "/api/contacts/\(id)/line/issue-code"
        case .lineStatus(let id): return "/api/contacts/\(id)/line/status"
        }
    }

    var method: String {
        switch self {
        case .checkin, .attestChallenge, .attestRegister, .storekitVerify, .cancelDeletion, .lineIssueCode:
            return "POST"
        case .settings:
            return "PATCH"
        case .contacts:
            return "PUT"
        case .account:
            return "DELETE"
        case .health, .lineStatus:
            return "GET"
        }
    }

    var requiresAttest: Bool {
        switch self {
        case .checkin, .settings, .contacts, .account, .storekitVerify, .cancelDeletion,
             .lineIssueCode, .lineStatus:
            // LINE 系も backend で authMiddleware + attestMiddleware + deletionGuard 配下。
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

    /// `requiresChallengeOnly` のエンドポイントで `X-Hibix-Attest-Challenge` ヘッダに載せる値。
    var challengeHeaderValue: String? {
        if case .attestRegister(_, let challenge) = self { return challenge }
        return nil
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
        case .attestRegister(let body, _):
            return try encoder.encode(body)
        case .storekitVerify(let body):
            return try encoder.encode(body)
        case .account, .attestChallenge, .cancelDeletion, .health, .lineIssueCode, .lineStatus:
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

/// PUT /api/contacts の1要素 (v1.1 C案: email/LINE 同列・安定ID upsert)。
/// - `id`: サーバー contact UUID。省略(nil)=新規。JSON では nil 時にキーを出さない。
/// - `email`: email 型のみ。line 型は nil(キーを出さない)。
nonisolated struct ContactInputBody: Encodable {
    let id: String?
    let contact_type: String
    let email: String?
    let label: String?

    enum CodingKeys: String, CodingKey {
        case id, contact_type, email, label
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(contact_type, forKey: .contact_type)
        try container.encodeIfPresent(email, forKey: .email)
        // label は null 許容(明示 null を送る)。
        try container.encode(label, forKey: .label)
    }
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
    let contact_type: String
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

// MARK: - LINE 連携(v1.1 C案)
// 注意: expires_at / code_expires_at は UNIX epoch 秒(Int)。
// 他APIの ISO8601 Date と異なるため Int で受けて TimeInterval へ変換する。

nonisolated struct LineIssueCodeResponse: Decodable {
    let code: String
    let expires_at: Int
    let add_friend_url: String?
}

nonisolated struct LineStatusResponse: Decodable {
    let status: String
    let code_expires_at: Int?
}
