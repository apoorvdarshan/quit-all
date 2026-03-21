import Foundation
import CoreData

// MARK: - Relapse Analyzer
// Analyzes relapse history to identify patterns and risk factors.
@Observable
final class RelapseAnalyzer {
    static let shared = RelapseAnalyzer()
    private init() {}

    struct RelapseInsights {
        var totalRelapses: Int = 0
        var averageStreakBeforeRelapse: Double = 0
        var longestStreakEver: Int = 0
        var commonRelapseDay: String?
        var commonRelapseTime: String?
        var mostCommonActivity: String?
        var streaksGettingLonger: Bool = false
    }

    func analyze(for addictionType: AddictionType, context: NSManagedObjectContext) async -> RelapseInsights {
        await context.perform {
            var insights = RelapseInsights()

            let request: NSFetchRequest<CDRelapseEvent> = CDRelapseEvent.fetchRequest()
            request.predicate = NSPredicate(format: "addiction.type == %@", addictionType.rawValue)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \CDRelapseEvent.timestamp, ascending: true)]

            guard let relapses = try? context.fetch(request), !relapses.isEmpty else {
                return insights
            }

            insights.totalRelapses = relapses.count

            // Average streak before relapse
            let streaks = relapses.map { Int($0.streakBroken) }
            insights.averageStreakBeforeRelapse = Double(streaks.reduce(0, +)) / Double(streaks.count)
            insights.longestStreakEver = streaks.max() ?? 0

            // Check if streaks are getting longer (positive trend)
            if streaks.count >= 3 {
                let firstHalf = Array(streaks.prefix(streaks.count / 2))
                let secondHalf = Array(streaks.suffix(streaks.count / 2))
                let firstAvg = Double(firstHalf.reduce(0, +)) / Double(firstHalf.count)
                let secondAvg = Double(secondHalf.reduce(0, +)) / Double(secondHalf.count)
                insights.streaksGettingLonger = secondAvg > firstAvg
            }

            // Common relapse day/time
            let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            var dayCounts: [Int: Int] = [:]
            var activityCounts: [String: Int] = [:]

            for relapse in relapses {
                if let timestamp = relapse.timestamp {
                    let weekday = Calendar.current.component(.weekday, from: timestamp) - 1
                    dayCounts[weekday, default: 0] += 1
                }
                if let activity = relapse.whatHappened, !activity.isEmpty {
                    activityCounts[activity, default: 0] += 1
                }
            }

            if let topDay = dayCounts.max(by: { $0.value < $1.value })?.key {
                insights.commonRelapseDay = dayNames[topDay]
            }

            insights.mostCommonActivity = activityCounts.max(by: { $0.value < $1.value })?.key

            return insights
        }
    }
}
