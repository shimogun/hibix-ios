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
        StubURLProtocol.handler = handler
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
            register: { @Sendable _ in }
        )
        client.attach(attestClient: attest)

        let _: CheckinResponse = try await client.request(.checkin(checkinAt: Date()))
        #expect(capturedHeaders[APIHeader.uuid] == "uuid-test")
        #expect(capturedHeaders[APIHeader.attestKeyId] == "test-key-id")
        #expect(capturedHeaders[APIHeader.attestChallenge] == "Y2hhbGxlbmdl")
        #expect(capturedHeaders[APIHeader.attestAssertion]?.isEmpty == false)

        try store.reset()
    }
}

// MARK: - URLProtocol stub

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
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
