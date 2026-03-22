import SwiftUI
import CoreData

// MARK: - Addictions Management View
struct AddictionsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDAddiction.startDate, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default
    ) private var addictions: FetchedResults<CDAddiction>

    @State private var editingAddiction: CDAddiction?

    var body: some View {
        NavigationStack {
            List {
                ForEach(addictions) { addiction in
                    let type = AddictionTracker.shared.addictionType(for: addiction)
                    let days = StreakEngine.daysSince(addiction.startDate)

                    Button {
                        editingAddiction = addiction
                    } label: {
                        HStack(spacing: 12) {
                            Image(type.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(addiction.name ?? "")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("\(days) days clean")
                                    .font(.caption)
                                    .foregroundColor(type.color)
                            }

                            Spacer()

                            if addiction.dailyCost > 0 {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(CostCalculator.formatCurrency(addiction.dailyCost, currencyCode: addiction.currency) + "/day")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(CostCalculator.formatCurrency(
                                        CostCalculator.moneySaved(dailyCost: addiction.dailyCost, startDate: addiction.startDate),
                                        currencyCode: addiction.currency
                                    ))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.green)
                                }
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .listRowBackground(Color(hex: "141414"))
                }
                .onDelete(perform: deleteAddictions)
            }
            .scrollContentBackground(.hidden)
            .background(Color(hex: "0A0A0A"))
            .navigationTitle("My Addictions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(item: $editingAddiction) { addiction in
                EditAddictionView(addiction: addiction)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func deleteAddictions(at offsets: IndexSet) {
        for index in offsets {
            let addiction = addictions[index]
            AddictionTracker.shared.deleteAddiction(addiction, context: viewContext)
        }
    }
}

// MARK: - Edit Addiction View
struct EditAddictionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let addiction: CDAddiction

    @State private var dailyCost: String = ""
    @State private var motivation: String = ""

    private var addictionType: AddictionType {
        AddictionTracker.shared.addictionType(for: addiction)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0A0A0A").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        Image(addictionType.iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 72, height: 72)
                            .padding(.top, 20)

                        Text(addiction.name ?? "")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)

                        // Daily spending
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Daily spending")
                                .font(.subheadline)
                                .foregroundColor(.gray)

                            HStack {
                                Text(Locale.current.currencySymbol ?? "$")
                                    .foregroundColor(.gray)
                                TextField("0", text: $dailyCost)
                                    .keyboardType(.decimalPad)
                                    .foregroundColor(.white)
                                    .font(.title2.weight(.semibold))
                            }
                            .padding()
                            .background(Color(hex: "141414"))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)

                        // Motivation
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Why you're quitting")
                                .font(.subheadline)
                                .foregroundColor(.gray)

                            TextField("Your motivation...", text: $motivation)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color(hex: "141414"))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)

                        // Quit date (read only display)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quit date")
                                .font(.subheadline)
                                .foregroundColor(.gray)

                            HStack {
                                Text(formatDate(addiction.startDate))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(StreakEngine.daysSince(addiction.startDate)) days ago")
                                    .foregroundColor(addictionType.color)
                            }
                            .padding()
                            .background(Color(hex: "141414"))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)

                        Spacer().frame(height: 40)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                dailyCost = addiction.dailyCost > 0 ? String(format: "%.0f", addiction.dailyCost) : ""
                motivation = addiction.motivation ?? ""
            }
        }
        .preferredColorScheme(.dark)
    }

    private func saveChanges() {
        addiction.dailyCost = Double(dailyCost) ?? 0
        addiction.motivation = motivation
        AddictionTracker.shared.saveContext(viewContext)
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
