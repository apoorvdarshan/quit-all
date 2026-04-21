import Foundation
import CoreData

// MARK: - Pattern Detector
// Analyzes craving history to find patterns in timing, triggers, and trends.
@Observable
final class PatternDetector {
    static let shared = PatternDetector()
    private init() {}

    struct Patterns {
        var peakCravingHour: Int?
        var peakCravingDay: Int?      // 0 = Sunday
        var topTrigger: String?
        var cravingTrend: Trend?      // increasing, decreasing, stable
        var averageCravingsPerDay: Double?
        var survivalRate: Double?
        var hourlyHeatmap: [Int: Int] = [:]  // hour -> count
        var weekdayHeatmap: [Int: Int] = [:]  // day -> count
        var triggerBreakdown: [String: Int] = [:]
        var dangerZoneDescription: String?
        var insights: [String] = []
    }

    enum Trend: String {
        case increasing = "increasing"
        case decreasing = "decreasing"
        case stable = "stable"
    }

    func analyzePatterns(for addictionType: AddictionType, context: NSManagedObjectContext) async -> Patterns {
        await context.perform {
            var patterns = Patterns()

            let request: NSFetchRequest<CDCravingEvent> = CDCravingEvent.fetchRequest()
            request.predicate = NSPredicate(format: "addiction.type == %@", addictionType.rawValue)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \CDCravingEvent.timestamp, ascending: true)]

            guard let cravings = try? context.fetch(request), !cravings.isEmpty else {
                return patterns
            }

            // Hourly heatmap
            var hourCounts: [Int: Int] = [:]
            var dayCounts: [Int: Int] = [:]
            var triggerCounts: [String: Int] = [:]
            var survivedCount = 0

            for craving in cravings {
                guard let timestamp = craving.timestamp else { continue }

                let hour = Calendar.current.component(.hour, from: timestamp)
                let weekday = Calendar.current.component(.weekday, from: timestamp) - 1

                hourCounts[hour, default: 0] += 1
                dayCounts[weekday, default: 0] += 1

                if let trigger = craving.trigger {
                    triggerCounts[trigger, default: 0] += 1
                }

                if craving.survived {
                    survivedCount += 1
                }
            }

            patterns.hourlyHeatmap = hourCounts
            patterns.weekdayHeatmap = dayCounts
            patterns.triggerBreakdown = triggerCounts
            patterns.peakCravingHour = hourCounts.max(by: { $0.value < $1.value })?.key
            patterns.peakCravingDay = dayCounts.max(by: { $0.value < $1.value })?.key
            patterns.topTrigger = triggerCounts.max(by: { $0.value < $1.value })?.key
            patterns.survivalRate = Double(survivedCount) / Double(cravings.count)

            // Calculate trend (compare last 7 days to previous 7 days)
            let now = Date()
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
            let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: now)!

            let recentCravings = cravings.filter { ($0.timestamp ?? .distantPast) >= sevenDaysAgo }
            let previousCravings = cravings.filter {
                let ts = $0.timestamp ?? .distantPast
                return ts >= fourteenDaysAgo && ts < sevenDaysAgo
            }

            if !previousCravings.isEmpty {
                let recentRate = Double(recentCravings.count) / 7.0
                let previousRate = Double(previousCravings.count) / 7.0

                if recentRate < previousRate * 0.7 {
                    patterns.cravingTrend = .decreasing
                } else if recentRate > previousRate * 1.3 {
                    patterns.cravingTrend = .increasing
                } else {
                    patterns.cravingTrend = .stable
                }
            }

            // Average per day
            if let first = cravings.first?.timestamp {
                let totalDays = max(1, Calendar.current.dateComponents([.day], from: first, to: now).day ?? 1)
                patterns.averageCravingsPerDay = Double(cravings.count) / Double(totalDays)
            }

            // Build insights
            patterns.insights = self.buildInsights(from: patterns, cravingCount: cravings.count)

            // Danger zone description
            if let hour = patterns.peakCravingHour, let day = patterns.peakCravingDay {
                let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                let formatter = DateFormatter()
                formatter.dateFormat = "ha"
                let hourStr = self.formatHour(hour)
                patterns.dangerZoneDescription = "\(dayNames[day]) \(hourStr)"
            }

            return patterns
        }
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12AM" }
        if hour < 12 { return "\(hour)AM" }
        if hour == 12 { return "12PM" }
        return "\(hour - 12)PM"
    }

    private func buildInsights(from patterns: Patterns, cravingCount: Int) -> [String] {
        var insights: [String] = []
        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

        if let hour = patterns.peakCravingHour {
            insights.append("You crave most at \(formatHour(hour))")
        }

        if let day = patterns.peakCravingDay {
            insights.append("Your danger zone: \(dayNames[day]) evenings")
        }

        if let trigger = patterns.topTrigger, let count = patterns.triggerBreakdown[trigger] {
            let percentage = Int(Double(count) / Double(cravingCount) * 100)
            insights.append("\(trigger) triggers \(percentage)% of your cravings")
        }

        if let trend = patterns.cravingTrend {
            switch trend {
            case .decreasing:
                insights.append("Your cravings are decreasing week over week")
            case .increasing:
                insights.append("Cravings have increased this week — stay vigilant")
            case .stable:
                insights.append("Your craving frequency is holding steady")
            }
        }

        if let rate = patterns.survivalRate, rate > 0.5 {
            insights.append("You've survived \(Int(rate * 100))% of all cravings")
        }

        return insights
    }
}
