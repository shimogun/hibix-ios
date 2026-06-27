import Testing
import Foundation
import GRDB
@testable import Hibix

@Suite("LineLinkViewModel", .serialized)
@MainActor
struct LineLinkViewModelTests {

    private let fixedNow = Date(timeIntervalSince1970: 1_747_440_000)

    private func seedLineContact(_ repo: EmergencyContactsRepository) async throws -> Int64 {
        let c = try await repo.add(contactType: .line, value: "兄", label: "兄", now: fixedNow)
        try await repo.updateServerMapping([(localID: c.id, serverID: "uuid-b")])
        return c.id
    }

    @Test
    func start_setsCodePhase() async throws {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)
        let repo = EmergencyContactsRepository(writer: dbQueue)
        let settings = SettingsRepository(writer: dbQueue)
        let attest = try TestSupport.makeRegisteredAttestClient()
        let client = TestSupport.makeStubAPIClient { request in
            if request.url!.path.hasSuffix("/line/issue-code") {
                return TestSupport.ok(request, #"{"code":"A2B3C4","expires_at":1781234567,"add_friend_url":null}"#)
            }
            return TestSupport.ok(request, #"{"status":"pending","code_expires_at":null}"#)
        }
        client.attach(attestClient: attest)
        let sync = ContactsSyncService(apiClient: client, contactsRepo: repo, settings: settings, attest: attest)
        let svc = LineLinkService(apiClient: client, contactsRepo: repo, contactsSync: sync)
        let id = try await seedLineContact(repo)
        let vm = LineLinkViewModel(service: svc, localContactID: id)

        await vm.start()
        if case .code(let c) = vm.phase {
            #expect(c.code == "A2B3C4")
        } else {
            Issue.record("expected .code phase, got \(vm.phase)")
        }
    }

    @Test
    func pollOnce_returnsTrueAndLinkedPhase_whenLinked() async throws {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)
        let repo = EmergencyContactsRepository(writer: dbQueue)
        let settings = SettingsRepository(writer: dbQueue)
        let attest = try TestSupport.makeRegisteredAttestClient()
        let client = TestSupport.makeStubAPIClient { request in
            if request.url!.path.hasSuffix("/line/issue-code") {
                // 遠い未来の expires_at(2096年) → 失効判定にかからない。
                return TestSupport.ok(request, #"{"code":"A2B3C4","expires_at":4000000000,"add_friend_url":null}"#)
            }
            return TestSupport.ok(request, #"{"status":"linked","code_expires_at":null}"#)
        }
        client.attach(attestClient: attest)
        let sync = ContactsSyncService(apiClient: client, contactsRepo: repo, settings: settings, attest: attest)
        let svc = LineLinkService(apiClient: client, contactsRepo: repo, contactsSync: sync)
        let id = try await seedLineContact(repo)
        let vm = LineLinkViewModel(service: svc, localContactID: id)

        await vm.start()
        let done = await vm.pollOnce()
        #expect(done == true)
        if case .linked = vm.phase {} else { Issue.record("expected .linked phase, got \(vm.phase)") }
    }

    @Test
    func pollOnce_expiredCode_setsExpiredPhase() async throws {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)
        let repo = EmergencyContactsRepository(writer: dbQueue)
        let settings = SettingsRepository(writer: dbQueue)
        let attest = try TestSupport.makeRegisteredAttestClient()
        let client = TestSupport.makeStubAPIClient { request in
            if request.url!.path.hasSuffix("/line/issue-code") {
                // 既に過去の expires_at(2001年) → pollOnce で expired 判定。
                return TestSupport.ok(request, #"{"code":"A2B3C4","expires_at":1000000000,"add_friend_url":null}"#)
            }
            return TestSupport.ok(request, #"{"status":"pending","code_expires_at":null}"#)
        }
        client.attach(attestClient: attest)
        let sync = ContactsSyncService(apiClient: client, contactsRepo: repo, settings: settings, attest: attest)
        let svc = LineLinkService(apiClient: client, contactsRepo: repo, contactsSync: sync)
        let id = try await seedLineContact(repo)
        let vm = LineLinkViewModel(service: svc, localContactID: id)

        await vm.start()
        let done = await vm.pollOnce()
        #expect(done == false)
        if case .expired = vm.phase {} else { Issue.record("expected .expired phase, got \(vm.phase)") }
    }
}
