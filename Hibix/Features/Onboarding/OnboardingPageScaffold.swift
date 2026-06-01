import SwiftUI

/// オンボーディング各ページ共通レイアウト。
/// 上からイラスト→タイトル→サブ→任意の追加UI。背景はFlow側で水彩を敷く。
struct OnboardingPageScaffold<Illustration: View, Extra: View>: View {
    let title: String
    let subtitle: String
    private let illustration: Illustration
    private let extra: Extra

    init(title: String,
         subtitle: String,
         @ViewBuilder illustration: () -> Illustration,
         @ViewBuilder extra: () -> Extra = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.illustration = illustration()
        self.extra = extra()
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            illustration
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.hibixNavy)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.hibixSubNavy)
                    .multilineTextAlignment(.center)
            }
            extra
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
