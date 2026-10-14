import XCTest
@testable import Quit_All

/// Currency strings assume the en_US test locale that scripts/test-ios.sh sets
/// (`-testLanguage en -testRegion US`).
final class CostCalculatorTests: QuitAllTestCase {
    func testMoneySavedCountsWholeDaysAfterTheFirstDay() {
        XCTAssertEqual(CostCalculator.moneySaved(dailyCost: 15, startDate: ago(days: 10, hours: 2)), 150, accuracy: 0.001)
        XCTAssertEqual(CostCalculator.moneySaved(dailyCost: 15, startDate: ago(days: 1, hours: 23)), 15, accuracy: 0.001)
        XCTAssertEqual(CostCalculator.moneySaved(dailyCost: 0, startDate: ago(days: 30)), 0)
    }

    func testMoneySavedIsProratedByTheHourOnTheFirstDay() {
        XCTAssertEqual(CostCalculator.moneySaved(dailyCost: 24, startDate: ago(hours: 6, minutes: 10)), 6, accuracy: 0.001)
        XCTAssertEqual(CostCalculator.moneySaved(dailyCost: 24, startDate: ago(minutes: 20)), 0, accuracy: 0.001)
    }

    func testMoneySavedWithoutAStartDateIsZero() {
        XCTAssertEqual(CostCalculator.moneySaved(dailyCost: 50, startDate: nil), 0)
    }

    func testProjectionUsesTheAverageMonthLength() {
        XCTAssertEqual(CostCalculator.projectedSavings(dailyCost: 10, months: 6), 1826.4, accuracy: 0.001)
        XCTAssertEqual(CostCalculator.projectedSavings(dailyCost: 10, months: 60), 18264, accuracy: 0.001)
        XCTAssertEqual(CostCalculator.projectedSavings(dailyCost: 0, months: 12), 0)
    }

    func testLifeSavedOnlyCountsHabitsWithAKnownCost() {
        let tenDays = ago(days: 10, hours: 2)
        // 10 days x 10 cigarettes x 11 minutes.
        XCTAssertEqual(CostCalculator.hoursSaved(addictionType: .smoking, dailyUnits: 10, startDate: tenDays), 1100.0 / 60, accuracy: 0.001)
        // 10 days x 3 drinks x 15 minutes.
        XCTAssertEqual(CostCalculator.hoursSaved(addictionType: .alcohol, dailyUnits: 3, startDate: tenDays), 7.5, accuracy: 0.001)
        XCTAssertEqual(CostCalculator.hoursSaved(addictionType: .vaping, dailyUnits: 8, startDate: tenDays), 400.0 / 60, accuracy: 0.001)
        for type in [AddictionType.porn, .socialMedia, .weed, .gambling, .overspending, .caffeine] {
            XCTAssertEqual(CostCalculator.hoursSaved(addictionType: type, dailyUnits: 5, startDate: tenDays), 0, type.rawValue)
        }
        XCTAssertEqual(CostCalculator.hoursSaved(addictionType: .smoking, dailyUnits: 10, startDate: nil), 0)
    }

    func testCurrencyFormattingDropsCentsFromOneHundredUp() {
        XCTAssertEqual(CostCalculator.formatCurrency(12.5), "$12.50")
        XCTAssertEqual(CostCalculator.formatCurrency(99.99, currencyCode: "USD"), "$99.99")
        XCTAssertEqual(CostCalculator.formatCurrency(150, currencyCode: "USD"), "$150")
        XCTAssertEqual(CostCalculator.formatCurrency(1_234.4, currencyCode: "USD"), "$1,234")
        XCTAssertEqual(CostCalculator.formatCurrency(12.5, currencyCode: "EUR"), "€12.50")
        XCTAssertEqual(CostCalculator.formatCurrency(1_245, currencyCode: "INR"), "₹1,245")
    }

    func testPurchaseIdeasStayWithinThreeTimesTheSavings() {
        let usd = CostCalculator.whatYouCouldBuy(amount: 150, currencyCode: "USD")
        XCTAssertEqual(usd.map { $0.item }, ["Coffee", "Nice dinner", "AirPods", "New sneakers"])
        XCTAssertEqual(usd.map { $0.cost }, [5, 30, 130, 150])
        XCTAssertTrue(CostCalculator.whatYouCouldBuy(amount: 1, currencyCode: "USD").isEmpty)
        XCTAssertEqual(CostCalculator.whatYouCouldBuy(amount: 1_000_000, currencyCode: nil).count, 10)
    }

    func testPurchaseIdeasArePricedInTheChosenCurrency() {
        let rupees = CostCalculator.whatYouCouldBuy(amount: 150 * 83, currencyCode: "INR")
        XCTAssertEqual(rupees.map { $0.item }, ["Coffee", "Nice dinner", "AirPods", "New sneakers"])
        XCTAssertEqual(rupees.first?.cost ?? 0, 5 * 83, accuracy: 0.001)
        // Unknown currencies fall back to USD prices.
        XCTAssertEqual(CostCalculator.whatYouCouldBuy(amount: 150, currencyCode: "CHF").map { $0.cost }, [5, 30, 130, 150])
    }

    func testLifeSavedIsShownInTheLargestReadableUnit() {
        XCTAssertEqual(CostCalculator.formatHoursSaved(0.5), "30 minutes")
        XCTAssertEqual(CostCalculator.formatHoursSaved(5.5), "5.5 hours")
        XCTAssertEqual(CostCalculator.formatHoursSaved(1100.0 / 60), "18.3 hours")
        XCTAssertEqual(CostCalculator.formatHoursSaved(48), "2.0 days")
        XCTAssertEqual(CostCalculator.formatHoursSaved(45 * 24), "1.5 months")
    }
}
