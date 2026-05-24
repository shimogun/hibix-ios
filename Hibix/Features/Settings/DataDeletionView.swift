import SwiftUI

/// PRD v2.2.0 §6 F-11 — データ削除権 UI。
///
/// 設定 > データを削除 から遷移する。警告ダイアログで確定すると、
/// サーバー削除リクエストを発行 → ローカル消去 → アプリ再起動の順に進む。
struct DataDeletionView: View {
    @State private var viewModel: DataDeletionViewModel
    @Environment(\.appRebooter) private var rebooter

    init(dependencies: AppDependencies) {
        _viewModel = State(initialValue: DataDeletionViewModel(
            service: dependencies.accountDeletionService
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                consequencesSection
                serverSlaSection

                if let message = viewModel.failureMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                deleteButton

                Spacer(minLength: 24)
            }
            .padding(20)
        }
        .navigationTitle("データを削除")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.state == .confirming {
                confirmationOverlay
                    .transition(.opacity)
            }
        }
        .overlay {
            if viewModel.isBusy {
                deletionProgress
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.state == .confirming)
    }

    private var confirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { viewModel.dismissConfirmation() }
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text("本当に削除しますか？")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("この操作は取り消せません。アプリ内・サーバー上の全データが消去されます。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button {
                        viewModel.dismissConfirmation()
                    } label: {
                        Text("キャンセル")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        Task { await runDeletion() }
                    } label: {
                        Text("削除する")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .padding(.horizontal, 32)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("削除確認ダイアログ")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("アカウントとデータを削除")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Hibix に記録した気分・メモ・連絡先・購入情報を完全に削除します。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var consequencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("削除されるもの")
                .font(.headline)
            bullet("ピクセルカレンダーの全履歴と気分メモ")
            bullet("緊急連絡先")
            bullet("購入情報・Pro 解禁状態（再購入は復元で戻せます）")
            bullet("通知設定・アプリロック設定")
            bullet("匿名 UUID（再インストールで新規発行）")
        }
    }

    private var serverSlaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("サーバーからの完全消去")
                .font(.headline)
            Text("削除リクエスト受理から 48 時間以内にサーバー上のすべてのデータを物理削除します。48 時間以内であれば、アプリを再インストールして同じ Apple ID から取り消しを行えます。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("・")
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
        }
    }

    private var deleteButton: some View {
        Button {
            viewModel.presentConfirmation()
        } label: {
            Text("データを削除")
                .font(.body)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(viewModel.isBusy)
        .accessibilityHint("削除内容の確認ダイアログが表示されます")
    }

    private var deletionProgress: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("削除中…")
                    .font(.body)
                    .foregroundStyle(.white)
            }
            .padding(28)
            .background(Color(uiColor: .systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("データを削除しています")
    }

    private func runDeletion() async {
        let rebooter = self.rebooter
        await viewModel.confirmDeletion {
            rebooter.reboot()
        }
    }
}
