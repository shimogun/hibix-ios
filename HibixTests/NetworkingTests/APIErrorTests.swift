import Testing
import Foundation
@testable import Hibix

@Suite("APIError parsing")
struct APIErrorTests {

    private func decode(_ json: String) throws -> APIErrorResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(APIErrorResponse.self, from: Data(json.utf8))
    }

    @Test
    func parse_invalidUUID() throws {
        let parsed = try decode(#"""
        {"error": {"code": "INVALID_UUID", "message": "anonymous_uuid is invalid"}}
        """#)
        #expect(parsed.error.code == .invalidUUID)
        #expect(parsed.error.scheduled_deletion_by == nil)
    }

    @Test
    func parse_deletionPending_includesScheduledDeletionBy() throws {
        let parsed = try decode(#"""
        {
          "error": {
            "code": "DELETION_PENDING",
            "message": "削除リクエストが進行中です。",
            "scheduled_deletion_by": "2026-05-19T12:34:56Z"
          }
        }
        """#)
        #expect(parsed.error.code == .deletionPending)
        #expect(parsed.error.scheduled_deletion_by != nil)
    }

    @Test
    func apiError_flags_areDerivedFromCode() {
        let deletion = APIError.server(status: 409, code: .deletionPending, message: "x", scheduledDeletionBy: Date())
        #expect(deletion.isDeletionPending)
        #expect(!deletion.isAttestationFailure)

        let required = APIError.server(status: 403, code: .attestationRequired, message: "x", scheduledDeletionBy: nil)
        #expect(required.isAttestationFailure)
        #expect(!required.isRateLimited)

        let failed = APIError.server(status: 401, code: .attestationFailed, message: "x", scheduledDeletionBy: nil)
        #expect(failed.isAttestationFailure)

        let rate = APIError.server(status: 429, code: .rateLimitExceeded, message: "x", scheduledDeletionBy: nil)
        #expect(rate.isRateLimited)
    }
}

@Suite("APIEndpoint structure")
struct APIEndpointTests {

    @Test
    func paths_areCorrect() {
        #expect(APIEndpoint.checkin(checkinAt: Date()).path == "/api/checkin")
        #expect(APIEndpoint.settings(SettingsPatchBody(watch_days: 1, watch_mode: nil)).path == "/api/settings")
        #expect(APIEndpoint.contacts(ContactsPutBody(contacts: [])).path == "/api/contacts")
        #expect(APIEndpoint.account.path == "/api/account")
        #expect(APIEndpoint.attestChallenge.path == "/api/attest/challenge")
        #expect(APIEndpoint.attestRegister(AttestRegisterBody(key_id: "k", attestation: "a", client_data_hash: "h")).path == "/api/attest/register")
        #expect(APIEndpoint.storekitVerify(StoreKitVerifyBody(jws: "jws")).path == "/api/storekit/verify")
        #expect(APIEndpoint.cancelDeletion.path == "/api/account/cancel-deletion")
        #expect(APIEndpoint.health.path == "/api/health")
    }

    @Test
    func methods_areCorrect() {
        #expect(APIEndpoint.checkin(checkinAt: Date()).method == "POST")
        #expect(APIEndpoint.settings(SettingsPatchBody(watch_days: 1, watch_mode: nil)).method == "PATCH")
        #expect(APIEndpoint.contacts(ContactsPutBody(contacts: [])).method == "PUT")
        #expect(APIEndpoint.account.method == "DELETE")
        #expect(APIEndpoint.health.method == "GET")
    }

    @Test
    func requiresAttest_followsSpec() {
        #expect(APIEndpoint.checkin(checkinAt: Date()).requiresAttest)
        #expect(APIEndpoint.settings(SettingsPatchBody(watch_days: 1, watch_mode: nil)).requiresAttest)
        #expect(APIEndpoint.contacts(ContactsPutBody(contacts: [])).requiresAttest)
        #expect(APIEndpoint.account.requiresAttest)
        #expect(APIEndpoint.storekitVerify(StoreKitVerifyBody(jws: "x")).requiresAttest)
        #expect(APIEndpoint.cancelDeletion.requiresAttest)

        #expect(!APIEndpoint.attestChallenge.requiresAttest)
        #expect(!APIEndpoint.attestRegister(AttestRegisterBody(key_id: "k", attestation: "a", client_data_hash: "h")).requiresAttest)
        #expect(!APIEndpoint.health.requiresAttest)
    }
}
