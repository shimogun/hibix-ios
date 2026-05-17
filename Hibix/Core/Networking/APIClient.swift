import Foundation
import os.log

/// Hibix Backend (`hibix-backend`) と通信する HTTP クライアント。
///
/// - mutating エンドポイントには App Attest assertion 4 ヘッダを自動付与する
/// - エラーレスポンス JSON を `APIError` にパースする
/// - PRD v2.2.0 §8 / §10.7 準拠
@MainActor
final class APIClient {
    @ObservationIgnored private let session: URLSession
    @ObservationIgnored private let baseURL: URL
    @ObservationIgnored private let anonymousUUID: String
    @ObservationIgnored private var attestClient: AppAttestClient?

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "API")

    init(baseURL: URL = APIConfig.baseURL,
         anonymousUUID: String,
         session: URLSession? = nil) {
        self.baseURL = baseURL
        self.anonymousUUID = anonymousUUID
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = APIConfig.requestTimeout
            config.timeoutIntervalForResource = APIConfig.requestTimeout
            self.session = URLSession(configuration: config)
        }
    }

    /// AppAttestClient と相互参照させるための遅延セット。`AppDependencies` で構築時に呼ぶ。
    func attach(attestClient: AppAttestClient) {
        self.attestClient = attestClient
    }

    /// エンドポイントを叩いて Decodable レスポンスを返す。
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let data = try await sendData(endpoint: endpoint)
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            Self.logger.error("Decoding failed for \(endpoint.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw APIError.decoding(error)
        }
    }

    /// レスポンス body を捨てる用途。
    func requestIgnoringResponse(_ endpoint: APIEndpoint) async throws {
        _ = try await sendData(endpoint: endpoint)
    }

    // MARK: - Private

    private func sendData(endpoint: APIEndpoint) async throws -> Data {
        let body: Data?
        do {
            body = try endpoint.makeBody()
        } catch {
            throw APIError.client(error)
        }

        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint.path))
        request.httpMethod = endpoint.method
        request.httpBody = body
        request.setValue(anonymousUUID, forHTTPHeaderField: APIHeader.uuid)
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: APIHeader.contentType)
        }

        try await attachAttestHeadersIfNeeded(to: &request, endpoint: endpoint, body: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw APIError.transport(urlError)
        } catch {
            throw APIError.client(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unexpectedStatus(status: -1, rawBody: nil)
        }

        if (200..<300).contains(http.statusCode) {
            return data
        }

        if let decoded = Self.decodeErrorBody(data) {
            throw APIError.server(
                status: http.statusCode,
                code: decoded.error.code,
                message: decoded.error.message,
                scheduledDeletionBy: decoded.error.scheduled_deletion_by
            )
        }

        let rawBody = String(data: data, encoding: .utf8)
        throw APIError.unexpectedStatus(status: http.statusCode, rawBody: rawBody)
    }

    private func attachAttestHeadersIfNeeded(
        to request: inout URLRequest,
        endpoint: APIEndpoint,
        body: Data?
    ) async throws {
        guard endpoint.requiresAttest else { return }
        guard let attestClient else {
            throw APIError.configuration("AppAttestClient is not attached")
        }
        let headers = try await attestClient.makeAssertionHeaders(for: body)
        request.setValue(headers.keyId, forHTTPHeaderField: APIHeader.attestKeyId)
        request.setValue(headers.assertion, forHTTPHeaderField: APIHeader.attestAssertion)
        request.setValue(headers.challenge, forHTTPHeaderField: APIHeader.attestChallenge)
    }

    private static func decodeErrorBody(_ data: Data) -> APIErrorResponse? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(APIErrorResponse.self, from: data)
    }
}
