import Testing
import Foundation
import GRDB
@testable import Hibix

@Suite("LineLinkService", .serialized)
@MainActor
struct LineLinkServiceTests {

    private let fixedNow = Date(timeIntervalSince1970: 1_747_440_000)

    private func makeStack(
        handler: @escaping @Sendable (URLRequest) -> (HTTPURLResponse, Data)
    ) throws -> (LineLinkService, EmergencyContactsRepository) {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)
        let repo = EmergencyContactsRepository(writer: dbQueue)
        let settings = SettingsRepository(writer: dbQueue)
        let attest = try TestSupport.makeRegisteredAttestClient()
        let client = TestSupport.makeStubAPIClient(handler: handler)
        client.attach(attestClient: attest)
        let sync = ContactsSyncService(apiClient: client, contactsRepo: repo, settings: settings, attest: attest)
        let svc = LineLinkService(apiClient: client, contactsRepo: repo, contactsSync: sync)
        return (svc, repo)
    }

    @Test
    func issueCode_syncsWhenServerIdMissing_thenPostsCode_andSetsPending() async throws {
        let (svc, repo) = try makeStack { request in
            if request.url!.path == "/api/contacts" {
                let r = #"{"contacts":[{"id":"uuid-b","contact_type":"line","label":"兄"}]}"#
                return TestSupport.ok(request, r)
            } else {
                #expect(request.url!.path == "/api/contacts/uuid-b/line/issue-code")
                let r = #"{"code":"A2B3C4","expires_at":1781234567,"add_friend_url":null}"#
                return TestSupport.ok(request, r)
            }
        }
        let b = try await repo.add(contactType: .line, value: "兄", label: "兄", now: fixedNow)
        let code = try await svc.issueCode(localContactID: b.id)
        #expect(code.code == "A2B3C4")
        #expect(code.expiresAt == Date(timeIntervalSince1970: 1_781_234_567))
        let listed = try await repo.list()
        #expect(listed.first(where: { $0.id == b.id })?.serverID == "uuid-b")
        #expect(listed.first(where: { $0.id == b.id })?.lineLinkStatus == .pending)
    }

    @Test
    func fetchStatus_updatesLocalStatusToLinked() async throws {
        let (svc, repo) = try makeStack { request in
            TestSupport.ok(request, #"{"status":"linked","code_expires_at":null}"#)
        }
        let b = try await repo.add(contactType: .line, value: "兄", label: nil, now: fixedNow)
        try await repo.updateServerMapping([(localID: b.id, serverID: "uuid-b")])
        let status = try await svc.fetchStatus(localContactID: b.id)
        #expect(status == .linked)
        let listed = try await repo.list()
        #expect(listed.first(where: { $0.id == b.id })?.lineLinkStatus == .linked)
    }
}
