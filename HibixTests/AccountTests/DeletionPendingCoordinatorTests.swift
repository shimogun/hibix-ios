import Testing
import Foundation
@testable import Hibix

@Suite("DeletionPendingCoordinator", .serialized)
@MainActor
struct DeletionPendingCoordinatorTests {

    @Test
    func report_setsPendingWithScheduledDate() {
        let coordinator = DeletionPendingCoordinator()
        let scheduled = Date(timeIntervalSince1970: 1_780_000_000)
        let error = APIError.server(
            status: 409,
            code: .deletionPending,
            message: "進行中",
            scheduledDeletionBy: scheduled
        )
        coordinator.report(error)
        #expect(coordinator.pending != nil)
        #expect(coordinator.pending?.scheduledDeletionBy == scheduled)
        #expect(coordinator.pending?.message == "進行中")
    }

    @Test
    func report_ignoresNonDeletionPendingError() {
        let coordinator = DeletionPendingCoordinator()
        let error = APIError.server(
            status: 400,
            code: .invalidUUID,
            message: "bad",
            scheduledDeletionBy: nil
        )
        coordinator.report(error)
        #expect(coordinator.pending == nil)
    }

    @Test
    func dismiss_clearsPending() {
        let coordinator = DeletionPendingCoordinator()
        coordinator.report(.server(
            status: 409,
            code: .deletionPending,
            message: "x",
            scheduledDeletionBy: nil
        ))
        coordinator.dismiss()
        #expect(coordinator.pending == nil)
        #expect(coordinator.cancelState == .idle)
    }

    @Test
    func confirmCancel_withoutAttachedService_setsFailedState() async {
        let coordinator = DeletionPendingCoordinator()
        coordinator.report(.server(
            status: 409,
            code: .deletionPending,
            message: "x",
            scheduledDeletionBy: nil
        ))
        await coordinator.confirmCancel()
        if case .failed = coordinator.cancelState {
            // expected
        } else {
            Issue.record("Expected .failed, got \(coordinator.cancelState)")
        }
    }
}
