import SwiftUI

extension Color {
    /// Hibix Mood Colors (ブランドガイド v1.0 §6 確定値)
    static func moodColor(for level: MoodLevel) -> Color {
        switch level {
        case .down:    return Color(moodHex: 0x86ADE5) // スカイブルー
        case .calm:    return Color(moodHex: 0x9BCCB5) // ミントセージ
        case .neutral: return Color(moodHex: 0xFECE7C) // ゴールデンクリーム
        case .good:    return Color(moodHex: 0xFEB478) // サンセットオレンジ
        case .best:    return Color(moodHex: 0xFEACA5) // コーラルピンク
        }
    }

    /// Brand primary (ロゴ「H」・主要UI) — スカイブルー
    static var brandPrimary: Color { Color(moodHex: 0x86ADE5) }
    /// Brand secondary (ロゴのハート・CTA) — コーラルピンク
    static var brandSecondary: Color { Color(moodHex: 0xFEACA5) }

    static var moodEmptyCell: Color { Color(moodHex: 0xE5E7EB) }

    fileprivate init(moodHex hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
