import CoreData
import XCTest
@testable import Quit_All

final class PersistenceTests: QuitAllTestCase {
    func testModelDefinesTheFourEntitiesAndCascadesHabitHistory() throws {
        let model = makeContext().persistentStoreCoordinator!.managedObjectModel
        XCTAssertEqual(
            Set(model.entitiesByName.keys),
            ["CDAddiction", "CDCravingEvent", "CDMilestone", "CDRelapseEvent"]
        )
        let habit = try XCTUnwrap(model.entitiesByName["CDAddiction"])
        for relationship in ["cravings", "milestones", "relapses"] {
            XCTAssertEqual(habit.relationshipsByName[relationship]?.deleteRule, .cascadeDeleteRule, relationship)
        }
    }

    func testContainersShareOneModel() {
        // Separate models per container make Core Data unable to pick an entity
        // for CDAddiction(context:), which breaks the app's previews and tests.
        let first = makeContext().persistentStoreCoordinator!.managedObjectModel
        let second = makeContext().persistentStoreCoordinator!.managedObjectModel
        XCTAssertTrue(first === second)
    }

    func testInMemoryStoresAreIsolated() throws {
        let first = makeContext()
        let second = makeContext()
        makeAddiction(startDate: ago(days: 1), in: first)

        XCTAssertEqual(try count("CDAddiction", in: first), 1)
        XCTAssertEqual(try count("CDAddiction", in: second), 0)
    }

    func testHabitsSurviveReopeningTheStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuitAllTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appendingPathComponent("Quit_All.sqlite")
        let model = makeContext().persistentStoreCoordinator!.managedObjectModel
        let start = ago(days: 7, hours: 3)
        var opened: [NSManagedObjectContext] = []
        defer {
            // Close every store before deleting its files; SQLite must not
            // have its database unlinked while it is still open.
            for context in opened {
                let coordinator = context.persistentStoreCoordinator!
                for store in coordinator.persistentStores {
                    try? coordinator.remove(store)
                }
            }
            try? FileManager.default.removeItem(at: directory)
        }

        let first = try openStore(at: storeURL, model: model)
        opened.append(first)
        let saved = makeAddiction(.alcohol, startDate: start, dailyCost: 9.5, in: first)
        addCraving(to: saved, at: ago(days: 1), trigger: .social, survived: false, in: first)
        try first.save()
        let firstCoordinator = first.persistentStoreCoordinator!
        for store in firstCoordinator.persistentStores {
            try firstCoordinator.remove(store)
        }

        let reopened = try openStore(at: storeURL, model: model)
        opened.append(reopened)
        let request: NSFetchRequest<CDAddiction> = CDAddiction.fetchRequest()
        let habits = try reopened.fetch(request)
        XCTAssertEqual(habits.count, 1)
        let habit = try XCTUnwrap(habits.first)
        XCTAssertEqual(habit.name, "Alcohol")
        XCTAssertEqual(habit.dailyCost, 9.5)
        XCTAssertEqual(try XCTUnwrap(habit.startDate).timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 0.001)
        let cravings = try XCTUnwrap(habit.cravings as? Set<CDCravingEvent>)
        XCTAssertEqual(cravings.map(\.trigger), ["Social situation"])
        XCTAssertEqual(cravings.first?.survived, false)
    }

    func testPreviewStoreHasSampleData() throws {
        let context = PersistenceController.preview.container.viewContext
        XCTAssertEqual(try count("CDAddiction", in: context), 1)
        XCTAssertEqual(try count("CDCravingEvent", in: context), 5)
        XCTAssertEqual(try count("CDMilestone", in: context), 1)
    }

    private func openStore(at url: URL, model: NSManagedObjectModel) throws -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "Quit_All", managedObjectModel: model)
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: url)]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        return container.viewContext
    }
}
