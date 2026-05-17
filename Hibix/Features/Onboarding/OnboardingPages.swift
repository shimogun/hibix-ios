import SwiftUI

struct OnboardingConceptPage: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            PixelTilesIllustration()
            VStack(spacing: 12) {
                Text("毎日のひとタップが、\n365日のあなたになる")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Text("色で気分を残すだけ。\n1年分のあなたの心が、1画面に積み上がります。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }
}

struct OnboardingWatchPage: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            WatchArrowIllustration()
            VStack(spacing: 12) {
                Text("設定日数タップがなければ、\n大切な人にだけメールが届きます")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Text("「いつもの記録がない」を、\nそっと家族に知らせます。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("※データはあなたの iPhone から出ません")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }
}

struct OnboardingPermissionPage: View {
    let isRequestingAuthorization: Bool
    let didDecideAuthorization: Bool
    let authorizationGranted: Bool
    let onAllow: () -> Void
    let onSkip: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            BellIllustration()
            VStack(spacing: 12) {
                Text("朝/夜の記録リマインダーを\n送ってもいいですか?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Text("通知は朝 9:00 / 夜 21:00 に届きます。\n後で設定画面から変更できます。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button(action: onAllow) {
                    Text(isRequestingAuthorization ? "確認中..." : "許可する")
                        .font(.body)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRequestingAuthorization || didDecideAuthorization)
                .accessibilityHint("通知の許可ダイアログを表示します")

                Button(action: onSkip) {
                    Text("あとで")
                        .font(.body)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(isRequestingAuthorization || didDecideAuthorization)
            }

            if didDecideAuthorization {
                Text(authorizationGranted ? "通知を予約しました" : "通知はオフのままです(設定からあとで変更できます)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)

            Button(action: onStart) {
                Text("はじめる")
                    .font(.body)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(.primary)
            .disabled(!didDecideAuthorization)
            .accessibilityHint(didDecideAuthorization ? "ホーム画面へ進みます" : "まず「許可する」または「あとで」を選択してください")
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Illustrations

private struct PixelTilesIllustration: View {
    private let palette: [Color] = [
        Color(red: 74/255, green: 85/255, blue: 104/255),
        Color(red: 66/255, green: 153/255, blue: 225/255),
        Color(red: 56/255, green: 178/255, blue: 172/255),
        Color(red: 236/255, green: 201/255, blue: 75/255),
        Color(red: 237/255, green: 137/255, blue: 54/255),
        Color(red: 159/255, green: 122/255, blue: 234/255),
        Color(red: 246/255, green: 135/255, blue: 179/255)
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { col in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(palette[(row * 7 + col) % palette.count].opacity(0.85))
                            .frame(width: 28, height: 28)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct WatchArrowIllustration: View {
    var body: some View {
        HStack(spacing: 24) {
            Image(systemName: "iphone")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Image(systemName: "arrow.right")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.secondary)
            Image(systemName: "person.2.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
        }
        .accessibilityHidden(true)
    }
}

private struct BellIllustration: View {
    var body: some View {
        Image(systemName: "bell.badge.fill")
            .font(.system(size: 96))
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
    }
}
