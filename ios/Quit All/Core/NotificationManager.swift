import UserNotifications
import CoreData

// MARK: - Smart Notification Manager
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() async -> Bool {
        // Simulator tests never show the system permission prompt.
        guard !AppTestEnvironment.isActive else { return false }
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    // Schedule all smart notifications for an addiction
    func scheduleSmartNotifications(
        addictionName: String,
        addictionType: AddictionType,
        startDate: Date,
        context: NSManagedObjectContext
    ) async {
        guard !AppTestEnvironment.isActive else { return }

        // Remove existing notifications for this addiction
        let prefix = "quit_\(addictionType.rawValue)_"
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let toRemove = pending.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: toRemove)

        // Schedule milestone notifications
        await scheduleMilestoneNotifications(addictionName: addictionName, type: addictionType, startDate: startDate)

        // Schedule daily check-in
        await scheduleDailyCheckIn(addictionName: addictionName, type: addictionType)

        // Schedule pattern-based danger zone notifications
        await scheduleDangerZoneNotifications(addictionName: addictionName, type: addictionType, context: context)
    }

    private func scheduleMilestoneNotifications(addictionName: String, type: AddictionType, startDate: Date) async {
        let milestones: [(days: Int, message: String)] = [
            (3, "3 days clean. Your body has already started healing."),
            (7, "One full week! The worst withdrawal is behind you."),
            (14, "2 weeks. Your brain is rewiring right now."),
            (30, "30 DAYS! Habit officially broken."),
            (100, "TRIPLE DIGITS! 100 days clean."),
            (365, "ONE YEAR. You changed your life.")
        ]

        for milestone in milestones {
            guard let triggerDate = Calendar.current.date(byAdding: .day, value: milestone.days, to: startDate) else { continue }

            // Skip if milestone date is in the past
            guard triggerDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Quit All"
            content.body = "\(milestone.message) \(type.emoji)"
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "quit_\(type.rawValue)_milestone_\(milestone.days)",
                content: content,
                trigger: trigger
            )

            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private func scheduleDailyCheckIn(addictionName: String, type: AddictionType) async {
        let content = UNMutableNotificationContent()
        content.title = "Quit All"
        content.body = "Haven't checked in today. Everything okay? \(type.emoji)"
        content.sound = .default

        // Schedule for 8 PM daily
        var components = DateComponents()
        components.hour = 20
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "quit_\(type.rawValue)_daily_checkin",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    private func scheduleDangerZoneNotifications(addictionName: String, type: AddictionType, context: NSManagedObjectContext) async {
        // Analyze craving patterns to find danger hours
        let dangerHour = await findDangerHour(for: type, context: context)

        if let hour = dangerHour {
            let content = UNMutableNotificationContent()
            content.title = "Quit All"
            content.body = "This is your highest risk time. Stay sharp tonight. \(type.emoji)"
            content.sound = .default

            // Schedule 15 minutes before danger hour
            var components = DateComponents()
            components.hour = hour > 0 ? hour - 1 : 23
            components.minute = 45

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: "quit_\(type.rawValue)_danger_zone",
                content: content,
                trigger: trigger
            )

            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private func findDangerHour(for type: AddictionType, context: NSManagedObjectContext) async -> Int? {
        await context.perform {
            let request: NSFetchRequest<CDCravingEvent> = CDCravingEvent.fetchRequest()
            request.predicate = NSPredicate(format: "addiction.type == %@", type.rawValue)

            guard let cravings = try? context.fetch(request), !cravings.isEmpty else { return nil }

            // Count cravings by hour
            var hourCounts: [Int: Int] = [:]
            for craving in cravings {
                if let timestamp = craving.timestamp {
                    let hour = Calendar.current.component(.hour, from: timestamp)
                    hourCounts[hour, default: 0] += 1
                }
            }

            return hourCounts.max(by: { $0.value < $1.value })?.key
        }
    }

    // Streak-aware notification: warn on previous relapse day
    func scheduleStreakWarning(addictionName: String, type: AddictionType, previousLongestStreak: Int, startDate: Date) async {
        guard previousLongestStreak > 7 else { return }

        let warningDay = previousLongestStreak
        guard let triggerDate = Calendar.current.date(byAdding: .day, value: warningDay, to: startDate) else { return }
        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Quit All"
        content.body = "You hit day \(warningDay) last time then relapsed on day \(warningDay + 1). Today is day \(warningDay). Be careful. \(type.emoji)"
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "quit_\(type.rawValue)_streak_warning",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
