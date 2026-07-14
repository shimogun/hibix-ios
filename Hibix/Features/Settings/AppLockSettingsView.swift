import SwiftUI

/// PRD v2.2.0 §6 F-08 アプリロック設定画面。
/// 無料時はトグルを操作不可にし、アップグレード導線のみ提供。
struct AppLockSettingsView: View {
    @Bindable private var appLock: AppLockManager
    @Bindable private var entitlement: EntitlementManager
    @State private var isPaywallPresented: Bool = false
    init(dependencies: AppDependencies) {
        self.appLock = dependencies.appLockManager
        self.entitlement = dependencies.entitlementManager
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: lockBinding) {
                    Text("アプリロック")
                }
                .disabled(!entitlement.isPro)
            } footer: {
                if entitlement.isPro {
                    Text("有効にすると、アプリ起動時とバックグラウンドからの復帰時に Face ID / Touch ID / 端末パスコードでの認証を求めます。")
                } else {
                    Text("「アプリロック」は Hibix Pro で利用できます。")
                }
            }

            if !entitlement.isPro {
                Section {
                    Button {
                        isPaywallPresented = true
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Hibix Pro にアップグレード")
                            Spacer()
                        }
                    }
                }
            }

            if let message = appLock.lastErrorMessage {
                Section {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("アプリロック")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPaywallPresented) {
            PaywallView(
                entitlement: entitlement,
                onPurchaseCompleted: {
                    isPaywallPresented = false
                },
                onDismiss: {
                    isPaywallPresented = false
                }
            )
        }
    }

    private var lockBinding: Binding<Bool> {
        Binding(
            get: { appLock.isLockEnabled },
            set: { newValue in
                Task { _ = await appLock.setEnabled(newValue) }
            }
        )
    }
}
