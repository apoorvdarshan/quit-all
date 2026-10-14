import XCTest

final class SettingsUITests: QuitAllUITestCase {
    func testEveryTabOpensItsScreen() {
        let app = launchSeededHome()
        XCTAssertTrue(app.buttons["home.sos"].exists)

        openTab("Stats", in: app)
        waitFor(app.staticTexts["LAST 30 DAYS"])
        XCTAssertTrue(app.staticTexts["OVERALL"].exists, "two habits show the overall summary")

        openTab("Habits", in: app)
        waitFor(app.navigationBars["My Addictions"])

        openTab("Settings", in: app)
        waitFor(app.navigationBars["Settings"])
        XCTAssertTrue(app.switches["Smart Notifications"].exists)
        XCTAssertTrue(app.buttons["Manage Purchase"].exists)
        XCTAssertTrue(app.buttons["Reset All Data"].exists)

        openTab("About", in: app)
        waitFor(app.navigationBars["About"])
        XCTAssertTrue(app.staticTexts["Version"].exists)
        XCTAssertTrue(app.buttons["Privacy Policy"].exists || app.links["Privacy Policy"].exists)

        openTab("Home", in: app)
        waitFor(app.buttons["home.sos"])
    }

    func testResetAllDataReturnsToOnboardingForGood() {
        let app = launchSeededHome()
        openTab("Settings", in: app)

        let reset = app.buttons["Reset All Data"]
        waitFor(reset)
        reset.tap()
        let alert = app.alerts["Reset All Data?"]
        waitFor(alert)
        alert.buttons["Reset"].tap()

        waitFor(app.staticTexts["SELECT ALL THAT APPLY"], timeout: 10)

        relaunchKeepingData(app)
        waitFor(app.staticTexts["SELECT ALL THAT APPLY"], timeout: 20)
        XCTAssertFalse(app.staticTexts["home.streakValue"].exists, "habits and progress were deleted")
    }
}
