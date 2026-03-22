import SwiftUI
import CoreData

@main
struct Quit_AllApp: App {
    let persistenceController = PersistenceController.shared

    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

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
                withAnimation(.spring(duration: 0.4)) {
                    hasCompletedOnboarding = false
                }
            }
        }
    }
}
