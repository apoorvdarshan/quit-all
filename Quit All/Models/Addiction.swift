import Foundation
import SwiftUI

// MARK: - Addiction Type Enum
enum AddictionType: String, CaseIterable, Codable, Identifiable {
    case smoking = "Smoking"
    case vaping = "Vaping"
    case alcohol = "Alcohol"
    case porn = "Porn"
    case socialMedia = "Social Media"
    case weed = "Weed"
    case gambling = "Gambling"
    case overspending = "Overspending"
    case caffeine = "Caffeine"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .smoking: return "🚬"
        case .vaping: return "💨"
        case .alcohol: return "🍺"
        case .porn: return "🔞"
        case .socialMedia: return "📱"
        case .weed: return "🌿"
        case .gambling: return "🎰"
        case .overspending: return "💸"
        case .caffeine: return "☕"
        }
    }

    var color: Color {
        switch self {
        case .smoking, .vaping: return Color(hex: "607D8B")
        case .alcohol: return Color(hex: "FF8F00")
        case .porn: return Color(hex: "7B1FA2")
        case .socialMedia: return Color(hex: "1565C0")
        case .weed: return Color(hex: "2E7D32")
        case .gambling: return Color(hex: "C62828")
        case .overspending: return Color(hex: "F9A825")
        case .caffeine: return Color(hex: "4E342E")
        }
    }

    // Minutes of life lost per unit
    var minutesPerUnit: Double {
        switch self {
        case .smoking: return 11.0
        case .vaping: return 5.0
        case .alcohol: return 15.0
        default: return 0.0
        }
    }

    var unitName: String {
        switch self {
        case .smoking: return "cigarette"
        case .vaping: return "session"
        case .alcohol: return "drink"
        case .caffeine: return "cup"
        default: return "time"
        }
    }

    var defaultDailyUnits: Double {
        switch self {
        case .smoking: return 10.0
        case .vaping: return 8.0
        case .alcohol: return 3.0
        default: return 1.0
        }
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
