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
        XCTAssertTrue(control(app.switches, containing: "Smart Notifications").exists)
        XCTAssertTrue(control(app.buttons, containing: "Manage Purchase").exists)
        XCTAssertTrue(control(app.buttons, containing: "Reset All Data").exists)

        openTab("About", in: app)
        waitFor(app.navigationBars["About"])
        XCTAssertTrue(app.staticTexts["Version"].exists)
        XCTAssertTrue(control(app.buttons, containing: "Privacy Policy").exists
                      || control(app.links, containing: "Privacy Policy").exists)

        openTab("Home", in: app)
        waitFor(app.buttons["home.sos"])
    }

    func testAboutLinksToTheSourceCodeAndIssueForms() {
        let app = launchSeededHome()
        openTab("About", in: app)
        waitFor(app.navigationBars["About"])

        for label in ["Star on GitHub", "Report a Bug", "Request a Feature"] {
            var row = aboutRow(label, in: app)
            var swipes = 0
            while !row.exists && swipes < 6 {
                app.swipeUp()
                swipes += 1
                row = aboutRow(label, in: app)
            }
            XCTAssertTrue(row.exists, "About shows \(label)")
        }
    }

    private func aboutRow(_ label: String, in app: XCUIApplication) -> XCUIElement {
        let button = control(app.buttons, containing: label)
        return button.exists ? button : control(app.links, containing: label)
    }

    func testResetAllDataReturnsToOnboardingForGood() {
        let app = launchSeededHome()
        openTab("Settings", in: app)

        let reset = control(app.buttons, containing: "Reset All Data")
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
