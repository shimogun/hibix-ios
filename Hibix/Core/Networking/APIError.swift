import Foundation

/// PRD v2.2.0 §8.1 のエラーコード一覧。サーバーが返す `error.code` を網羅。
enum APIErrorCode: String, Decodable, Sendable {
    case invalidUUID = "INVALID_UUID"
    case validationError = "VALIDATION_ERROR"
    case tooManyContacts = "TOO_MANY_CONTACTS"
    /// v1.1 C案: 通知モード(gentle/daily)で email 型連絡先が0件のとき(M-01)。
    case emailContactRequired = "EMAIL_CONTACT_REQUIRED"
    case rateLimitExceeded = "RATE_LIMIT_EXCEEDED"
    case deletionPending = "DELETION_PENDING"
    case attestationRequired = "ATTESTATION_REQUIRED"
    case attestationFailed = "ATTESTATION_FAILED"
    case attestationInvalid = "ATTESTATION_INVALID"
    case alreadyRegistered = "ALREADY_REGISTERED"
    case jwsInvalid = "JWS_INVALID"
    case bundleIdMismatch = "BUNDLE_ID_MISMATCH"
    case productIdMismatch = "PRODUCT_ID_MISMATCH"
    case revoked = "REVOKED"
    case noPendingDeletion = "NO_PENDING_DELETION"
    case internalError = "INTERNAL_ERROR"
}

/// サーバー側エラーレスポンスのデコード型。`DELETION_PENDING` 時のみ
/// `scheduled_deletion_by` が追加で含まれる。
struct APIErrorResponse: Decodable, Sendable {
    let error: APIErrorBody

    struct APIErrorBody: Decodable, Sendable {
        let code: APIErrorCode
        let message: String
        let scheduled_deletion_by: Date?
    }
}

/// APIClient が投げる統一エラー。
enum APIError: Error, LocalizedError {
    /// サーバーがエラーレスポンス(2xx 以外 + JSON)を返した場合。
    case server(status: Int, code: APIErrorCode, message: String, scheduledDeletionBy: Date?)
    /// HTTP 2xx 以外で JSON パースもできなかった場合。
    case unexpectedStatus(status: Int, rawBody: String?)
    /// ネットワーク/タイムアウト/接続失敗。
    case transport(URLError)
    /// 設定不備など。
    case configuration(String)
    /// レスポンスが期待した型にデコードできなかった。
    case decoding(any Error)
    /// App Attest 側の準備に失敗した(クライアント側)。
    case attestUnavailable(String)
    /// その他のクライアント側エラー。
    case client(any Error)

    var errorDescription: String? {
        switch self {
        case .server(_, _, let message, _):
            return message
        case .unexpectedStatus(let status, _):
            return "サーバーエラー(HTTP \(status))"
        case .transport:
            return "ネットワークに接続できませんでした"
        case .configuration(let detail):
            return "設定エラー: \(detail)"
        case .decoding:
            return "サーバー応答の解析に失敗しました"
        case .attestUnavailable(let reason):
            return "サーバーと通信できません(\(reason))"
        case .client(let error):
            return error.localizedDescription
        }
    }

    var errorCode: APIErrorCode? {
        if case .server(_, let code, _, _) = self { return code }
        return nil
    }

    var isDeletionPending: Bool {
        errorCode == .deletionPending
    }

    var isAttestationFailure: Bool {
        guard let code = errorCode else { return false }
        return code == .attestationRequired || code == .attestationFailed
    }

    var isRateLimited: Bool {
        errorCode == .rateLimitExceeded
    }
}
