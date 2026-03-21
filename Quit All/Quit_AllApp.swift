import SwiftUI
import CoreData

@main
struct Quit_AllApp: App {
    let persistenceController = PersistenceController.shared

    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var showRelapse = false
    @State private var relapseAddiction: CDAddiction?

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
            .sheet(isPresented: $showRelapse) {
                if let addiction = relapseAddiction {
                    RelapseView(addiction: addiction)
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showRelapseView)) { notification in
                if let addiction = notification.object as? CDAddiction {
                    relapseAddiction = addiction
                    // Small delay to let SOS dismiss first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showRelapse = true
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
