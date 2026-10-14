import XCTest

final class PaywallUITests: QuitAllUITestCase {
    func testHardPaywallBlocksTheAppAndNeverCompletesAPurchase() {
        // Onboarded but no premium entitlement: the hard paywall covers Home.
        let app = launch([.onboarded, .seedHabits])

        let purchase = app.buttons["paywall.purchase"]
        waitFor(purchase, timeout: 20)
        // Without store products there is no trial offer to show.
        waitFor(app.staticTexts["Go Premium"])
        waitForLabel(purchase, "SUBSCRIBE NOW")
        // Without store prices the plans show their fallback prices.
        XCTAssertTrue(app.buttons["paywall.plan.yearly"].label.contains("$34.99/year"))
        XCTAssertTrue(app.buttons["paywall.plan.lifetime"].label.contains("$69.99 one-time"))
        XCTAssertFalse(app.buttons["paywall.plan.weekly"].exists, "weekly appears only once the store returns it")

        app.buttons["paywall.plan.lifetime"].tap()
        waitForLabel(purchase, "BUY LIFETIME")
        XCTAssertTrue(app.staticTexts["One-time purchase. No renewal."].exists)

        app.buttons["paywall.plan.yearly"].tap()
        waitForLabel(purchase, "SUBSCRIBE NOW")
        XCTAssertTrue(app.staticTexts["Cancel anytime in iPhone Settings."].exists)

        // Buying is impossible in test mode: no product, an error, and the paywall stays.
        purchase.tap()
        let error = app.staticTexts["paywall.error"]
        waitFor(error)
        XCTAssertEqual(error.label, "Products not available. Please try again.")

        // Restoring without an entitlement keeps the app locked.
        app.buttons["paywall.restore"].tap()
        XCTAssertTrue(purchase.waitForExistence(timeout: 3))
        let sos = app.buttons["home.sos"]
        XCTAssertFalse(sos.exists && sos.isHittable, "Home stays behind the paywall")

        XCTAssertTrue(app.buttons["Privacy Policy"].exists || app.links["Privacy Policy"].exists)
        XCTAssertTrue(app.buttons["Terms of Service"].exists || app.links["Terms of Service"].exists)
    }
}
