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

    private func resetAllData() {
        let request: NSFetchRequest<NSFetchRequestResult> = CDAddiction.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try viewContext.execute(deleteRequest)
            try viewContext.save()
        } catch {
            print("Reset error: \(error)")
        }

        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        NotificationManager.shared.removeAllNotifications()
    }
}
