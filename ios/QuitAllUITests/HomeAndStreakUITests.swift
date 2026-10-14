import XCTest

/// Seeded habits: Smoking started 10 days 2 hours ago at $15/day, and
/// Caffeine 3 days 2 hours ago at $5/day.
final class HomeAndStreakUITests: QuitAllUITestCase {
    func testHomeShowsEachHabitsStreakSavingsAndNextMilestone() {
        let app = launchSeededHome()

        let value = app.staticTexts["home.streakValue"]
        let unit = app.staticTexts["home.streakUnit"]
        waitForLabel(value, "10")
        XCTAssertEqual(unit.label, "days clean from smoking")
        XCTAssertEqual(app.staticTexts["home.stat.Saved"].label, "$150")
        // 10 days x 10 cigarettes x 11 minutes.
        XCTAssertEqual(app.staticTexts["home.stat.Life saved"].label, "18.3 hours")
        XCTAssertTrue(app.staticTexts["home.stat.Clean since"].exists)
        XCTAssertEqual(app.staticTexts["home.nextMilestone"].label, "Next: Your brain is rewiring right now")

        // Switching habits from the card row.
        app.buttons["home.habitCard.Caffeine"].tap()
        waitForLabel(value, "3")
        XCTAssertEqual(unit.label, "days clean from caffeine")
        XCTAssertEqual(app.staticTexts["home.stat.Saved"].label, "$15.00")
        XCTAssertFalse(app.staticTexts["home.stat.Life saved"].exists, "caffeine has no life-time cost")
        XCTAssertEqual(app.staticTexts["home.nextMilestone"].label, "Next: One full week")
    }

    func testMilestonesUnlockWithTheStreakAndSavingsOpenTheCalculator() {
        let app = launchSeededHome()

        app.staticTexts["home.streakValue"].tap()
        waitFor(app.navigationBars["Milestones"])
        let oneWeek = app.buttons["milestone.1_week"]
        let twoWeeks = app.buttons["milestone.2_weeks"]
        waitFor(oneWeek)
        XCTAssertTrue(oneWeek.isEnabled, "unlocked after 10 days")
        XCTAssertTrue(twoWeeks.exists)
        XCTAssertFalse(twoWeeks.isEnabled, "locked until day 14")

        // An unlocked milestone opens its share card.
        oneWeek.tap()
        waitFor(app.staticTexts["10 days free from smoking"])
        app.buttons["Close"].tap()
        waitForDisappearance(app.staticTexts["10 days free from smoking"])
        app.navigationBars["Milestones"].buttons["Done"].tap()
        waitForDisappearance(app.navigationBars["Milestones"])

        // The savings badge opens the cost calculator.
        app.staticTexts["home.stat.Saved"].tap()
        waitFor(app.navigationBars["Money Saved"])
        waitForLabel(app.staticTexts["cost.totalSaved"], "$150")
        XCTAssertTrue(app.staticTexts["since quitting smoking"].exists)
        XCTAssertTrue(app.staticTexts["PROJECTED SAVINGS"].exists)
        app.navigationBars["Money Saved"].buttons["Done"].tap()
        waitForDisappearance(app.navigationBars["Money Saved"])
    }
}
