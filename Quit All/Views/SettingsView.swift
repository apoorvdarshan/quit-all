import SwiftUI
import CoreData

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var showAddictions = false
    @State private var showResetAlert = false
    @State private var notificationsEnabled = true

    private let gold = Color(hex: "D4AF37")

    var body: some View {
        NavigationStack {
            List {
                // Addictions
                Section {
                    Button {
                        showAddictions = true
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet")
                                .foregroundColor(gold)
                            Text("My Addictions")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(gold.opacity(0.4))
                        }
                    }
                } header: {
                    Text("TRACKING")
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(gold.opacity(0.6))
                        .tracking(1.5)
                }
                .listRowBackground(Color(hex: "111111"))

                // Notifications
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(gold)
                            Text("Smart Notifications")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                        }
                    }
                    .tint(gold)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        if !newValue {
                            NotificationManager.shared.removeAllNotifications()
                        }
                    }
                } header: {
                    Text("NOTIFICATIONS")
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(gold.opacity(0.6))
                        .tracking(1.5)
                } footer: {
                    Text("Pattern-based reminders at your highest risk times")
                        .font(.system(size: 12, design: .serif))
                        .foregroundColor(.white.opacity(0.3))
                }
                .listRowBackground(Color(hex: "111111"))

                // Subscription
                Section {
                    Button {
                        manageSubscription()
                    } label: {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(gold)
                            Text("Manage Subscription")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(gold.opacity(0.4))
                        }
                    }

                    Button {
                        Task { await PaywallManager.shared.restorePurchases() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(gold)
                            Text("Restore Purchases")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundColor(.white)
                        }
                    }
                } header: {
                    Text("SUBSCRIPTION")
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(gold.opacity(0.6))
                        .tracking(1.5)
                }
                .listRowBackground(Color(hex: "111111"))

                // About
                Section {
                    HStack {
                        Text("Version")
                            .font(.system(size: 15, weight: .medium, design: .serif))
                        Spacer()
                        Text("1.0.0")
                            .font(.system(size: 14, design: .serif))
                            .foregroundColor(gold.opacity(0.5))
                    }

                    Link(destination: URL(string: "https://quit-all.com/privacy")!) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(gold)
                            Text("Privacy Policy")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(gold.opacity(0.4))
                        }
                    }

                    Link(destination: URL(string: "https://quit-all.com/terms")!) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(gold)
                            Text("Terms of Service")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(gold.opacity(0.4))
                        }
                    }
                } header: {
                    Text("ABOUT")
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(gold.opacity(0.6))
                        .tracking(1.5)
                }
                .listRowBackground(Color(hex: "111111"))

                // Reset
                Section {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(Color(hex: "8B0000"))
                            Text("Reset All Data")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundColor(Color(hex: "8B0000"))
                        }
                    }
                }
                .listRowBackground(Color(hex: "111111"))
            }
            .scrollContentBackground(.hidden)
            .background(Color(hex: "080808"))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundColor(gold)
                    }
                }
            }
            .sheet(isPresented: $showAddictions) {
                AddictionsView()
            }
            .alert("Reset All Data?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This will permanently delete all your tracking data, streaks, and history. This cannot be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func manageSubscription() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    private func resetAllData() {
        // Delete all addictions (cascades to cravings, relapses, milestones)
        let request: NSFetchRequest<CDAddiction> = CDAddiction.fetchRequest()
        if let addictions = try? viewContext.fetch(request) {
            for addiction in addictions {
                viewContext.delete(addiction)
            }
        }

        // Delete any orphaned entities
        let entities: [NSFetchRequest<NSFetchRequestResult>] = [
            CDCravingEvent.fetchRequest(),
            CDRelapseEvent.fetchRequest(),
            CDMilestone.fetchRequest()
        ]
        for req in entities {
            if let objects = try? viewContext.fetch(req) as? [NSManagedObject] {
                for obj in objects { viewContext.delete(obj) }
            }
        }

        try? viewContext.save()

        // Clear all UserDefaults
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "isSubscribed")
        NotificationManager.shared.removeAllNotifications()

        // Force app back to onboarding
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .resetApp, object: nil)
        }
    }
}
