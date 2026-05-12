import CoreData
import Foundation
import WidgetKit

enum WidgetSnapshotStore {
    static let appGroupIdentifier = "group.com.apoorvdarshan.quitall"
    static let snapshotKey = "quit_all_widget_snapshot"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static func refresh(context: NSManagedObjectContext, selectedAddiction: CDAddiction? = nil) {
        let request: NSFetchRequest<CDAddiction> = CDAddiction.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDAddiction.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \CDAddiction.startDate, ascending: true)
        ]

        guard let addictions = try? context.fetch(request),
              let primary = primaryAddiction(from: addictions, selectedAddiction: selectedAddiction) else {
            clear()
            return
        }

        let type = AddictionTracker.shared.addictionType(for: primary)
        let snapshot = WidgetSnapshot(
            addictionName: primary.name ?? type.rawValue,
            addictionType: type.rawValue,
            startDate: primary.startDate ?? Date(),
            dailyCost: primary.dailyCost,
            currencyCode: primary.currency ?? "USD",
            activeHabitCount: addictions.count,
            updatedAt: Date()
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clear() {
        defaults?.removeObject(forKey: snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func primaryAddiction(from addictions: [CDAddiction], selectedAddiction: CDAddiction?) -> CDAddiction? {
        guard let selectedAddiction else { return addictions.first }
        return addictions.first { $0.objectID == selectedAddiction.objectID } ?? addictions.first
    }
}

struct WidgetSnapshot: Codable {
    let addictionName: String
    let addictionType: String
    let startDate: Date
    let dailyCost: Double
    let currencyCode: String
    let activeHabitCount: Int
    let updatedAt: Date
}
