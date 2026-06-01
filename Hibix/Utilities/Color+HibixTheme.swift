import SwiftUI
import UIKit

// MARK: - Dynamic Color Helpers

private extension UIColor {
    convenience init(hibixRGB hex: UInt32, alpha: CGFloat) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

/// ライト/ダークで自動的に解決する動的カラーを生成する。
/// 外観モード(`colorScheme`)に追従するため、各Viewで分岐せずに済む。
private func hibixDynamic(light: UInt32,
                          dark: UInt32,
                          lightAlpha: CGFloat = 1.0,
                          darkAlpha: CGFloat = 1.0) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hibixRGB: dark, alpha: darkAlpha)
            : UIColor(hibixRGB: light, alpha: lightAlpha)
    })
}

// MARK: - Watercolor Theme Palette

/// 朝焼けの空・水彩テイスト用カラー定義。
/// ライト: キービジュアルの「白〜水色〜クリーム」。
/// ダーク: 「紺の夜空」。文字は明るいラベンダー/オフホワイト、アクセントは共通。
/// 気分カラー(`Color.moodColor`)はブランドガイド §6 確定値のまま据え置く。
extension Color {
    /// 背景グラデーション上部
    static var hibixBgTop: Color { hibixDynamic(light: 0xDFF3FF, dark: 0x131A2E) }
    /// 背景グラデーション中央
    static var hibixBgMid: Color { hibixDynamic(light: 0xFFF9EC, dark: 0x182039) }
    /// 背景グラデーション下部
    static var hibixBgBottom: Color { hibixDynamic(light: 0xF7FAFF, dark: 0x0F1526) }

    /// メインネイビー(タイトル・主要文字)。ダークはオフホワイト。
    static var hibixNavy: Color { hibixDynamic(light: 0x1F4B8F, dark: 0xE6ECFA) }
    /// サブネイビー(アイコン等)。ダークは淡い青。
    static var hibixSubNavy: Color { hibixDynamic(light: 0x3F63A8, dark: 0x9FB4E0) }

    /// 日付・月ラベル用ラベンダー。
    static var hibixPeriwinkle: Color { hibixDynamic(light: 0x9A9FE5, dark: 0xA9B0EE) }
    /// ラベンダー
    static var hibixLavender: Color { hibixDynamic(light: 0xEDEBFF, dark: 0x2A3450) }
    /// 薄ラベンダー
    static var hibixLavenderLight: Color { hibixDynamic(light: 0xF5F3FF, dark: 0x222C46) }

    /// カレンダー空セル背景
    static var hibixCellBase: Color { hibixDynamic(light: 0xF2F3FF, dark: 0x222C46) }
    /// セルの縁取り(白半透明 / ダークは淡い白)
    static var hibixCellBorder: Color { hibixDynamic(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.8, darkAlpha: 0.10) }
    /// 罫線
    static var hibixHairline: Color { hibixDynamic(light: 0xDDE6F5, dark: 0x2E3A57) }
    /// 補助テキスト
    static var hibixSubText: Color { hibixDynamic(light: 0x8A93A5, dark: 0x9AA3B8) }
    /// 文字数カウント用
    static var hibixCounterText: Color { hibixDynamic(light: 0x6F83AA, dark: 0x98A6C8) }
    /// プレースホルダー用
    static var hibixPlaceholder: Color { hibixDynamic(light: 0xA8B2C5, dark: 0x6E7890) }

    /// アクセントピンク(コーラル) — 共通
    static var hibixAccentPink: Color { Color(uiColor: UIColor(hibixRGB: 0xFFA3AF, alpha: 1.0)) }
    /// アクセントブルー — 共通
    static var hibixAccentBlue: Color { Color(uiColor: UIColor(hibixRGB: 0x78B5FF, alpha: 1.0)) }

    // カード/ボタン装飾用
    static var hibixCardTop: Color { hibixDynamic(light: 0xFFFFFF, dark: 0x2A3450) }
    static var hibixCardMid: Color { hibixDynamic(light: 0xF4F7FF, dark: 0x222C46) }
    static var hibixCardWarm: Color { hibixDynamic(light: 0xFFF8EC, dark: 0x262A40) }
    static var hibixCardBorder: Color { hibixDynamic(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.75, darkAlpha: 0.10) }
    static var hibixCardShadow: Color { hibixDynamic(light: 0xAFC4DA, dark: 0x000000, lightAlpha: 0.14, darkAlpha: 0.30) }
    static var hibixButtonFill: Color { hibixDynamic(light: 0xFFFFFF, dark: 0x2A3450, lightAlpha: 0.72, darkAlpha: 0.55) }
    static var hibixButtonShadow: Color { hibixDynamic(light: 0xB7C9DF, dark: 0x000000, lightAlpha: 0.20, darkAlpha: 0.35) }
    /// 背景の水彩ぼかし円(ライト=白 / ダーク=淡い月光ブルー)
    static var hibixGlow: Color { hibixDynamic(light: 0xFFFFFF, dark: 0x3A4E86) }
}

// MARK: - Watercolor Background

/// 画面全体に敷く朝焼け水彩(ダークは紺の夜空)グラデーション背景。
/// ごく薄いぼかし円を重ね、水彩感を出す。
struct HibixWatercolorBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .hibixBgTop, location: 0.0),
                .init(color: .hibixBgMid, location: 0.45),
                .init(color: .hibixBgBottom, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.hibixGlow.opacity(0.35))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: 60, y: -40)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color.hibixGlow.opacity(0.28))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: -70, y: 60)
        }
    }
}

// MARK: - Reusable Style Modifiers

private struct HibixGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    stops: [
                        .init(color: Color.hibixCardTop, location: 0.0),
                        .init(color: Color.hibixCardMid, location: 0.5),
                        .init(color: Color.hibixCardWarm, location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.70)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.hibixCardBorder, lineWidth: 1)
            )
            .shadow(color: Color.hibixCardShadow, radius: 18, x: 0, y: 10)
    }
}

private struct HibixRoundButtonModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.hibixButtonFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.hibixCardBorder, lineWidth: 1)
            )
            .shadow(color: Color.hibixButtonShadow, radius: 22, x: 0, y: 8)
    }
}

extension View {
    /// 朝焼け水彩(ダークは紺の夜空)グラデーションを背景に敷く(セーフエリア含む)。
    func hibixWatercolorBackground() -> some View {
        background(HibixWatercolorBackground().ignoresSafeArea())
    }

    /// 大きな角丸ガラスカード装飾。
    func hibixGlassCard(cornerRadius: CGFloat = 28) -> some View {
        modifier(HibixGlassCardModifier(cornerRadius: cornerRadius))
    }

    /// 白半透明(ダークは紺半透明)の丸ボタン/ピル装飾。
    func hibixRoundButton(cornerRadius: CGFloat = 32) -> some View {
        modifier(HibixRoundButtonModifier(cornerRadius: cornerRadius))
    }
}
