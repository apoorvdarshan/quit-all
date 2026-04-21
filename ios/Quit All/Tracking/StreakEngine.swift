import Foundation

// MARK: - Streak Engine
// Handles streak calculations, formatting, and progress ring values.
struct StreakEngine {

    // Calculate days clean
    static func daysSince(_ date: Date?) -> Int {
        guard let date = date else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0)
    }

    // Calculate hours clean
    static func hoursSince(_ date: Date?) -> Int {
        guard let date = date else { return 0 }
        return max(0, Calendar.current.dateComponents([.hour], from: date, to: Date()).hour ?? 0)
    }

    // Calculate minutes clean
    static func minutesSince(_ date: Date?) -> Int {
        guard let date = date else { return 0 }
        return max(0, Calendar.current.dateComponents([.minute], from: date, to: Date()).minute ?? 0)
    }

    // Progress toward next milestone (0.0 to 1.0)
    static func progressToNextMilestone(startDate: Date?) -> (progress: Double, nextMilestone: MilestoneDefinition?) {
        let hours = hoursSince(startDate)
        let milestones = MilestoneLibrary.milestones

        // Find current and next milestone
        var previousHours = 0
        for milestone in milestones {
            if hours < milestone.requiredHours {
                let range = milestone.requiredHours - previousHours
                let elapsed = hours - previousHours
                let progress = min(1.0, Double(elapsed) / Double(range))
                return (progress, milestone)
            }
            previousHours = milestone.requiredHours
        }

        // Past all milestones
        return (1.0, nil)
    }

    // Format streak display — shows the most relevant unit
    static func formatStreak(startDate: Date?) -> (value: String, unit: String) {
        let days = daysSince(startDate)
        let hours = hoursSince(startDate)

        if days == 0 {
            if hours == 0 {
                let minutes = minutesSince(startDate)
                return ("\(minutes)", minutes == 1 ? "minute" : "minutes")
            }
            return ("\(hours)", hours == 1 ? "hour" : "hours")
        }
        return ("\(days)", days == 1 ? "day" : "days")
    }

    // Get unlocked milestones
    static func unlockedMilestones(startDate: Date?) -> [MilestoneDefinition] {
        let hours = hoursSince(startDate)
        return MilestoneLibrary.milestones.filter { $0.requiredHours <= hours }
    }

    // Check for newly unlocked milestone
    static func checkNewMilestone(startDate: Date?, existingMilestones: Set<String>) -> MilestoneDefinition? {
        let hours = hoursSince(startDate)
        for milestone in MilestoneLibrary.milestones {
            if hours >= milestone.requiredHours && !existingMilestones.contains(milestone.type.rawValue) {
                return milestone
            }
        }
        return nil
    }
}
