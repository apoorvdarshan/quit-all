import SwiftUI
import CoreData

@main
struct Quit_AllApp: App {
    let persistenceController = PersistenceController.shared

    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var showPaywall = false
    @State private var hasCheckedAccess = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    HomeView()
                } else {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .preferredColorScheme(.dark)
            .onReceive(NotificationCenter.default.publisher(for: .resetApp)) { _ in
                hasCompletedOnboarding = false
            }
            .task {
                // Listen for RevenueCat customer info updates.
                await PaywallManager.shared.listenForTransactions()
            }
            .onAppear {
                guard !hasCheckedAccess else { return }
                hasCheckedAccess = true

                // Check premium access on every launch.
                Task {
                    await PaywallManager.shared.checkEntitlements()

                    // If onboarding is done but premium is inactive, show the hard paywall.
                    if hasCompletedOnboarding && !PaywallManager.shared.hasAccess {
                        showPaywall = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView {
                    showPaywall = false
                }
            }
        }
    }
}
