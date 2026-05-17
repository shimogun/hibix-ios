import SwiftUI

/// PRD v2.2.0 §6 F-12 / §5.6 のペイウォール画面。
struct PaywallView: View {
    @Bindable var viewModel: PaywallViewModel
    let onPurchaseCompleted: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                header
                benefits
                Spacer(minLength: 0)
                cta
                footer
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .navigationTitle("Hibix Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる", action: onDismiss)
                }
            }
            .task {
                if case .idle = viewModel.loadState {
                    await viewModel.loadProducts()
                }
            }
            .onChange(of: viewModel.purchaseState) { _, newValue in
                if newValue == .completed {
                    onPurchaseCompleted()
                }
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Hibix Pro")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("一度の購入で、すべての見守り機能が使えます")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit("すべての見守りモード解禁")
            benefit("緊急連絡先メール通知")
            benefit("Face ID / パスコードロック")
            benefit("全期間のピクセルカレンダー")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func benefit(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.tint)
                .font(.title3)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
            Spacer()
        }
    }

    @ViewBuilder
    private var cta: some View {
        VStack(spacing: 12) {
            switch viewModel.loadState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 48)
            case .loaded(let product):
                Button(action: { Task { await viewModel.purchase() } }) {
                    HStack {
                        Spacer()
                        Text("\(product.displayPrice) で購入")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .frame(minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPurchaseInFlight)
            case .failed(let message):
                Text(message)
                    .font(.body)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                Button("再試行") { Task { await viewModel.loadProducts() } }
                    .buttonStyle(.bordered)
            }

            Button("購入を復元") { Task { await viewModel.restorePurchases() } }
                .font(.subheadline)
                .disabled(isPurchaseInFlight)

            statusMessage
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        switch viewModel.purchaseState {
        case .purchasing:
            ProgressView("購入処理中…")
                .font(.footnote)
        case .restoring:
            ProgressView("復元中…")
                .font(.footnote)
        case .failed(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        case .completed:
            Text("Pro 機能が解禁されました")
                .font(.footnote)
                .foregroundStyle(.green)
        case .idle, .cancelledByUser:
            EmptyView()
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("購入は一度のみ・解約不要")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var isPurchaseInFlight: Bool {
        viewModel.purchaseState == .purchasing || viewModel.purchaseState == .restoring
    }
}
