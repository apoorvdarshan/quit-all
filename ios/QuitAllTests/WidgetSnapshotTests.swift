import CoreData
import XCTest
@testable import Quit_All

/// The widget extension decodes the snapshot with its own copy of these fields
/// (QuitAllWidgetSnapshot), so the JSON keys are a contract between the targets.
final class WidgetSnapshotTests: QuitAllTestCase {
    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: WidgetSnapshotStore.appGroupIdentifier)!
    }

    func testSnapshotKeysMatchWhatTheWidgetReads() throws {
        let snapshot = WidgetSnapshot(
            addictionName: "Smoking", addictionType: "Smoking", startDate: Date(),
            dailyCost: 15, currencyCode: "USD", activeHabitCount: 2, updatedAt: Date()
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        XCTAssertEqual(
            Set(json.keys),
            ["addictionName", "addictionType", "startDate", "dailyCost", "currencyCode", "activeHabitCount", "updatedAt"]
        )
        XCTAssertEqual(WidgetSnapshotStore.appGroupIdentifier, "group.com.apoorvdarshan.quitall")
    }

    func testRefreshPublishesTheFirstHabitInDisplayOrder() throws {
        let context = makeContext()
        let start = ago(days: 6, hours: 1)
        let smoking = makeAddiction(.smoking, startDate: start, dailyCost: 15, in: context)
        let caffeine = makeAddiction(.caffeine, startDate: ago(days: 2), dailyCost: 4, in: context)
        smoking.sortOrder = 1
        caffeine.sortOrder = 0
        caffeine.currency = "EUR"
        try context.save()

        WidgetSnapshotStore.refresh(context: context)
        let first = try readSnapshot()
        XCTAssertEqual(first.addictionName, "Caffeine")
        XCTAssertEqual(first.currencyCode, "EUR")
        XCTAssertEqual(first.dailyCost, 4)
        XCTAssertEqual(first.activeHabitCount, 2)

        WidgetSnapshotStore.refresh(context: context, selectedAddiction: smoking)
        let selected = try readSnapshot()
        XCTAssertEqual(selected.addictionName, "Smoking")
        XCTAssertEqual(selected.addictionType, "Smoking")
        XCTAssertEqual(selected.startDate.timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 0.001)
    }

    func testSnapshotIsClearedWithoutActiveHabits() throws {
        let context = makeContext()
        makeAddiction(startDate: ago(days: 1), in: context)
        WidgetSnapshotStore.refresh(context: context)
        XCTAssertNotNil(sharedDefaults.data(forKey: WidgetSnapshotStore.snapshotKey))

        WidgetSnapshotStore.refresh(context: makeContext())
        XCTAssertNil(sharedDefaults.data(forKey: WidgetSnapshotStore.snapshotKey))
    }

    func testSavingAHabitRefreshesTheWidget() throws {
        let context = makeContext()
        WidgetSnapshotStore.clear()

        makeAddiction(.weed, startDate: ago(days: 3), in: context)

        XCTAssertEqual(try readSnapshot().addictionName, "Weed")
        WidgetSnapshotStore.clear()
    }

    private func readSnapshot() throws -> WidgetSnapshot {
        let data = try XCTUnwrap(sharedDefaults.data(forKey: WidgetSnapshotStore.snapshotKey))
        return try JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
