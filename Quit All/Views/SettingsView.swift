import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var showAddictions = false
    @State private var showResetAlert = false
    @State private var notificationsEnabled = true

    var body: some View {
        NavigationStack {
            List {
                // Addictions
                Section {
                    Button {
                        showAddictions = true
                    } label: {
                        HStack {
                            Label("My Addictions", systemImage: "list.bullet")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .foregroundColor(.white)
                    }
                } header: {
                    Text("Tracking")
                }
                .listRowBackground(Color(hex: "141414"))

                // Notifications
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Smart Notifications", systemImage: "bell.fill")
                    }
                    .tint(.green)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        if !newValue {
                            NotificationManager.shared.removeAllNotifications()
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Pattern-based reminders at your highest risk times")
                }
                .listRowBackground(Color(hex: "141414"))

                // About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                } header: {
                    Text("About")
                }
                .listRowBackground(Color(hex: "141414"))

                // Reset
                Section {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("Reset All Data", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                .listRowBackground(Color(hex: "141414"))
            }
            .scrollContentBackground(.hidden)
            .background(Color(hex: "0A0A0A"))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
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
        // Delete all addictions
        let request: NSFetchRequest<NSFetchRequestResult> = CDAddiction.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try viewContext.execute(deleteRequest)
            try viewContext.save()
        } catch {
            print("Reset error: \(error)")
        }

        // Clear user defaults
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")

        NotificationManager.shared.removeAllNotifications()
    }
}
