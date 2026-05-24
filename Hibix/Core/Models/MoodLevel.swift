import Foundation

nonisolated enum MoodLevel: Int, CaseIterable, Sendable {
    case down = 1
    case calm = 3
    case neutral = 4
    case good = 5
    case best = 7

    var displayName: String {
        switch self {
        case .down:    return "落ち込み"
        case .calm:    return "平静"
        case .neutral: return "普通"
        case .good:    return "良い"
        case .best:    return "最高"
        }
    }

    var accessibilityLabel: String {
        "気分\(rawValue)、\(displayName)"
    }

    var iconName: String {
        switch self {
        case .down:    return "cloud.rain.fill"
        case .calm:    return "cloud.fill"
        case .neutral: return "circle.fill"
        case .good:    return "sun.max.fill"
        case .best:    return "sparkles"
        }
    }

    /// DBに保存された rawValue から MoodLevel を復元する。
    /// 旧 sink(2) は down(1) に、旧 uplift(6) は good(5) にマイグレーションする。
    static func fromStoredValue(_ rawValue: Int) -> MoodLevel? {
        switch rawValue {
        case 1, 2: return .down
        case 3:    return .calm
        case 4:    return .neutral
        case 5, 6: return .good
        case 7:    return .best
        default:   return nil
        }
    }
}
