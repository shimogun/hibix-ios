import SwiftUI

// MARK: - ① コンセプト

struct OnboardingConceptPage: View {
    var body: some View {
        OnboardingPageScaffold(
            title: "気分を記録すると、\n安心がつながる",
            subtitle: "毎日の気分記録が、\nあなた自身と大切な人をそっと支えます。"
        ) {
            HStack(spacing: 14) {
                Image(systemName: "person.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.hibixSubNavy)
                PixelPreviewIllustration(filledDays: 12, columns: 4, rows: 3)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.hibixSubNavy)
            }
        }
    }
}

// MARK: - ② 気分記録

struct OnboardingMoodPage: View {
    var body: some View {
        OnboardingPageScaffold(
            title: "1日1回、気分を選ぶだけ",
            subtitle: "5段階の気分から選択"
        ) {
            HStack(spacing: 14) {
                ForEach(MoodLevel.allCases, id: \.self) { level in
                    VStack(spacing: 6) {
                        Image(level.iconAssetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                        Text(level.displayName)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.hibixNavy)
                    }
                }
            }
        }
    }
}

// MARK: - ③ ピクセルカレンダー

struct OnboardingCalendarPage: View {
    var body: some View {
        OnboardingPageScaffold(
            title: "気分の変化を見える化",
            subtitle: "毎日の記録が、\nあなただけのピクセルカレンダーになります。"
        ) {
            PixelPreviewIllustration(filledDays: 76, columns: 10, rows: 9)
        }
    }
}

// MARK: - ④ 見守りモード

struct OnboardingWatchModePage: View {
    var body: some View {
        OnboardingPageScaffold(
            title: "あなたに合った見守り方",
            subtitle: "3つのモードから選べます"
        ) {
            EmptyView()
        } extra: {
            VStack(spacing: 10) {
                ModeInfoCard(title: "おひとりさま", detail: "自分のために記録", isPro: false)
                ModeInfoCard(title: "ゆるつながり", detail: "必要なときだけ通知", isPro: true)
                ModeInfoCard(title: "まいにち共有", detail: "家族と毎日共有", isPro: true)
            }
        }
    }
}

// MARK: - ⑤ 安否通知

struct OnboardingSafetyPage: View {
    var body: some View {
        OnboardingPageScaffold(
            title: "もしもの時だけ知らせる",
            subtitle: "一定期間記録がない場合、\n登録した連絡先へ通知します。"
        ) {
            VStack(spacing: 8) {
                WatchFlowStep(text: "記録なし")
                Image(systemName: "arrow.down").foregroundStyle(Color.hibixPeriwinkle)
                WatchFlowStep(text: "7日経過")
                Image(systemName: "arrow.down").foregroundStyle(Color.hibixPeriwinkle)
                WatchFlowStep(text: "メール通知", systemImage: "envelope.fill")
            }
        } extra: {
            Text("※日数は設定で変更できます")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(Color.hibixSubText)
        }
    }
}

// MARK: - ⑥ プライバシー

struct OnboardingPrivacyPage: View {
    private static let points = ["端末内保存", "外部共有なし", "データ削除可能"]
    var body: some View {
        OnboardingPageScaffold(
            title: "データはあなたのもの",
            subtitle: "記録は端末内に保存。\n第三者へ共有されません。"
        ) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.hibixSubNavy)
        } extra: {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Self.points, id: \.self) { point in
                    Label(point, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.hibixNavy)
                }
            }
        }
    }
}

// MARK: - ⑦ アプリロック

struct OnboardingAppLockPage: View {
    var body: some View {
        OnboardingPageScaffold(
            title: "気分記録を守る",
            subtitle: "Face IDやパスコードで保護できます。"
        ) {
            VStack(spacing: 12) {
                Image(systemName: "faceid")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.hibixSubNavy)
                Text("● ● ● ●")
                    .font(.title3)
                    .foregroundStyle(Color.hibixPeriwinkle)
            }
            .frame(width: 150, height: 180)
            .hibixGlassCard(cornerRadius: 24)
        }
    }
}

// MARK: - ⑧ Pro

struct OnboardingProPage: View {
    var body: some View {
        OnboardingPageScaffold(
            title: "買い切りで、ずっと使える",
            subtitle: "サブスクなし。\n一度の購入で全機能を解放。"
        ) {
            EmptyView()
        } extra: {
            VStack(spacing: 14) {
                ProCompareTable()
                Text("¥2,800")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(Color.hibixNavy)
                + Text("  買い切り")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.hibixSubText)
            }
        }
    }
}

// MARK: - ⑨ 開始

struct OnboardingStartPage: View {
    let onSelectMode: (WatchMode) -> Void

    var body: some View {
        OnboardingPageScaffold(
            title: "今日から始めよう",
            subtitle: "あなたに合った見守りモードを選択"
        ) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(Color.hibixSubNavy)
        } extra: {
            VStack(spacing: 12) {
                ForEach(WatchMode.allCases) { mode in
                    Button {
                        onSelectMode(mode)
                    } label: {
                        HStack(spacing: 8) {
                            Text(mode.displayName)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.hibixNavy)
                            if mode.requiresPro {
                                Text("Pro")
                                    .font(.caption2)
                                    .fontWeight(.heavy)
                                    .foregroundStyle(Color.hibixAccentPink)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .hibixRoundButton(cornerRadius: 25)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode.requiresPro ? "\(mode.displayName)、Pro" : mode.displayName)
                }
            }
        }
    }
}

// MARK: - Illustrations / parts

/// 角丸タイルのピクセルカレンダー風プレビュー（非操作）。
private struct PixelPreviewIllustration: View {
    let filledDays: Int
    let columns: Int
    let rows: Int

    private var palette: [Color] { MoodLevel.allCases.map { Color.moodColor(for: $0) } }

    var body: some View {
        let cell: CGFloat = columns >= 10 ? 12 : 22
        VStack(spacing: 3) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        let filled = (index * 7 + 3) % 11 < 8 && index < filledDays
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(filled ? palette[(index * 3) % palette.count] : Color.hibixCellBase.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .strokeBorder(Color.hibixCellBorder, lineWidth: 1)
                            )
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
    }
}

private struct ModeInfoCard: View {
    let title: String
    let detail: String
    let isPro: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.hibixNavy)
                    if isPro {
                        Text("Pro")
                            .font(.caption2)
                            .fontWeight(.heavy)
                            .foregroundStyle(Color.hibixAccentPink)
                    }
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.hibixSubText)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .hibixGlassCard(cornerRadius: 18)
    }
}

private struct WatchFlowStep: View {
    let text: String
    var systemImage: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(Color.hibixAccentPink)
            }
            Text(text)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.hibixNavy)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .hibixGlassCard(cornerRadius: 14)
    }
}

private struct ProCompareTable: View {
    private struct Row: Identifiable { let id = UUID(); let label: String; let free: String; let pro: String }
    private let rows = [
        Row(label: "基本記録", free: "✓", pro: "✓"),
        Row(label: "見守り", free: "一部", pro: "全解放"),
        Row(label: "高度な管理", free: "−", pro: "✓")
    ]
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                Text("無料").frame(width: 64)
                Text("Pro").frame(width: 64)
            }
            .font(.caption).fontWeight(.heavy).foregroundStyle(Color.hibixSubNavy)
            .padding(.vertical, 6)
            ForEach(rows) { row in
                Divider().overlay(Color.hibixHairline)
                HStack {
                    Text(row.label).frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.free).frame(width: 64)
                    Text(row.pro).frame(width: 64)
                }
                .font(.caption).fontWeight(.medium).foregroundStyle(Color.hibixNavy)
                .padding(.vertical, 7)
            }
        }
        .padding(.horizontal, 14)
        .hibixGlassCard(cornerRadius: 18)
    }
}
