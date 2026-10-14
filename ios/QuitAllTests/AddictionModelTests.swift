import SwiftUI
import UIKit
import XCTest
@testable import Quit_All

final class AddictionModelTests: QuitAllTestCase {
    func testStoredHabitTypesStayStable() {
        // CDAddiction.type stores these raw values; renaming one breaks saved habits.
        XCTAssertEqual(
            AddictionType.allCases.map(\.rawValue),
            ["Smoking", "Vaping", "Alcohol", "Porn", "Social Media", "Weed", "Gambling", "Overspending", "Caffeine"]
        )
        XCTAssertEqual(Set(AddictionType.allCases.map(\.id)).count, AddictionType.allCases.count)
    }

    func testEveryHabitHasABundledIcon() {
        for type in AddictionType.allCases {
            XCTAssertNotNil(UIImage(named: type.iconName, in: Bundle.main, with: nil), type.iconName)
        }
        for name in ["app_logo", "icon_money_saved", "icon_life_saved", "icon_calendar"] {
            XCTAssertNotNil(UIImage(named: name, in: Bundle.main, with: nil), name)
        }
    }

    func testLifeCostAndDefaultUnitsPerHabit() {
        XCTAssertEqual(AddictionType.smoking.minutesPerUnit, 11)
        XCTAssertEqual(AddictionType.vaping.minutesPerUnit, 5)
        XCTAssertEqual(AddictionType.alcohol.minutesPerUnit, 15)
        XCTAssertEqual(AddictionType.smoking.defaultDailyUnits, 10)
        XCTAssertEqual(AddictionType.vaping.defaultDailyUnits, 8)
        XCTAssertEqual(AddictionType.alcohol.defaultDailyUnits, 3)
        XCTAssertEqual(AddictionType.smoking.unitName, "cigarette")
        XCTAssertEqual(AddictionType.caffeine.unitName, "cup")
        for type in [AddictionType.porn, .socialMedia, .weed, .gambling, .overspending, .caffeine] {
            XCTAssertEqual(type.minutesPerUnit, 0, type.rawValue)
            XCTAssertEqual(type.defaultDailyUnits, 1, type.rawValue)
        }
    }

    func testStoredEventValuesStayStable() {
        XCTAssertEqual(
            CravingTrigger.allCases.map(\.rawValue),
            ["Stress", "Boredom", "Social situation", "Saw something", "Habit/Routine", "Emotional", "Other"]
        )
        XCTAssertEqual(Mood.allCases.map(\.rawValue), ["Great", "Good", "Okay", "Bad", "Terrible"])
        XCTAssertEqual(RelapseActivity.allCases.count, 9)
        XCTAssertEqual(RelapseActivity.bored.rawValue, "Just bored")
        XCTAssertEqual(RelapseActivity.other.rawValue, "Something else")
    }

    func testHexColorsParseSixThreeAndEightDigitForms() {
        assertColor(Color(hex: "D4AF37"), red: 212, green: 175, blue: 55, alpha: 255)
        assertColor(Color(hex: "#080808"), red: 8, green: 8, blue: 8, alpha: 255)
        assertColor(Color(hex: "F0A"), red: 255, green: 0, blue: 170, alpha: 255)
        assertColor(Color(hex: "80FF0000"), red: 255, green: 0, blue: 0, alpha: 128)
        // Anything else falls back to opaque black.
        assertColor(Color(hex: "12345"), red: 0, green: 0, blue: 0, alpha: 255)
    }

    private func assertColor(
        _ color: Color, red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a), file: file, line: line)
        XCTAssertEqual(r * 255, red, accuracy: 0.5, "red", file: file, line: line)
        XCTAssertEqual(g * 255, green, accuracy: 0.5, "green", file: file, line: line)
        XCTAssertEqual(b * 255, blue, accuracy: 0.5, "blue", file: file, line: line)
        XCTAssertEqual(a * 255, alpha, accuracy: 0.5, "alpha", file: file, line: line)
    }
}
