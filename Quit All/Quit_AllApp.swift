import SwiftUI
import CoreData

@main
struct Quit_AllApp: App {
    let persistenceController = PersistenceController.shared

    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var showPaywall = false

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
            .onAppear {
                // Check trial/subscription status on every launch
                PaywallManager.shared.checkTrialStatus()

                // If onboarding done but no access (trial expired + no subscription), show paywall
                if hasCompletedOnboarding && !PaywallManager.shared.hasAccess {
                    showPaywall = true
                }

                // Listen for StoreKit transaction updates
                Task { await PaywallManager.shared.listenForTransactions() }
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView {
                    showPaywall = false
                }
            }
        }
    }
}
