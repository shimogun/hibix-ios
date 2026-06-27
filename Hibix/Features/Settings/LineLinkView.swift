import SwiftUI

/// LINE 連携画面。コード発行→友だち追加リンク→ShareLink 共有→status ポーリング。
struct LineLinkView: View {
    @State var viewModel: LineLinkViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("LINEで連携")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                }
                .task { await viewModel.start() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView("コードを発行しています…")
        case .code(let code):
            codeView(code)
        case .linked:
            statusView(systemImage: "checkmark.seal.fill",
                       tint: .green,
                       title: "LINE 連携が完了しました",
                       buttonTitle: "完了") { dismiss() }
        case .expired:
            statusView(systemImage: "clock.badge.exclamationmark",
                       tint: .orange,
                       title: "コードの有効期限が切れました",
                       buttonTitle: "コードを再発行") { Task { await viewModel.reissue() } }
        case .error(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("再試行") { Task { await viewModel.reissue() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    private func statusView(systemImage: String,
                            tint: Color,
                            title: String,
                            buttonTitle: String,
                            action: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage).font(.largeTitle).foregroundStyle(tint)
            Text(title).font(.headline).multilineTextAlignment(.center)
            Button(buttonTitle, action: action).buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func codeView(_ code: LineLinkService.LineLinkCode) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                stepLabel(number: "①", text: "公式アカウントを友だち追加")
                if let url = code.addFriendURL {
                    Link(destination: url) {
                        Label("LINEで友だち追加", systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                stepLabel(number: "②", text: "このコードをトークに送信")
                Text(code.code)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .tracking(8)
                    .textSelection(.enabled)
                    .accessibilityLabel("連携コード \(code.code)")

                ShareLink(item: viewModel.shareText) {
                    Label("コードを共有", systemImage: "square.and.arrow.up")
                }

                Text("相手がコードを送信すると、自動で連携されます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .task {
            // 画面表示中は約4秒間隔で linked を確認。
            while !Task.isCancelled {
                if await viewModel.pollOnce() { break }
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    private func stepLabel(number: String, text: String) -> some View {
        HStack(spacing: 8) {
            Text(number).font(.headline)
            Text(text).font(.headline)
        }
    }
}
