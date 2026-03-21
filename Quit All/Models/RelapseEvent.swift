import Foundation

// MARK: - Relapse Activity Options
enum RelapseActivity: String, CaseIterable, Codable {
    case drinking = "Drinking with friends"
    case party = "At a party"
    case alone = "Home alone"
    case stressed = "Stressed at work"
    case argued = "After an argument"
    case bored = "Just bored"
    case celebrating = "Celebrating something"
    case sad = "Feeling sad"
    case other = "Something else"

    var emoji: String {
        switch self {
        case .drinking: return "🍻"
        case .party: return "🎉"
        case .alone: return "🏠"
        case .stressed: return "💼"
        case .argued: return "😤"
        case .bored: return "😐"
        case .celebrating: return "🥳"
        case .sad: return "😢"
        case .other: return "📝"
        }
    }
}
