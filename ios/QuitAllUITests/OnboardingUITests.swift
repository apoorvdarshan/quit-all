import XCTest

final class OnboardingUITests: QuitAllUITestCase {
    func testOnboardingBuildsAPlanAndEndsOnThePaywall() {
        let app = launch()

        // Step 0: choose habits; CONTINUE stays disabled until one is picked.
        waitFor(app.staticTexts["SELECT ALL THAT APPLY"], timeout: 20)
        let continueButton = app.buttons["CONTINUE"]
        XCTAssertFalse(continueButton.isEnabled)
        app.buttons["onboarding.habit.Smoking"].tap()
        app.buttons["onboarding.habit.Alcohol"].tap()
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()

        // Step 1: details for each habit, in alphabetical order.
        waitFor(app.staticTexts["Quitting Alcohol"])
        let dailyCost = app.textFields["onboarding.dailyCost"]
        dailyCost.tap()
        dailyCost.typeText("12")
        tapButton("NEXT", in: app)

        waitFor(app.staticTexts["Quitting Smoking"])
        dailyCost.tap()
        dailyCost.typeText("15")
        let motivation = app.textFields["onboarding.motivation"]
        motivation.tap()
        motivation.typeText("For my health")
        tapButton("ANALYZE", in: app)

        // Step 2 runs a short analysis, then step 3 asks about symptoms.
        waitFor(text(startingWith: "Do you experience", in: app), timeout: 15)
        app.buttons["onboarding.symptom.Sleep problems"].tap()
        tapButton("CONTINUE", in: app)

        // Steps 4 and 5: feature and benefit pages.
        waitFor(app.staticTexts["SOS CRAVING BUTTON"])
        tapButton("CONTINUE", in: app)
        waitFor(app.staticTexts["Fast help during cravings"])
        tapButton("CONTINUE", in: app)

        // Step 6: the plan lists both habits with their daily savings.
        waitFor(text(startingWith: "Your quit plan", in: app))
        XCTAssertTrue(app.staticTexts["Saving $12.00/day"].exists)
        XCTAssertTrue(app.staticTexts["Saving $15.00/day"].exists)
        tapButton("SEE MY PLAN", in: app)

        // Step 7: the paywall. Nothing is bought, so onboarding cannot finish.
        waitFor(app.buttons["paywall.restore"])
        XCTAssertTrue(app.buttons["paywall.plan.yearly"].exists)
        XCTAssertTrue(app.buttons["paywall.plan.lifetime"].exists)
        XCTAssertTrue(app.buttons["paywall.purchase"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }

    func testRestoringPremiumFinishesOnboardingAndHomeSurvivesRelaunch() {
        let app = launch([.premium])

        waitFor(app.staticTexts["SELECT ALL THAT APPLY"], timeout: 20)
        app.buttons["onboarding.habit.Smoking"].tap()
        tapButton("CONTINUE", in: app)
        waitFor(app.staticTexts["Quitting Smoking"])
        let dailyCost = app.textFields["onboarding.dailyCost"]
        dailyCost.tap()
        dailyCost.typeText("10")
        tapButton("ANALYZE", in: app)
        waitFor(text(startingWith: "Do you experience", in: app), timeout: 15)
        tapButton("CONTINUE", in: app)
        waitFor(app.staticTexts["SOS CRAVING BUTTON"])
        tapButton("CONTINUE", in: app)
        waitFor(app.staticTexts["Fast help during cravings"])
        tapButton("CONTINUE", in: app)
        tapButton("SEE MY PLAN", in: app)

        // The simulated entitlement is restored; no purchase is made.
        let restore = app.buttons["paywall.restore"]
        waitFor(restore)
        restore.tap()

        // Home: a streak that just started, counted in minutes.
        let streakUnit = app.staticTexts["home.streakUnit"]
        waitFor(streakUnit, timeout: 15)
        XCTAssertTrue(["minutes clean from smoking", "minute clean from smoking"].contains(streakUnit.label), streakUnit.label)
        XCTAssertTrue(app.tabBars.buttons["Home"].exists)

        relaunchKeepingData(app)
        waitFor(app.staticTexts["home.streakUnit"], timeout: 20)
        XCTAssertFalse(app.staticTexts["SELECT ALL THAT APPLY"].exists, "onboarding stays finished")
        XCTAssertFalse(app.buttons["paywall.purchase"].exists)
    }
}
