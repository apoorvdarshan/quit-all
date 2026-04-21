import Foundation
import CoreData

// MARK: - Craving Logger
// Records and queries craving events.
@Observable
final class CravingLogger {
    static let shared = CravingLogger()
    private init() {}

    func logCraving(
        addiction: CDAddiction,
        trigger: CravingTrigger,
        survived: Bool,
        duration: Int = 0,
        moodBefore: Mood? = nil,
        moodAfter: Mood? = nil,
        context: NSManagedObjectContext
    ) {
        let event = CDCravingEvent(context: context)
        event.id = UUID()
        event.timestamp = Date()
        event.trigger = trigger.rawValue
        event.survived = survived
        event.duration = Int32(duration)
        event.moodBefore = moodBefore?.rawValue
        event.moodAfter = moodAfter?.rawValue
        event.addiction = addiction

        AddictionTracker.shared.saveContext(context)
    }

    func fetchCravings(for addiction: CDAddiction, context: NSManagedObjectContext) -> [CDCravingEvent] {
        let request: NSFetchRequest<CDCravingEvent> = CDCravingEvent.fetchRequest()
        request.predicate = NSPredicate(format: "addiction == %@", addiction)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDCravingEvent.timestamp, ascending: false)]

        return (try? context.fetch(request)) ?? []
    }

    func cravingCount(for addiction: CDAddiction, context: NSManagedObjectContext) -> Int {
        let request: NSFetchRequest<CDCravingEvent> = CDCravingEvent.fetchRequest()
        request.predicate = NSPredicate(format: "addiction == %@", addiction)
        return (try? context.count(for: request)) ?? 0
    }

    func survivedCount(for addiction: CDAddiction, context: NSManagedObjectContext) -> Int {
        let request: NSFetchRequest<CDCravingEvent> = CDCravingEvent.fetchRequest()
        request.predicate = NSPredicate(format: "addiction == %@ AND survived == YES", addiction)
        return (try? context.count(for: request)) ?? 0
    }

    // Get cravings for a specific date range
    func cravings(for addiction: CDAddiction, from: Date, to: Date, context: NSManagedObjectContext) -> [CDCravingEvent] {
        let request: NSFetchRequest<CDCravingEvent> = CDCravingEvent.fetchRequest()
        request.predicate = NSPredicate(format: "addiction == %@ AND timestamp >= %@ AND timestamp <= %@",
                                         addiction, from as NSDate, to as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDCravingEvent.timestamp, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    // Get craving dates for calendar heatmap
    func cravingDateMap(for addiction: CDAddiction, context: NSManagedObjectContext) -> [Date: Bool] {
        let cravings = fetchCravings(for: addiction, context: context)
        var map: [Date: Bool] = [:]

        for craving in cravings {
            if let timestamp = craving.timestamp {
                let day = Calendar.current.startOfDay(for: timestamp)
                // If any craving on that day was not survived, mark as relapse day
                if let existing = map[day] {
                    map[day] = existing && craving.survived
                } else {
                    map[day] = craving.survived
                }
            }
        }
        return map
    }
}
