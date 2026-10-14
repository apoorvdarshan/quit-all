import XCTest

final class HabitsUITests: QuitAllUITestCase {
    func testAddingAHabitPersistsAcrossLaunches() {
        let app = launchSeededHome()
        openTab("Habits", in: app)
        waitFor(app.buttons["habits.row.Smoking"])
        XCTAssertTrue(app.buttons["habits.row.Caffeine"].exists)
        XCTAssertFalse(app.buttons["habits.row.Alcohol"].exists)

        app.buttons["habits.add"].tap()
        waitFor(app.navigationBars["Add Addiction"])
        XCTAssertFalse(app.buttons["addHabit.type.Smoking"].exists, "habits already tracked are not offered")
        app.buttons["addHabit.type.Alcohol"].tap()
        let dailyCost = app.textFields["addHabit.dailyCost"]
        waitFor(dailyCost)
        dailyCost.tap()
        dailyCost.typeText("12")
        app.staticTexts["QUIT DATE"].tap() // dismisses the keyboard
        tapButton("ADD ADDICTION", in: app)

        let alcohol = app.buttons["habits.row.Alcohol"]
        waitFor(alcohol)
        XCTAssertTrue(alcohol.label.contains("0 days clean"), alcohol.label)
        XCTAssertTrue(alcohol.label.contains("$12.00/day"), alcohol.label)

        relaunchKeepingData(app)
        openTab("Habits", in: app)
        waitFor(app.buttons["habits.row.Alcohol"], timeout: 20)
        XCTAssertTrue(app.buttons["habits.row.Smoking"].exists)
    }

    func testEditingDailySpendingUpdatesSavings() {
        let app = launchSeededHome()
        openTab("Habits", in: app)

        let smoking = app.buttons["habits.row.Smoking"]
        waitFor(smoking)
        XCTAssertTrue(smoking.label.contains("$15.00/day"), smoking.label)
        smoking.tap()

        waitFor(app.navigationBars["Edit"])
        let dailyCost = app.textFields["editHabit.dailyCost"]
        waitFor(dailyCost)
        XCTAssertEqual(dailyCost.value as? String, "15")
        replaceText(of: dailyCost, with: "20")
        app.navigationBars["Edit"].buttons["Save"].tap()
        waitForDisappearance(app.navigationBars["Edit"])

        // 10 days at the new $20/day.
        let updated = NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "$20.00/day", "$200")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: updated, object: smoking)], timeout: 10), .completed, smoking.label)

        openTab("Home", in: app)
        waitForLabel(app.staticTexts["home.stat.Saved"], "$200")
    }
}
