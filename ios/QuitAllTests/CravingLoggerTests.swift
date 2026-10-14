import CoreData
import XCTest
@testable import Quit_All

final class CravingLoggerTests: QuitAllTestCase {
    private let logger = CravingLogger.shared

    func testLoggingACravingSavesTheCheckIn() throws {
        let context = makeContext()
        let habit = makeAddiction(startDate: ago(days: 3), in: context)

        logger.logCraving(
            addiction: habit, trigger: .social, survived: true, duration: 185,
            moodBefore: .bad, moodAfter: .good, context: context
        )

        XCTAssertFalse(context.hasChanges, "logCraving saves immediately")
        let craving = try XCTUnwrap(logger.fetchCravings(for: habit, context: context).first)
        XCTAssertEqual(craving.trigger, "Social situation")
        XCTAssertTrue(craving.survived)
        XCTAssertEqual(craving.duration, 185)
        XCTAssertEqual(craving.moodBefore, "Bad")
        XCTAssertEqual(craving.moodAfter, "Good")
        XCTAssertEqual(craving.timestamp?.timeIntervalSinceNow ?? -.infinity, 0, accuracy: 5)
        XCTAssertNotNil(craving.id)
    }

    func testCravingsAreListedNewestFirstAndPerHabit() throws {
        let context = makeContext()
        let smoking = makeAddiction(startDate: ago(days: 9), in: context)
        let caffeine = makeAddiction(.caffeine, startDate: ago(days: 9), in: context)
        addCraving(to: smoking, at: ago(days: 3), trigger: .stress, in: context)
        addCraving(to: smoking, at: ago(days: 1), trigger: .boredom, survived: false, in: context)
        addCraving(to: smoking, at: ago(days: 2), trigger: .habit, in: context)
        addCraving(to: caffeine, at: ago(hours: 2), trigger: .other, in: context)
        try context.save()

        let cravings = logger.fetchCravings(for: smoking, context: context)

        XCTAssertEqual(cravings.map(\.trigger), ["Boredom", "Habit/Routine", "Stress"])
        XCTAssertEqual(logger.cravingCount(for: smoking, context: context), 3)
        XCTAssertEqual(logger.survivedCount(for: smoking, context: context), 2)
        XCTAssertEqual(logger.cravingCount(for: caffeine, context: context), 1)
    }

    func testDateRangeQueryIsInclusiveAndChronological() throws {
        let context = makeContext()
        let habit = makeAddiction(startDate: ago(days: 20), in: context)
        let start = ago(days: 5)
        let end = ago(days: 1)
        addCraving(to: habit, at: ago(days: 6), in: context)
        addCraving(to: habit, at: end, trigger: .emotional, in: context)
        addCraving(to: habit, at: start, trigger: .saw, in: context)
        addCraving(to: habit, at: ago(hours: 3), in: context)
        try context.save()

        let inRange = logger.cravings(for: habit, from: start, to: end, context: context)

        XCTAssertEqual(inRange.map(\.trigger), ["Saw something", "Emotional"])
    }

    func testCalendarMarksADayClearOnlyIfEveryCravingWasSurvived() throws {
        let context = makeContext()
        let now = Date()
        let habit = makeAddiction(startDate: ago(days: 20, from: now), in: context)
        addCraving(to: habit, at: day(4, hour: 9, from: now), in: context)
        addCraving(to: habit, at: day(4, hour: 21, from: now), survived: false, in: context)
        addCraving(to: habit, at: day(4, hour: 23, from: now), in: context)
        addCraving(to: habit, at: day(2, hour: 13, from: now), in: context)
        addCraving(to: habit, at: day(2, hour: 18, from: now), in: context)
        try context.save()

        let map = logger.cravingDateMap(for: habit, context: context)

        XCTAssertEqual(map.count, 2)
        XCTAssertEqual(map[day(4, hour: 0, from: now)], false)
        XCTAssertEqual(map[day(2, hour: 0, from: now)], true)
        XCTAssertNil(map[day(3, hour: 0, from: now)])
    }
}
