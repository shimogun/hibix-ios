import SwiftUI

/// PRD §5.6 / §6 F-12 のペイウォール画面。
/// v1.1: 7日間無料トライアル（¥480/月）を主役に、買い切り lifetime（¥5,800）を併置。
struct PaywallView: View {
    @Bindable var viewModel: PaywallViewModel
    let onPurchaseCompleted: () -> Void
    let onDismiss: () -> Void

    /// サブスク審査（App Store 3.1.2）に必須の規約リンク。
    /// ※最終URLはオーナー確認（暫定: 特商法表記と同ドメイン運用）。
    private enum LegalLinks {
        static let eula = URL(string: "https://shimogun.com/eula")
        static let privacy = URL(string: "https://shimogun.com/privacy")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    benefits
                    hook
                    cta
                    compliance
                    statusMessage
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
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

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("7日間、ぜんぶ無料でお試し。")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text("見守りも、全期間カレンダーも。\n合わなければ解約OK。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit("すべての見守りモード（ゆるつながり／まいにち共有）")
            benefit("記録が途絶えたら、登録した人へお知らせ")
            benefit("全期間のピクセルカレンダー")
            benefit("Face ID・パスコードロック")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func benefit(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.tint)
                .font(.title3)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
            Spacer(minLength: 0)
        }
    }

    private var hook: some View {
        Text("離れた家族の安心が、月ワンコイン。")
            .font(.footnote)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    // MARK: - CTA

    @ViewBuilder
    private var cta: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 48)
        case .loaded(let offer):
            VStack(spacing: 12) {
                if let subscription = offer.subscription {
                    subscriptionButton(subscription)
                }
                if let lifetime = offer.lifetime {
                    lifetimeButton(lifetime)
                }
            }
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                    .font(.body)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                Button("再試行") { Task { await viewModel.loadProducts() } }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func subscriptionButton(_ subscription: SubscriptionDisplay) -> some View {
        Button(action: { Task { await viewModel.purchase(.subscription) } }) {
            VStack(spacing: 2) {
                Text(primaryTitle(subscription))
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(primarySubtitle(subscription))
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isPurchaseInFlight)
    }

    private func lifetimeButton(_ lifetime: StoreKitProductDisplay) -> some View {
        Button(action: { Task { await viewModel.purchase(.lifetime) } }) {
            Text("ずっと使う（買い切り \(lifetime.displayPrice)）")
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.bordered)
        .disabled(isPurchaseInFlight)
    }

    private func primaryTitle(_ subscription: SubscriptionDisplay) -> String {
        if subscription.isEligibleForTrial {
            return "7日間無料ではじめる"
        }
        return "\(subscription.displayPrice)/月ではじめる"
    }

    private func primarySubtitle(_ subscription: SubscriptionDisplay) -> String {
        if subscription.isEligibleForTrial {
            return "その後 \(subscription.displayPrice)/月"
        }
        return "自動更新・いつでも解約可"
    }

    // MARK: - Compliance (App Store 3.1.2)

    @ViewBuilder
    private var compliance: some View {
        VStack(spacing: 8) {
            if showsSubscriptionDisclosure {
                Text("無料期間終了後 \(subscriptionPriceText)/月で自動更新されます。いつでも解約できます。購読は App の設定からいつでも管理・解約できます。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                if let eula = LegalLinks.eula {
                    Link("利用規約", destination: eula)
                }
                if let privacy = LegalLinks.privacy {
                    Link("プライバシーポリシー", destination: privacy)
                }
            }
            .font(.caption2)

            Button("購入を復元") { Task { await viewModel.restorePurchases() } }
                .font(.subheadline)
                .disabled(isPurchaseInFlight)
        }
    }

    private var showsSubscriptionDisclosure: Bool {
        if case .loaded(let offer) = viewModel.loadState {
            return offer.subscription != nil
        }
        return false
    }

    private var subscriptionPriceText: String {
        if case .loaded(let offer) = viewModel.loadState, let sub = offer.subscription {
            return sub.displayPrice
        }
        return "¥480"
    }

    // MARK: - Status

    @ViewBuilder
    private var statusMessage: some View {
        switch viewModel.purchaseState {
        case .purchasing:
            ProgressView("購入処理中…")
                .font(.footnote)
        case .restoring:
            ProgressView("復元中…")
                .font(.footnote)
        case .pendingApproval:
            Text("承認待ちです。承認されると Pro 機能が有効になります。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        case .failed(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        case .completed:
            Text("Pro 機能が有効になりました")
                .font(.footnote)
                .foregroundStyle(.green)
        case .idle, .cancelledByUser:
            EmptyView()
        }
    }

    private var isPurchaseInFlight: Bool {
        viewModel.purchaseState == .purchasing || viewModel.purchaseState == .restoring
    }
}
