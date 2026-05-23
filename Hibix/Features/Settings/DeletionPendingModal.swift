import SwiftUI

/// PRD v2.2.0 §8.5 / §8.10 — 409 `DELETION_PENDING` を受けた時に表示するモーダル。
///
/// `DeletionPendingCoordinator.pending` が non-nil になると `RootView` から sheet で出される。
/// ユーザーは「取り消す」または「あとで」を選べる。
struct DeletionPendingModal: View {
    @Bindable var coordinator: DeletionPendingCoordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)

                    Text("削除リクエストが進行中です")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let pending = coordinator.pending {
                        Text(pending.message)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        if let by = pending.scheduledDeletionBy {
                            Label {
                                Text("予定: \(by.formatted(date: .abbreviated, time: .shortened)) までに完全消去")
                                    .font(.callout)
                            } icon: {
                                Image(systemName: "clock")
                            }
                            .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("続けるには取り消してください。")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    if case .failed(let message) = coordinator.cancelState {
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    cancelButton

                    Button {
                        coordinator.dismiss()
                    } label: {
                        Text("あとで")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isCancelling)
                }
                .padding(20)
            }
            .navigationTitle("確認")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(isCancelling)
    }

    private var isCancelling: Bool {
        if case .cancelling = coordinator.cancelState { return true }
        return false
    }

    private var cancelButton: some View {
        Button {
            Task { await coordinator.confirmCancel() }
        } label: {
            HStack {
                if isCancelling {
                    ProgressView()
                }
                Text(isCancelling ? "取り消し中…" : "削除を取り消す")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isCancelling)
        .accessibilityHint("削除リクエストを取り消して、通常の利用を再開します")
    }
}
