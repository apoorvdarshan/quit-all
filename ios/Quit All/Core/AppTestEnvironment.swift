import CoreData
import Foundation

/// Deterministic test mode for simulator tests.
///
/// Only Debug simulator builds can enter it: in Release builds and builds for a
/// device `isActive` is always false, so production behavior is unchanged.
///
/// - Unit tests: the app hosts the test bundle (detected from XCTest's environment).
/// - UI tests: the app is launched with `--ui-testing` plus the optional flags below.
///
/// In test mode the app never configures RevenueCat (so nothing can be bought),
/// never checks the App Store for updates, never fetches KLIPY GIFs (SOS uses the
/// bundled offline loops) and never asks for notification permission.
enum AppTestEnvironment {
    static let uiTestingArgument = "--ui-testing"
    /// Start from an empty UI-test store and cleared app defaults.
    static let resetArgument = "--ui-testing-reset"
    /// Mark onboarding as finished.
    static let onboardedArgument = "--ui-testing-onboarded"
    /// Simulate an active premium entitlement. No StoreKit or RevenueCat is involved.
    static let premiumArgument = "--ui-testing-premium"
    /// Insert Smoking (10 days clean, $15/day) and Caffeine (3 days clean, $5/day).
    static let seedHabitsArgument = "--ui-testing-seed-habits"

    static var isActive: Bool {
        isUITesting || isHostingUnitTests
    }

    static var isUITesting: Bool {
        #if DEBUG && targetEnvironment(simulator)
        return CommandLine.arguments.contains(uiTestingArgument)
        #else
        return false
        #endif
    }

    static var isHostingUnitTests: Bool {
        #if DEBUG && targetEnvironment(simulator)
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
        #else
        return false
        #endif
    }

    /// The premium entitlement a UI test asked for; never true outside UI tests.
    static var grantsPremium: Bool {
        isUITesting && CommandLine.arguments.contains(premiumArgument)
    }

    /// UI tests keep their Core Data store apart from a developer's own simulator data.
    static var storeURL: URL? {
        guard isUITesting,
              let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return support
            .appendingPathComponent("UITesting", isDirectory: true)
            .appendingPathComponent("Quit_All.sqlite")
    }

    /// Applies the UI-test launch flags. Called before the app reads any state.
    static func prepareLaunch() {
        #if DEBUG && targetEnvironment(simulator)
        _ = launchPreparation
        #endif
    }

    #if DEBUG && targetEnvironment(simulator)
    private static let launchPreparation: Void = {
        guard isUITesting else { return }
        let arguments = CommandLine.arguments
        let defaults = UserDefaults.standard

        if arguments.contains(resetArgument) {
            // Simulator Debug build only: clears this app's defaults and the
            // UI-test store, never a device, a Release build or other apps.
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                defaults.removePersistentDomain(forName: bundleIdentifier)
            }
            if let storeDirectory = storeURL?.deletingLastPathComponent() {
                try? FileManager.default.removeItem(at: storeDirectory)
            }
        }
        if arguments.contains(onboardedArgument) {
            defaults.set(true, forKey: "hasCompletedOnboarding")
        }
        if arguments.contains(seedHabitsArgument) {
            seedHabits(in: PersistenceController.shared.container.viewContext)
        }
    }()

    /// Seeds two habits with fixed ages relative to `now`. Does nothing if habits exist.
    static func seedHabits(in context: NSManagedObjectContext, now: Date = Date()) {
        let request: NSFetchRequest<CDAddiction> = CDAddiction.fetchRequest()
        let existing = (try? context.count(for: request)) ?? 0
        guard existing == 0 else { return }

        let seeds: [(type: AddictionType, days: Double, dailyCost: Double, motivation: String)] = [
            (.smoking, 10, 15, "For my health"),
            (.caffeine, 3, 5, "Better sleep"),
        ]
        for seed in seeds {
            // Two extra hours keep the day counts stable for the whole test run.
            let startDate = now.addingTimeInterval(-(seed.days * 86_400 + 2 * 3_600))
            _ = AddictionTracker.shared.createAddiction(
                name: seed.type.rawValue,
                type: seed.type,
                startDate: startDate,
                dailyCost: seed.dailyCost,
                motivation: seed.motivation,
                context: context
            )
        }
    }
    #endif
}
