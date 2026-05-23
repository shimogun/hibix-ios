import Testing
import Foundation
@testable import Hibix

@Suite("DataDeletionViewModel", .serialized)
@MainActor
struct DataDeletionViewModelTests {

    @Test
    func initialState_isIdle() {
        let service = MockAccountDeletionService()
        let viewModel = DataDeletionViewModel(service: service)
        #expect(viewModel.state == .idle)
        #expect(viewModel.isBusy == false)
        #expect(viewModel.isCompleted == false)
    }

    @Test
    func presentConfirmation_movesToConfirming() {
        let service = MockAccountDeletionService()
        let viewModel = DataDeletionViewModel(service: service)
        viewModel.presentConfirmation()
        #expect(viewModel.state == .confirming)
    }

    @Test
    func dismissConfirmation_returnsToIdle() {
        let service = MockAccountDeletionService()
        let viewModel = DataDeletionViewModel(service: service)
        viewModel.presentConfirmation()
        viewModel.dismissConfirmation()
        #expect(viewModel.state == .idle)
    }

    @Test
    func confirmDeletion_callsServer_thenPurges_thenReboots() async {
        let service = MockAccountDeletionService()
        service.deletionResponse = AccountDeleteResponse(
            deletion_request_id: "req-1",
            scheduled_deletion_by: Date().addingTimeInterval(48 * 3600)
        )
        let viewModel = DataDeletionViewModel(service: service)
        var rebootCount = 0
        await viewModel.confirmDeletion {
            rebootCount += 1
        }
        #expect(service.requestDeletionCallCount == 1)
        #expect(service.purgeLocalDataCallCount == 1)
        #expect(viewModel.state == .completed)
        #expect(rebootCount == 1)
    }

    @Test
    func confirmDeletion_serverFailure_stillPurgesAndReboots() async {
        let service = MockAccountDeletionService()
        service.deletionError = APIError.server(
            status: 500,
            code: .internalError,
            message: "server down",
            scheduledDeletionBy: nil
        )
        let viewModel = DataDeletionViewModel(service: service)
        var rebootCount = 0
        await viewModel.confirmDeletion {
            rebootCount += 1
        }
        // ユーザーの削除権を優先 → サーバー失敗でもローカルは消えて再起動する
        #expect(service.requestDeletionCallCount == 1)
        #expect(service.purgeLocalDataCallCount == 1)
        #expect(viewModel.state == .completed)
        #expect(rebootCount == 1)
    }
}

// MARK: - Mock

@MainActor
final class MockAccountDeletionService: AccountDeletionServicing {
    var deletionResponse: AccountDeleteResponse?
    var deletionError: APIError?
    var cancelResponse: CancelDeletionResponse?
    var cancelError: APIError?

    private(set) var requestDeletionCallCount = 0
    private(set) var cancelDeletionCallCount = 0
    private(set) var purgeLocalDataCallCount = 0

    func requestDeletion() async throws -> AccountDeleteResponse {
        requestDeletionCallCount += 1
        if let deletionError { throw deletionError }
        return deletionResponse ?? AccountDeleteResponse(
            deletion_request_id: "mock-req",
            scheduled_deletion_by: Date().addingTimeInterval(48 * 3600)
        )
    }

    func cancelDeletion() async throws -> CancelDeletionResponse {
        cancelDeletionCallCount += 1
        if let cancelError { throw cancelError }
        return cancelResponse ?? CancelDeletionResponse(cancelled_deletion_request_id: "mock-req")
    }

    func purgeLocalData() async {
        purgeLocalDataCallCount += 1
    }
}
