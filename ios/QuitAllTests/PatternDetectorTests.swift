import CoreData
import XCTest
@testable import Quit_All

/// Cravings 1-6 days back count as "this week", 8-13 days back as "last week".
final class PatternDetectorTests: QuitAllTestCase {
    private let detector = PatternDetector.shared
    private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    func testNoCravingsMeansNoPatterns() async {
        let context = makeContext()
        makeAddiction(startDate: ago(days: 5), in: context)

        let patterns = await detector.analyzePatterns(for: .smoking, context: context)

        XCTAssertNil(patterns.peakCravingHour)
        XCTAssertNil(patterns.topTrigger)
        XCTAssertNil(patterns.survivalRate)
        XCTAssertNil(patterns.cravingTrend)
        XCTAssertNil(patterns.dangerZoneDescription)
        XCTAssertTrue(patterns.insights.isEmpty)
    }

    func testFindsPeakHourTopTriggerAndSurvivalRate() async throws {
        let context = makeContext()
        let now = Date()
        let habit = makeAddiction(startDate: ago(days: 30, from: now), in: context)
        let recent = day(2, hour: 21, from: now)
        addCraving(to: habit, at: recent, trigger: .stress, in: context)
        addCraving(to: habit, at: day(9, hour: 21, from: now), trigger: .stress, in: context)
        addCraving(to: habit, at: day(10, hour: 21, from: now), trigger: .stress, in: context)
        addCraving(to: habit, at: day(11, hour: 8, from: now), trigger: .boredom, survived: false, in: context)
        try context.save()

        let patterns = await detector.analyzePatterns(for: .smoking, context: context)

        // Two of the 9 PM cravings are exactly a week apart, so they share a weekday.
        let peakDay = Calendar.current.component(.weekday, from: recent) - 1
        XCTAssertEqual(patterns.peakCravingHour, 21)
        XCTAssertEqual(patterns.peakCravingDay, peakDay)
        XCTAssertEqual(patterns.hourlyHeatmap, [21: 3, 8: 1])
        XCTAssertEqual(patterns.triggerBreakdown, ["Stress": 3, "Boredom": 1])
        XCTAssertEqual(patterns.topTrigger, "Stress")
        XCTAssertEqual(try XCTUnwrap(patterns.survivalRate), 0.75, accuracy: 0.0001)
        XCTAssertEqual(patterns.cravingTrend, .decreasing)
        XCTAssertEqual(patterns.dangerZoneDescription, "\(dayNames[peakDay]) 9PM")
        let average = try XCTUnwrap(patterns.averageCravingsPerDay)
        XCTAssertTrue((4.0 / 11.0)...(4.0 / 10.0) ~= average, "average \(average)")
        XCTAssertEqual(patterns.insights, [
            "You crave most at 9PM",
            "Your danger zone: \(dayNames[peakDay]) evenings",
            "Stress triggers 75% of your cravings",
            "Your cravings are decreasing week over week",
            "You've survived 75% of all cravings",
        ])
    }

    func testTrendComparesThisWeekWithLastWeek() async throws {
        let increasing = try await trend(thisWeek: 3, lastWeek: 1)
        XCTAssertEqual(increasing.cravingTrend, .increasing)
        XCTAssertTrue(increasing.insights.contains("Cravings have increased this week — stay vigilant"))

        let stable = try await trend(thisWeek: 2, lastWeek: 2)
        XCTAssertEqual(stable.cravingTrend, .stable)
        XCTAssertTrue(stable.insights.contains("Your craving frequency is holding steady"))

        let noHistory = try await trend(thisWeek: 3, lastWeek: 0)
        XCTAssertNil(noHistory.cravingTrend, "a trend needs last week's data")
    }

    func testLowSurvivalRateIsNotCelebrated() async throws {
        let context = makeContext()
        let now = Date()
        let habit = makeAddiction(startDate: ago(days: 30, from: now), in: context)
        addCraving(to: habit, at: day(1, hour: 10, from: now), survived: true, in: context)
        addCraving(to: habit, at: day(2, hour: 10, from: now), survived: false, in: context)
        addCraving(to: habit, at: day(3, hour: 10, from: now), survived: false, in: context)
        try context.save()

        let patterns = await detector.analyzePatterns(for: .smoking, context: context)

        XCTAssertEqual(try XCTUnwrap(patterns.survivalRate), 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertFalse(patterns.insights.contains { $0.hasPrefix("You've survived") })
    }

    func testHoursAreShownOnATwelveHourClock() async throws {
        let midnight = try await peakHourInsight(hour: 0)
        XCTAssertEqual(midnight, "You crave most at 12AM")
        let noon = try await peakHourInsight(hour: 12)
        XCTAssertEqual(noon, "You crave most at 12PM")
        let morning = try await peakHourInsight(hour: 7)
        XCTAssertEqual(morning, "You crave most at 7AM")
    }

    func testOnlyTheRequestedHabitIsAnalyzed() async throws {
        let context = makeContext()
        let now = Date()
        let smoking = makeAddiction(startDate: ago(days: 30, from: now), in: context)
        let caffeine = makeAddiction(.caffeine, startDate: ago(days: 30, from: now), in: context)
        addCraving(to: smoking, at: day(1, hour: 22, from: now), trigger: .stress, in: context)
        addCraving(to: smoking, at: day(2, hour: 22, from: now), trigger: .stress, in: context)
        addCraving(to: caffeine, at: day(1, hour: 7, from: now), trigger: .habit, in: context)
        try context.save()

        let patterns = await detector.analyzePatterns(for: .caffeine, context: context)

        XCTAssertEqual(patterns.hourlyHeatmap, [7: 1])
        XCTAssertEqual(patterns.topTrigger, "Habit/Routine")
    }

    private func trend(thisWeek: Int, lastWeek: Int) async throws -> PatternDetector.Patterns {
        let context = makeContext()
        let now = Date()
        let habit = makeAddiction(startDate: ago(days: 30, from: now), in: context)
        for index in 0..<thisWeek {
            addCraving(to: habit, at: day(1 + index, hour: 12, from: now), in: context)
        }
        for index in 0..<lastWeek {
            addCraving(to: habit, at: day(8 + index, hour: 12, from: now), in: context)
        }
        try context.save()
        return await detector.analyzePatterns(for: .smoking, context: context)
    }

    private func peakHourInsight(hour: Int) async throws -> String? {
        let context = makeContext()
        let now = Date()
        let habit = makeAddiction(startDate: ago(days: 30, from: now), in: context)
        addCraving(to: habit, at: day(2, hour: hour, from: now), in: context)
        try context.save()
        return await detector.analyzePatterns(for: .smoking, context: context).insights.first
    }
}

final class RelapseAnalyzerTests: QuitAllTestCase {
    private let analyzer = RelapseAnalyzer.shared

    func testNoRelapsesMeansEmptyInsights() async {
        let context = makeContext()
        makeAddiction(startDate: ago(days: 5), in: context)

        let insights = await analyzer.analyze(for: .smoking, context: context)

        XCTAssertEqual(insights.totalRelapses, 0)
        XCTAssertEqual(insights.longestStreakEver, 0)
        XCTAssertNil(insights.commonRelapseDay)
        XCTAssertNil(insights.mostCommonActivity)
        XCTAssertFalse(insights.streaksGettingLonger)
    }

    func testSummarizesRelapseHistory() async throws {
        let context = makeContext()
        let now = Date()
        let habit = makeAddiction(startDate: ago(days: 1, from: now), in: context)
        // Same weekday each time: 21, 14 and 7 days back.
        let first = day(21, hour: 20, from: now)
        addRelapse(to: habit, at: first, streakBroken: 2, activity: .bored, in: context)
        addRelapse(to: habit, at: day(14, hour: 20, from: now), streakBroken: 5, activity: .party, in: context)
        addRelapse(to: habit, at: day(7, hour: 20, from: now), streakBroken: 9, activity: .bored, in: context)
        try context.save()

        let insights = await analyzer.analyze(for: .smoking, context: context)

        let weekday = Calendar.current.component(.weekday, from: first) - 1
        XCTAssertEqual(insights.totalRelapses, 3)
        XCTAssertEqual(insights.averageStreakBeforeRelapse, 16.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(insights.longestStreakEver, 9)
        XCTAssertTrue(insights.streaksGettingLonger)
        XCTAssertEqual(insights.mostCommonActivity, "Just bored")
        XCTAssertEqual(insights.commonRelapseDay, ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][weekday])
    }

    func testShrinkingStreaksAreNotReportedAsProgress() async throws {
        let context = makeContext()
        let now = Date()
        let habit = makeAddiction(startDate: ago(days: 1, from: now), in: context)
        addRelapse(to: habit, at: day(20, hour: 9, from: now), streakBroken: 9, in: context)
        addRelapse(to: habit, at: day(10, hour: 9, from: now), streakBroken: 5, in: context)
        addRelapse(to: habit, at: day(3, hour: 9, from: now), streakBroken: 2, in: context)
        try context.save()

        let insights = await analyzer.analyze(for: .smoking, context: context)

        XCTAssertEqual(insights.totalRelapses, 3)
        XCTAssertFalse(insights.streaksGettingLonger)
    }
}
