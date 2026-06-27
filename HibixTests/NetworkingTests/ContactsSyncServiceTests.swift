import Testing
import Foundation
import GRDB
@testable import Hibix

@Suite("ContactsSyncService", .serialized)
@MainActor
struct ContactsSyncServiceTests {

    private let fixedNow = Date(timeIntervalSince1970: 1_747_440_000)

    private func makeStack(
        handler: @escaping @Sendable (URLRequest) -> (HTTPURLResponse, Data)
    ) throws -> (ContactsSyncService, EmergencyContactsRepository) {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)
        let repo = EmergencyContactsRepository(writer: dbQueue)
        let settings = SettingsRepository(writer: dbQueue)
        let attest = try TestSupport.makeRegisteredAttestClient()
        let client = TestSupport.makeStubAPIClient(handler: handler)
        client.attach(attestClient: attest)
        let svc = ContactsSyncService(apiClient: client, contactsRepo: repo, settings: settings, attest: attest)
        return (svc, repo)
    }

    @Test
    func syncContacts_writesBackServerIdsByOrder() async throws {
        let (svc, repo) = try makeStack { request in
            let resp = #"{"contacts":[{"id":"uuid-a","contact_type":"email","label":null},{"id":"uuid-b","contact_type":"line","label":"兄"}]}"#
            return TestSupport.ok(request, resp)
        }
        let a = try await repo.add(contactType: .email, value: "a@example.com", label: nil, now: fixedNow)
        let b = try await repo.add(contactType: .line, value: "兄", label: "兄", now: fixedNow)
        await svc.syncContacts()
        let listed = try await repo.list()
        #expect(listed.first(where: { $0.id == a.id })?.serverID == "uuid-a")
        #expect(listed.first(where: { $0.id == b.id })?.serverID == "uuid-b")
    }

    @Test
    func syncSettings_sendsPatch() async throws {
        var capturedMethod: String?
        let (svc, _) = try makeStack { request in
            capturedMethod = request.httpMethod
            let resp = #"{"watch_days":2,"watch_mode":"gentle","is_pro":true}"#
            return TestSupport.ok(request, resp)
        }
        try await svc.syncSettings(watchMode: "gentle", watchDays: 2)
        #expect(capturedMethod == "PATCH")
    }

    @Test
    func syncContactsThrowing_propagatesEmailContactRequired() async throws {
        let (svc, repo) = try makeStack { request in
            let body = #"{"error":{"code":"EMAIL_CONTACT_REQUIRED","message":"required"}}"#
            return (HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!,
                    Data(body.utf8))
        }
        _ = try await repo.add(contactType: .line, value: "兄", label: nil, now: fixedNow)
        do {
            try await svc.syncContactsThrowing()
            Issue.record("expected APIError.server")
        } catch let APIError.server(status, code, _, _) {
            #expect(status == 400)
            #expect(code == .emailContactRequired)
        }
    }
}
