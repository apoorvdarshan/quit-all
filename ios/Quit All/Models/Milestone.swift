import Foundation

// MARK: - Milestone Definition
struct MilestoneDefinition: Identifiable {
    let id = UUID()
    let type: MilestoneType
    let title: String
    let subtitle: String
    let healthFact: String
    let requiredHours: Int

    var requiredDays: Double {
        Double(requiredHours) / 24.0
    }
}

enum MilestoneType: String, CaseIterable, Codable {
    case oneHour = "1_hour"
    case twentyFourHours = "24_hours"
    case threeDays = "3_days"
    case oneWeek = "1_week"
    case twoWeeks = "2_weeks"
    case thirtyDays = "30_days"
    case hundredDays = "100_days"
    case sixMonths = "6_months"
    case oneYear = "1_year"

    var hours: Int {
        switch self {
        case .oneHour: return 1
        case .twentyFourHours: return 24
        case .threeDays: return 72
        case .oneWeek: return 168
        case .twoWeeks: return 336
        case .thirtyDays: return 720
        case .hundredDays: return 2400
        case .sixMonths: return 4380
        case .oneYear: return 8760
        }
    }

    var displayName: String {
        switch self {
        case .oneHour: return "1 Hour"
        case .twentyFourHours: return "24 Hours"
        case .threeDays: return "3 Days"
        case .oneWeek: return "1 Week"
        case .twoWeeks: return "2 Weeks"
        case .thirtyDays: return "30 Days"
        case .hundredDays: return "100 Days"
        case .sixMonths: return "6 Months"
        case .oneYear: return "1 Year"
        }
    }
}

// MARK: - All Milestones
struct MilestoneLibrary {
    static let milestones: [MilestoneDefinition] = [
        MilestoneDefinition(
            type: .oneHour,
            title: "The hardest hour",
            subtitle: "You survived the first 60 minutes",
            healthFact: "Your heart rate and blood pressure have already started to drop back to normal levels.",
            requiredHours: 1
        ),
        MilestoneDefinition(
            type: .twentyFourHours,
            title: "First day done",
            subtitle: "24 hours of freedom",
            healthFact: "At 24 hours: carbon monoxide levels in your blood have dropped to normal. Your body is already healing.",
            requiredHours: 24
        ),
        MilestoneDefinition(
            type: .threeDays,
            title: "Withdrawal peaks here — you beat it",
            subtitle: "The worst is behind you",
            healthFact: "At 48-72 hours: nicotine is completely gone from your blood. Nerve endings begin regrowing. Your sense of taste and smell sharpen.",
            requiredHours: 72
        ),
        MilestoneDefinition(
            type: .oneWeek,
            title: "One full week",
            subtitle: "7 days of proving yourself",
            healthFact: "At 1 week: the worst physical withdrawal symptoms have passed. Your lungs are beginning to clear.",
            requiredHours: 168
        ),
        MilestoneDefinition(
            type: .twoWeeks,
            title: "Your brain is rewiring right now",
            subtitle: "Neural pathways are changing",
            healthFact: "At 2 weeks: circulation improves and lung function increases. Walking becomes easier. Brain dopamine receptors begin normalizing.",
            requiredHours: 336
        ),
        MilestoneDefinition(
            type: .thirtyDays,
            title: "One month — habit officially broken",
            subtitle: "30 days of a new you",
            healthFact: "At 30 days: the addiction pathways in your brain have significantly weakened. Your energy levels and immune system have improved.",
            requiredHours: 720
        ),
        MilestoneDefinition(
            type: .hundredDays,
            title: "Triple digits",
            subtitle: "100 days of freedom",
            healthFact: "At 100 days: your brain has substantially rewired. Cravings are now rare and manageable. You've built real, lasting change.",
            requiredHours: 2400
        ),
        MilestoneDefinition(
            type: .sixMonths,
            title: "Half a year",
            subtitle: "6 months of strength",
            healthFact: "At 6 months: lung cilia have regrown. Your body's ability to fight infection has dramatically improved. Stress levels are lower than when you were using.",
            requiredHours: 4380
        ),
        MilestoneDefinition(
            type: .oneYear,
            title: "You changed your life",
            subtitle: "365 days of transformation",
            healthFact: "At 1 year: your risk of heart disease has dropped by 50%. Your brain has fully rewired. You are no longer the same person.",
            requiredHours: 8760
        )
    ]
}
