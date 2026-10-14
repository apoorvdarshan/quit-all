import XCTest

final class CravingAndRelapseUITests: QuitAllUITestCase {
    func testSurvivedCravingIsLoggedAndShowsUpInStats() {
        let app = launchSeededHome()

        app.buttons["home.sos"].tap()
        waitFor(app.staticTexts["Hold on"])
        // The SOS session plays the bundled offline loops; nothing is downloaded in tests.
        tapButton("I'M READY TO CHECK IN", in: app)

        waitFor(app.staticTexts["What triggered this craving?"])
        app.buttons["sos.trigger.Stress"].tap()
        tapButton("DID YOU MAKE IT?", in: app)

        waitFor(app.staticTexts["Did you make it through?"])
        app.buttons["sos.outcome.survived"].tap()

        // SOS closes after the celebration and Home is back.
        waitForDisappearance(app.staticTexts["Did you make it through?"])
        waitFor(app.buttons["home.sos"])

        openTab("Stats", in: app)
        waitFor(app.staticTexts["TOP TRIGGERS"])
        XCTAssertTrue(app.staticTexts["Stress"].exists)
        XCTAssertTrue(app.staticTexts["100%"].exists)
        waitFor(app.staticTexts["You've survived 100% of all cravings"])
    }

    func testRelapseIsLoggedWithoutShameAndRestartsTheStreak() {
        let app = launchSeededHome()

        app.buttons["home.sos"].tap()
        tapButton("I'M READY TO CHECK IN", in: app)
        waitFor(app.staticTexts["What triggered this craving?"])
        app.buttons["sos.trigger.Habit/Routine"].tap()
        tapButton("DID YOU MAKE IT?", in: app)
        waitFor(app.staticTexts["Did you make it through?"])
        app.buttons["sos.outcome.relapsed"].tap()

        // The relapse flow opens once SOS has closed.
        waitFor(app.staticTexts["Okay. That happened."], timeout: 15)
        XCTAssertTrue(app.staticTexts["Your streak of 10 days is saved in history."].exists)
        tapButton("CONTINUE", in: app)

        waitFor(app.buttons["relapse.activity.Just bored"])
        app.buttons["relapse.activity.Just bored"].tap()
        tapButton("NEXT", in: app)

        waitFor(app.buttons["relapse.mood.Okay"])
        app.buttons["relapse.mood.Okay"].tap()
        tapButton("NEXT", in: app)

        let plan = app.textFields["relapse.plan"]
        waitFor(plan)
        plan.tap()
        plan.typeText("Take a walk instead")
        tapButton("SAVE & START OVER", in: app)

        waitFor(app.staticTexts["New streak begins now."])
        tapButton("LET'S GO", in: app)

        // The new streak starts from zero; the 10-day streak lives on in history.
        let unit = app.staticTexts["home.streakUnit"]
        waitFor(unit)
        waitForLabel(app.staticTexts["home.streakValue"], "0")
        XCTAssertTrue(["minutes clean from smoking", "minute clean from smoking"].contains(unit.label), unit.label)
        XCTAssertEqual(app.staticTexts["home.stat.Saved"].label, "$0.00")
    }
}
