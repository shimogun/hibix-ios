import Testing
import Foundation
@testable import Hibix

@Suite("APIClient", .serialized)
@MainActor
struct APIClientTests {

    private static let testBaseURL: URL = {
        guard let url = URL(string: "http://test.invalid") else {
            fatalError("invalid test URL literal")
        }
        return url
    }()

    private func makeClient(handler: @escaping @Sendable (URLRequest) -> (HTTPURLResponse, Data)) -> (APIClient, URL) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.setHandler(forUUID: "uuid-test", handler)
        let session = URLSession(configuration: config)
        let baseURL = Self.testBaseURL
        let client = APIClient(baseURL: baseURL, anonymousUUID: "uuid-test", session: session)
        return (client, baseURL)
    }

    @Test
    func attestChallenge_decodesResponse() async throws {
        let expectedURL = Self.testBaseURL.appendingPathComponent("/api/attest/challenge")
        let (client, _) = makeClient { request in
            #expect(request.url == expectedURL)
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "X-Hibix-UUID") == "uuid-test")
            let body = #"{"challenge":"YWJjZGVm","expires_at":"2026-05-17T12:39:56Z"}"#
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(body.utf8))
        }
        let resp: AttestChallengeResponse = try await client.request(.attestChallenge)
        #expect(resp.challenge == "YWJjZGVm")
    }

    @Test
    func mutating_withoutAttachedAttestClient_throwsConfiguration() async {
        let (client, _) = makeClient { _ in
            (HTTPURLResponse(url: URL(string: "http://x")!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        do {
            _ = try await client.requestIgnoringResponse(.checkin(checkinAt: Date()))
            Issue.record("Expected APIError.configuration")
        } catch let APIError.configuration(detail) {
            #expect(detail.contains("AppAttestClient"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func errorResponse_isParsedIntoAPIError() async {
        let (client, _) = makeClient { request in
            let body = #"{"error":{"code":"INVALID_UUID","message":"bad"}}"#
            return (HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!,
                    Data(body.utf8))
        }
        do {
            let _: AttestChallengeResponse = try await client.request(.attestChallenge)
            Issue.record("Expected APIError.server")
        } catch let APIError.server(status, code, message, _) {
            #expect(status == 400)
            #expect(code == .invalidUUID)
            #expect(message == "bad")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func deletionPending_parsesScheduledDeletionBy() async {
        let (client, _) = makeClient { request in
            let body = #"""
            {"error":{"code":"DELETION_PENDING","message":"進行中","scheduled_deletion_by":"2026-05-19T12:34:56Z"}}
            """#
            return (HTTPURLResponse(url: request.url!, statusCode: 409, httpVersion: nil, headerFields: nil)!,
                    Data(body.utf8))
        }
        do {
            let _: AttestChallengeResponse = try await client.request(.attestChallenge)
            Issue.record("Expected APIError.server")
        } catch let APIError.server(status, code, _, scheduled) {
            #expect(status == 409)
            #expect(code == .deletionPending)
            #expect(scheduled != nil)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func unexpectedStatus_withoutJsonError_capturesRawBody() async {
        let (client, _) = makeClient { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!,
                    Data("oops".utf8))
        }
        do {
            let _: AttestChallengeResponse = try await client.request(.attestChallenge)
            Issue.record("Expected APIError.unexpectedStatus")
        } catch let APIError.unexpectedStatus(status, raw) {
            #expect(status == 500)
            #expect(raw == "oops")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func attachedAttestClient_addsAttestHeaders() async throws {
        var capturedHeaders: [String: String] = [:]
        let (client, _) = makeClient { request in
            for header in [APIHeader.uuid, APIHeader.attestKeyId, APIHeader.attestAssertion, APIHeader.attestChallenge] {
                capturedHeaders[header] = request.value(forHTTPHeaderField: header)
            }
            let body = #"{"last_checkin_at":"2026-05-17T12:34:56Z"}"#
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(body.utf8))
        }

        let fakeService = FakeAppAttestService()
        let store = AppAttestKeyStore(service: UUID().uuidString)
        try store.saveKeyId("test-key-id")
        try store.setRegistered(true)
        let attest = AppAttestClient(
            service: fakeService,
            store: store,
            fetchChallenge: { @Sendable in
                AttestChallengeResponse(challenge: "Y2hhbGxlbmdl", expires_at: Date().addingTimeInterval(300))
            },
            register: { @Sendable _, _ in }
        )
        client.attach(attestClient: attest)

        let _: CheckinResponse = try await client.request(.checkin(checkinAt: Date()))
        #expect(capturedHeaders[APIHeader.uuid] == "uuid-test")
        #expect(capturedHeaders[APIHeader.attestKeyId] == "test-key-id")
        #expect(capturedHeaders[APIHeader.attestChallenge] == "Y2hhbGxlbmdl")
        #expect(capturedHeaders[APIHeader.attestAssertion]?.isEmpty == false)

        try store.reset()
    }

    // MARK: - v1.1 contacts / LINE

    private func makeRegisteredAttest() throws -> AppAttestClient {
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

    @Test
    func contacts_encodesPeerModelBody_andDecodesResponse() async throws {
        var capturedContacts: [[String: Any]] = []
        var capturedMethod: String?
        let (client, _) = makeClient { request in
            capturedMethod = request.httpMethod
            let bodyData = readHTTPBody(request)
            if let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
               let contacts = json["contacts"] as? [[String: Any]] {
                capturedContacts = contacts
            }
            let resp = #"{"contacts":[{"id":"uuid-a","contact_type":"email","label":null},{"id":"uuid-b","contact_type":"line","label":"兄"}]}"#
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(resp.utf8))
        }
        client.attach(attestClient: try makeRegisteredAttest())

        let body = ContactsPutBody(contacts: [
            ContactInputBody(id: nil, contact_type: "email", email: "a@example.com", label: nil),
            ContactInputBody(id: "uuid-b", contact_type: "line", email: nil, label: "兄"),
        ])
        let resp: ContactsResponse = try await client.request(.contacts(body))

        #expect(capturedMethod == "PUT")
        #expect(resp.contacts.count == 2)
        #expect(resp.contacts[0].id == "uuid-a")
        #expect(resp.contacts[1].contact_type == "line")
        #expect(capturedContacts.count == 2)
        #expect(capturedContacts[0]["contact_type"] as? String == "email")
        #expect(capturedContacts[0]["email"] as? String == "a@example.com")
        #expect(capturedContacts[0]["id"] == nil)                 // 新規は id キー無し
        #expect(capturedContacts[1]["id"] as? String == "uuid-b") // 既存は id 付き
        #expect(capturedContacts[1]["email"] == nil)              // line 型は email キー無し
    }

    @Test
    func lineIssueCode_postsToContactPath_andDecodesEpoch() async throws {
        var capturedURL: URL?
        var capturedMethod: String?
        let (client, base) = makeClient { request in
            capturedURL = request.url
            capturedMethod = request.httpMethod
            let resp = #"{"code":"A2B3C4","expires_at":1781234567,"add_friend_url":"https://line.me/R/ti/p/@hibix"}"#
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(resp.utf8))
        }
        client.attach(attestClient: try makeRegisteredAttest())

        let resp: LineIssueCodeResponse = try await client.request(.lineIssueCode(serverContactID: "uuid-b"))
        #expect(resp.code == "A2B3C4")
        #expect(resp.expires_at == 1_781_234_567)
        #expect(resp.add_friend_url == "https://line.me/R/ti/p/@hibix")
        #expect(capturedMethod == "POST")
        #expect(capturedURL == base.appendingPathComponent("/api/contacts/uuid-b/line/issue-code"))
    }

    @Test
    func lineStatus_getsStatus_andNullableExpiry() async throws {
        var capturedURL: URL?
        var capturedMethod: String?
        let (client, base) = makeClient { request in
            capturedURL = request.url
            capturedMethod = request.httpMethod
            let resp = #"{"status":"linked","code_expires_at":null}"#
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(resp.utf8))
        }
        client.attach(attestClient: try makeRegisteredAttest())

        let resp: LineStatusResponse = try await client.request(.lineStatus(serverContactID: "uuid-b"))
        #expect(resp.status == "linked")
        #expect(resp.code_expires_at == nil)
        #expect(capturedMethod == "GET")
        #expect(capturedURL == base.appendingPathComponent("/api/contacts/uuid-b/line/status"))
    }
}

/// URLProtocol 経由のリクエストは body が `httpBodyStream` に入るため、ストリームから読み出す。
private func readHTTPBody(_ request: URLRequest) -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let bufferSize = 4096
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)
        if read <= 0 { break }
        data.append(buffer, count: read)
    }
    return data
}

// MARK: - URLProtocol stub

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    /// `X-Hibix-UUID` ごとに handler を分離（並列実行される複数 Suite が衝突しないように）。
    nonisolated(unsafe) private static var handlers: [String: @Sendable (URLRequest) -> (HTTPURLResponse, Data)] = [:]
    private static let lock = NSLock()

    static func setHandler(forUUID uuid: String, _ handler: @escaping @Sendable (URLRequest) -> (HTTPURLResponse, Data)) {
        lock.lock(); defer { lock.unlock() }
        handlers[uuid] = handler
    }

    static func handler(forUUID uuid: String?) -> (@Sendable (URLRequest) -> (HTTPURLResponse, Data))? {
        lock.lock(); defer { lock.unlock() }
        guard let uuid else { return nil }
        return handlers[uuid]
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let uuid = request.value(forHTTPHeaderField: "X-Hibix-UUID")
        guard let handler = Self.handler(forUUID: uuid) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
