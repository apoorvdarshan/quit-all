import Foundation
import CoreData

// MARK: - Addiction Tracker
// Central manager for all addiction CRUD operations.
@Observable
final class AddictionTracker {
    static let shared = AddictionTracker()

    var activeAddictions: [CDAddiction] = []

    private init() {}

    // MARK: - CRUD Operations

    func loadActiveAddictions(context: NSManagedObjectContext) {
        let request: NSFetchRequest<CDAddiction> = CDAddiction.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDAddiction.startDate, ascending: true)]

        do {
            activeAddictions = try context.fetch(request)
        } catch {
            activeAddictions = []
        }
    }

    func createAddiction(
        name: String,
        type: AddictionType,
        startDate: Date,
        dailyCost: Double,
        motivation: String,
        context: NSManagedObjectContext
    ) -> CDAddiction {
        let addiction = CDAddiction(context: context)
        addiction.id = UUID()
        addiction.name = name
        addiction.type = type.rawValue
        addiction.startDate = startDate
        addiction.dailyCost = dailyCost
        addiction.currency = Locale.current.currency?.identifier ?? "USD"
        addiction.isActive = true
        addiction.longestStreak = 0
        addiction.totalRelapses = 0
        addiction.motivation = motivation

        saveContext(context)
        return addiction
    }

    func deleteAddiction(_ addiction: CDAddiction, context: NSManagedObjectContext) {
        context.delete(addiction)
        saveContext(context)
        loadActiveAddictions(context: context)
    }

    func updateLongestStreak(for addiction: CDAddiction, context: NSManagedObjectContext) {
        let currentStreak = streakDays(for: addiction)
        if currentStreak > addiction.longestStreak {
            addiction.longestStreak = Int32(currentStreak)
            saveContext(context)
        }
    }

    // MARK: - Streak Calculations

    func streakDays(for addiction: CDAddiction) -> Int {
        guard let startDate = addiction.startDate else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return max(0, days)
    }

    func streakHours(for addiction: CDAddiction) -> Int {
        guard let startDate = addiction.startDate else { return 0 }
        let hours = Calendar.current.dateComponents([.hour], from: startDate, to: Date()).hour ?? 0
        return max(0, hours)
    }

    // MARK: - Relapse

    func logRelapse(
        for addiction: CDAddiction,
        whatHappened: String,
        feeling: String,
        nextTimePlan: String,
        context: NSManagedObjectContext
    ) {
        let currentStreak = streakDays(for: addiction)

        // Update longest streak if needed
        if currentStreak > addiction.longestStreak {
            addiction.longestStreak = Int32(currentStreak)
        }

        // Create relapse event
        let relapse = CDRelapseEvent(context: context)
        relapse.id = UUID()
        relapse.timestamp = Date()
        relapse.streakBroken = Int32(currentStreak)
        relapse.whatHappened = whatHappened
        relapse.feeling = feeling
        relapse.nextTimePlan = nextTimePlan
        relapse.addiction = addiction

        // Increment total relapses
        addiction.totalRelapses += 1

        // Reset streak — new start date is now
        addiction.startDate = Date()

        saveContext(context)
    }

    // MARK: - Helpers

    func addictionType(for addiction: CDAddiction) -> AddictionType {
        AddictionType(rawValue: addiction.type ?? "") ?? .custom
    }

    func saveContext(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("Save error: \(nsError), \(nsError.userInfo)")
        }
    }
}
