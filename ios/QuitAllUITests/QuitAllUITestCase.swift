import XCTest

/// Shared launch and wait helpers.
///
/// Every test launches the Debug simulator build in its test mode
/// (`--ui-testing`, see AppTestEnvironment): no RevenueCat, StoreKit purchase,
/// App Store lookup, KLIPY request or notification prompt can happen, and each
/// test starts from an empty store unless it relaunches on purpose.
@MainActor
class QuitAllUITestCase: XCTestCase {
    enum Flag: String {
        case onboarded = "--ui-testing-onboarded"
        case premium = "--ui-testing-premium"
        case seedHabits = "--ui-testing-seed-habits"
    }

    private static let baseArguments = [
        "--ui-testing",
        "-AppleLanguages", "(en)",
        "-AppleLocale", "en_US",
    ]

    /// A fresh app: empty store, cleared defaults, English, UTC.
    func launch(_ flags: [Flag] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = Self.baseArguments + ["--ui-testing-reset"] + flags.map(\.rawValue)
        app.launchEnvironment["TZ"] = "UTC"
        app.launch()
        return app
    }

    /// Relaunches with the data the previous launch saved.
    func relaunchKeepingData(_ app: XCUIApplication, _ flags: [Flag] = [.premium]) {
        app.terminate()
        app.launchArguments = Self.baseArguments + flags.map(\.rawValue)
        app.launch()
    }

    /// Launches onboarded, with premium access and the two seeded habits, on Home.
    func launchSeededHome() -> XCUIApplication {
        let app = launch([.onboarded, .premium, .seedHabits])
        waitFor(app.staticTexts["home.streakValue"], timeout: 20)
        return app
    }

    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing \(element)", file: file, line: line)
    }

    func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 10,
                      file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed,
                       "\(element) label is \(element.exists ? element.label : "<missing>"), expected \(label)",
                       file: file, line: line)
    }

    func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 10,
                              file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed,
                       "\(element) is still shown", file: file, line: line)
    }

    /// Taps the only button with this label once a screen transition has finished.
    func tapButton(_ label: String, in app: XCUIApplication, timeout: TimeInterval = 10,
                   file: StaticString = #filePath, line: UInt = #line) {
        let query = app.buttons.matching(identifier: label)
        let single = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in query.count == 1 && query.firstMatch.isHittable },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [single], timeout: timeout), .completed,
                       "Expected one tappable \"\(label)\" button, found \(query.count)", file: file, line: line)
        query.firstMatch.tap()
    }

    /// A static text whose label starts with `prefix` (for multi-line titles).
    func text(startingWith prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    func replaceText(of field: XCUIElement, with text: String) {
        field.tap()
        let existing = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + text)
    }

    func openTab(_ name: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[name]
        waitFor(tab)
        tab.tap()
    }
}
