import CoreData
import XCTest
@testable import Quit_All

/// Shared base for the unit tests.
///
/// App types are main-actor isolated, so the tests are too. Every test runs in
/// UTC, so calendar math never depends on the machine's time zone or daylight
/// saving changes. Dates are built relative to "now" with a margin of at least
/// an hour from any unit boundary, so results do not depend on the time of day.
@MainActor
class QuitAllTestCase: XCTestCase {
    nonisolated override class func setUp() {
        super.setUp()
        NSTimeZone.default = TimeZone(identifier: "UTC")!
    }

    /// A fresh, empty in-memory store for one test. The context keeps its
    /// coordinator (and so the store) alive.
    func makeContext() -> NSManagedObjectContext {
        PersistenceController(inMemory: true).container.viewContext
    }

    func ago(days: Double = 0, hours: Double = 0, minutes: Double = 0, from now: Date = Date()) -> Date {
        now.addingTimeInterval(-(days * 86_400 + hours * 3_600 + minutes * 60))
    }

    /// A date `daysAgo` days back at a fixed hour of that day.
    func day(_ daysAgo: Int, hour: Int, from now: Date = Date()) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        return calendar.date(byAdding: .hour, value: hour, to: day)!
    }

    @discardableResult
    func makeAddiction(
        _ type: AddictionType = .smoking,
        startDate: Date,
        dailyCost: Double = 10,
        in context: NSManagedObjectContext
    ) -> CDAddiction {
        AddictionTracker.shared.createAddiction(
            name: type.rawValue,
            type: type,
            startDate: startDate,
            dailyCost: dailyCost,
            motivation: "Test",
            context: context
        )
    }

    @discardableResult
    func addCraving(
        to addiction: CDAddiction,
        at timestamp: Date,
        trigger: CravingTrigger = .stress,
        survived: Bool = true,
        in context: NSManagedObjectContext
    ) -> CDCravingEvent {
        let craving = CDCravingEvent(context: context)
        craving.id = UUID()
        craving.timestamp = timestamp
        craving.trigger = trigger.rawValue
        craving.survived = survived
        craving.addiction = addiction
        return craving
    }

    @discardableResult
    func addRelapse(
        to addiction: CDAddiction,
        at timestamp: Date,
        streakBroken: Int32,
        activity: RelapseActivity = .bored,
        in context: NSManagedObjectContext
    ) -> CDRelapseEvent {
        let relapse = CDRelapseEvent(context: context)
        relapse.id = UUID()
        relapse.timestamp = timestamp
        relapse.streakBroken = streakBroken
        relapse.whatHappened = activity.rawValue
        relapse.addiction = addiction
        return relapse
    }

    func count(_ entityName: String, in context: NSManagedObjectContext) throws -> Int {
        try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: entityName))
    }
}
