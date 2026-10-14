import CoreData
import XCTest
@testable import Quit_All

final class AddictionTrackerTests: QuitAllTestCase {
    private let tracker = AddictionTracker.shared

    func testCreatingAHabitSavesEveryField() throws {
        let context = makeContext()
        let start = ago(days: 4, hours: 3)
        let habit = tracker.createAddiction(
            name: "Smoking", type: .smoking, startDate: start,
            dailyCost: 12.5, motivation: "For my kids", context: context
        )

        XCTAssertFalse(context.hasChanges, "createAddiction saves immediately")
        XCTAssertNotNil(habit.id)
        XCTAssertEqual(habit.name, "Smoking")
        XCTAssertEqual(habit.type, "Smoking")
        XCTAssertEqual(habit.startDate, start)
        XCTAssertEqual(habit.dailyCost, 12.5)
        XCTAssertEqual(habit.currency, "USD")
        XCTAssertEqual(habit.motivation, "For my kids")
        XCTAssertTrue(habit.isActive)
        XCTAssertEqual(habit.longestStreak, 0)
        XCTAssertEqual(habit.totalRelapses, 0)
        XCTAssertEqual(try count("CDAddiction", in: context), 1)
    }

    func testActiveHabitsAreListedOldestFirst() {
        let context = makeContext()
        makeAddiction(.caffeine, startDate: ago(days: 2), in: context)
        makeAddiction(.smoking, startDate: ago(days: 20), in: context)
        let paused = makeAddiction(.alcohol, startDate: ago(days: 40), in: context)
        paused.isActive = false
        tracker.saveContext(context)

        tracker.loadActiveAddictions(context: context)

        XCTAssertEqual(tracker.activeAddictions.map(\.name), ["Smoking", "Caffeine"])
    }

    func testStreakLengthComesFromTheStartDate() {
        let context = makeContext()
        let habit = makeAddiction(startDate: ago(days: 6, hours: 5), in: context)
        XCTAssertEqual(tracker.streakDays(for: habit), 6)
        XCTAssertEqual(tracker.streakHours(for: habit), 149)

        habit.startDate = nil
        XCTAssertEqual(tracker.streakDays(for: habit), 0)
        XCTAssertEqual(tracker.streakHours(for: habit), 0)
    }

    func testLongestStreakOnlyGrows() {
        let context = makeContext()
        let habit = makeAddiction(startDate: ago(days: 12, hours: 2), in: context)

        tracker.updateLongestStreak(for: habit, context: context)
        XCTAssertEqual(habit.longestStreak, 12)

        habit.longestStreak = 30
        tracker.updateLongestStreak(for: habit, context: context)
        XCTAssertEqual(habit.longestStreak, 30)
    }

    func testRelapseRecordsTheBrokenStreakAndRestartsTheClock() throws {
        let context = makeContext()
        let habit = makeAddiction(startDate: ago(days: 10, hours: 2), in: context)
        habit.longestStreak = 4

        tracker.logRelapse(
            for: habit, whatHappened: RelapseActivity.party.rawValue,
            feeling: Mood.bad.rawValue, nextTimePlan: "Leave early", context: context
        )

        XCTAssertFalse(context.hasChanges, "logRelapse saves immediately")
        XCTAssertEqual(habit.totalRelapses, 1)
        XCTAssertEqual(habit.longestStreak, 10)
        XCTAssertEqual(habit.startDate?.timeIntervalSinceNow ?? -.infinity, 0, accuracy: 5)
        XCTAssertEqual(tracker.streakDays(for: habit), 0)

        let relapses = try XCTUnwrap(habit.relapses as? Set<CDRelapseEvent>)
        XCTAssertEqual(relapses.count, 1)
        let relapse = try XCTUnwrap(relapses.first)
        XCTAssertEqual(relapse.streakBroken, 10)
        XCTAssertEqual(relapse.whatHappened, "At a party")
        XCTAssertEqual(relapse.feeling, "Bad")
        XCTAssertEqual(relapse.nextTimePlan, "Leave early")
        XCTAssertNotNil(relapse.timestamp)
    }

    func testRelapseKeepsALongerEarlierBest() {
        let context = makeContext()
        let habit = makeAddiction(startDate: ago(days: 3, hours: 2), in: context)
        habit.longestStreak = 45
        habit.totalRelapses = 2

        tracker.logRelapse(for: habit, whatHappened: "", feeling: "", nextTimePlan: "", context: context)

        XCTAssertEqual(habit.longestStreak, 45)
        XCTAssertEqual(habit.totalRelapses, 3)
    }

    func testDeletingAHabitRemovesItsHistory() throws {
        let context = makeContext()
        let habit = makeAddiction(startDate: ago(days: 8), in: context)
        let kept = makeAddiction(.caffeine, startDate: ago(days: 1), in: context)
        addCraving(to: habit, at: ago(days: 1), in: context)
        addCraving(to: kept, at: ago(hours: 3), in: context)
        addRelapse(to: habit, at: ago(days: 2), streakBroken: 6, in: context)
        let milestone = CDMilestone(context: context)
        milestone.type = MilestoneType.oneWeek.rawValue
        milestone.addiction = habit
        try context.save()

        tracker.deleteAddiction(habit, context: context)

        XCTAssertEqual(try count("CDAddiction", in: context), 1)
        XCTAssertEqual(try count("CDCravingEvent", in: context), 1, "only the remaining habit's craving is kept")
        XCTAssertEqual(try count("CDRelapseEvent", in: context), 0)
        XCTAssertEqual(try count("CDMilestone", in: context), 0)
        XCTAssertEqual(tracker.activeAddictions.map(\.name), ["Caffeine"])
    }

    func testUnknownStoredTypeFallsBackToSmoking() {
        let context = makeContext()
        let habit = makeAddiction(.gambling, startDate: ago(days: 1), in: context)
        XCTAssertEqual(tracker.addictionType(for: habit), .gambling)

        habit.type = "Retired habit"
        XCTAssertEqual(tracker.addictionType(for: habit), .smoking)
        habit.type = nil
        XCTAssertEqual(tracker.addictionType(for: habit), .smoking)
    }
}
