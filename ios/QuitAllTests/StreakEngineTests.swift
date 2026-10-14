import XCTest
@testable import Quit_All

final class StreakEngineTests: QuitAllTestCase {
    func testCalendarMathRunsInUTC() {
        XCTAssertEqual(Calendar.current.timeZone.secondsFromGMT(), 0)
    }

    func testElapsedTimeCountsOnlyCompleteUnits() {
        let start = ago(days: 10, hours: 2)
        XCTAssertEqual(StreakEngine.daysSince(start), 10)
        XCTAssertEqual(StreakEngine.hoursSince(start), 242)
        XCTAssertEqual(StreakEngine.minutesSince(ago(minutes: 90.5)), 90)
        XCTAssertEqual(StreakEngine.daysSince(ago(hours: 23, minutes: 30)), 0)
    }

    func testMissingOrFutureStartDatesNeverGoNegative() {
        XCTAssertEqual(StreakEngine.daysSince(nil), 0)
        XCTAssertEqual(StreakEngine.hoursSince(nil), 0)
        XCTAssertEqual(StreakEngine.minutesSince(nil), 0)

        let future = Date().addingTimeInterval(3 * 86_400)
        XCTAssertEqual(StreakEngine.daysSince(future), 0)
        XCTAssertEqual(StreakEngine.hoursSince(future), 0)
        XCTAssertEqual(StreakEngine.minutesSince(future), 0)
    }

    func testStreakIsShownInTheLargestCompleteUnit() {
        func format(_ start: Date?) -> String {
            let streak = StreakEngine.formatStreak(startDate: start)
            return "\(streak.value) \(streak.unit)"
        }
        XCTAssertEqual(format(Date()), "0 minutes")
        XCTAssertEqual(format(ago(minutes: 1.5)), "1 minute")
        XCTAssertEqual(format(ago(minutes: 42.5)), "42 minutes")
        XCTAssertEqual(format(ago(hours: 1, minutes: 5)), "1 hour")
        XCTAssertEqual(format(ago(hours: 5, minutes: 30)), "5 hours")
        XCTAssertEqual(format(ago(days: 1, hours: 2)), "1 day")
        XCTAssertEqual(format(ago(days: 12, hours: 2)), "12 days")
        XCTAssertEqual(format(nil), "0 minutes")
    }

    func testProgressRunsFromThePreviousMilestoneToTheNextOne() throws {
        let fresh = StreakEngine.progressToNextMilestone(startDate: Date())
        XCTAssertEqual(fresh.progress, 0, accuracy: 0.0001)
        XCTAssertEqual(fresh.nextMilestone?.type, .oneHour)

        // 12 h is 11 of the 23 hours between the 1 h and 24 h milestones.
        let halfDay = StreakEngine.progressToNextMilestone(startDate: ago(hours: 12, minutes: 5))
        XCTAssertEqual(halfDay.progress, 11.0 / 23.0, accuracy: 0.0001)
        XCTAssertEqual(halfDay.nextMilestone?.type, .twentyFourHours)

        // Reaching a milestone exactly starts the next segment from zero.
        let oneDay = StreakEngine.progressToNextMilestone(startDate: ago(hours: 24, minutes: 5))
        XCTAssertEqual(oneDay.progress, 0, accuracy: 0.0001)
        XCTAssertEqual(oneDay.nextMilestone?.type, .threeDays)

        let tenDays = StreakEngine.progressToNextMilestone(startDate: ago(days: 10, hours: 2))
        XCTAssertEqual(tenDays.progress, Double(242 - 168) / Double(336 - 168), accuracy: 0.0001)
        XCTAssertEqual(tenDays.nextMilestone?.title, "Your brain is rewiring right now")
    }

    func testProgressIsCompleteAfterTheLastMilestone() {
        let veteran = StreakEngine.progressToNextMilestone(startDate: ago(days: 400))
        XCTAssertEqual(veteran.progress, 1)
        XCTAssertNil(veteran.nextMilestone)
    }

    func testUnlockedMilestonesFollowElapsedHours() {
        XCTAssertTrue(StreakEngine.unlockedMilestones(startDate: ago(minutes: 30)).isEmpty)
        XCTAssertEqual(
            StreakEngine.unlockedMilestones(startDate: ago(days: 10, hours: 2)).map(\.type),
            [.oneHour, .twentyFourHours, .threeDays, .oneWeek]
        )
        XCTAssertEqual(StreakEngine.unlockedMilestones(startDate: ago(days: 366)).count, MilestoneType.allCases.count)
    }

    func testNewMilestoneIsTheFirstUnlockedOneNotYetRecorded() {
        let start = ago(days: 10, hours: 2)
        XCTAssertEqual(StreakEngine.checkNewMilestone(startDate: start, existingMilestones: [])?.type, .oneHour)
        XCTAssertEqual(
            StreakEngine.checkNewMilestone(startDate: start, existingMilestones: ["1_hour", "24_hours"])?.type,
            .threeDays
        )
        XCTAssertNil(
            StreakEngine.checkNewMilestone(
                startDate: start,
                existingMilestones: ["1_hour", "24_hours", "3_days", "1_week"]
            )
        )
        XCTAssertNil(StreakEngine.checkNewMilestone(startDate: ago(minutes: 20), existingMilestones: []))
    }
}

final class MilestoneLibraryTests: QuitAllTestCase {
    func testOneMilestonePerTypeInAscendingOrder() {
        let milestones = MilestoneLibrary.milestones
        XCTAssertEqual(milestones.map(\.type), MilestoneType.allCases)
        XCTAssertEqual(milestones.map(\.requiredHours), milestones.map(\.requiredHours).sorted())
        for milestone in milestones {
            XCTAssertEqual(milestone.requiredHours, milestone.type.hours, milestone.type.rawValue)
            XCTAssertEqual(milestone.requiredDays, Double(milestone.type.hours) / 24, accuracy: 0.0001)
            XCTAssertFalse(milestone.title.isEmpty)
            XCTAssertFalse(milestone.healthFact.isEmpty)
        }
    }

    func testStoredMilestoneIdentifiersStayStable() {
        // CDMilestone.type stores these raw values; renaming one orphans saved milestones.
        XCTAssertEqual(
            MilestoneType.allCases.map(\.rawValue),
            ["1_hour", "24_hours", "3_days", "1_week", "2_weeks", "30_days", "100_days", "6_months", "1_year"]
        )
        XCTAssertEqual(
            MilestoneType.allCases.map(\.hours),
            [1, 24, 72, 168, 336, 720, 2400, 4380, 8760]
        )
        XCTAssertEqual(MilestoneType.hundredDays.displayName, "100 Days")
    }
}
