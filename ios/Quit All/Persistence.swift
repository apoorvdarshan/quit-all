import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Create sample addiction for previews
        let addiction = CDAddiction(context: viewContext)
        addiction.id = UUID()
        addiction.name = "Smoking"
        addiction.type = AddictionType.smoking.rawValue
        addiction.startDate = Calendar.current.date(byAdding: .day, value: -47, to: Date())
        addiction.dailyCost = 15.0
        addiction.currency = Locale.current.currency?.identifier ?? "USD"
        addiction.isActive = true
        addiction.longestStreak = 47
        addiction.totalRelapses = 2
        addiction.motivation = "For my health and family"

        // Create sample craving events
        for i in 0..<5 {
            let craving = CDCravingEvent(context: viewContext)
            craving.id = UUID()
            craving.timestamp = Calendar.current.date(byAdding: .day, value: -i, to: Date())
            craving.trigger = CravingTrigger.allCases.randomElement()?.rawValue ?? "Stress"
            craving.survived = i > 0
            craving.duration = Int32.random(in: 60...600)
            craving.moodBefore = Mood.allCases.randomElement()?.rawValue ?? "Okay"
            craving.moodAfter = Mood.allCases.randomElement()?.rawValue ?? "Good"
            craving.addiction = addiction
        }

        // Create sample milestone
        let milestone = CDMilestone(context: viewContext)
        milestone.id = UUID()
        milestone.type = MilestoneType.thirtyDays.rawValue
        milestone.unlockedDate = Calendar.current.date(byAdding: .day, value: -17, to: Date())
        milestone.addiction = addiction

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    /// One model instance per process. Several containers (the app, previews,
    /// unit tests) must share it, or Core Data cannot map the CD* classes to a
    /// single entity description.
    private static let managedObjectModel: NSManagedObjectModel = {
        guard let url = Bundle.main.url(forResource: "Quit_All", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Missing Core Data model Quit_All.momd")
        }
        return model
    }()

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Quit_All", managedObjectModel: Self.managedObjectModel)
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else if let testStoreURL = AppTestEnvironment.storeURL {
            // Debug simulator UI tests only; see AppTestEnvironment.
            try? FileManager.default.createDirectory(
                at: testStoreURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            container.persistentStoreDescriptions.first!.url = testStoreURL
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
