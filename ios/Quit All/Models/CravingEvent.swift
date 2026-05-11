import Foundation

// MARK: - Craving Trigger
enum CravingTrigger: String, CaseIterable, Codable {
    case stress = "Stress"
    case boredom = "Boredom"
    case social = "Social situation"
    case saw = "Saw something"
    case habit = "Habit/Routine"
    case emotional = "Emotional"
    case other = "Other"

    var localizedName: String {
        NSLocalizedString(rawValue, comment: "")
    }

    var emoji: String {
        switch self {
        case .stress: return "😰"
        case .boredom: return "😐"
        case .social: return "👥"
        case .saw: return "👀"
        case .habit: return "🔄"
        case .emotional: return "💔"
        case .other: return "❓"
        }
    }
}

// MARK: - Mood
enum Mood: String, CaseIterable, Codable {
    case great = "Great"
    case good = "Good"
    case okay = "Okay"
    case bad = "Bad"
    case terrible = "Terrible"

    var localizedName: String {
        NSLocalizedString(rawValue, comment: "")
    }

    var emoji: String {
        switch self {
        case .great: return "😄"
        case .good: return "🙂"
        case .okay: return "😐"
        case .bad: return "😞"
        case .terrible: return "😢"
        }
    }
}
