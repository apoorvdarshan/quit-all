import SwiftUI
import CoreData

// MARK: - Addictions Management View
struct AddictionsView: View {
    var showsDoneButton: Bool = true

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \CDAddiction.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \CDAddiction.startDate, ascending: true)
        ],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default
    ) private var addictions: FetchedResults<CDAddiction>

    @State private var editingAddiction: CDAddiction?
    @State private var showAddNew = false

    private let gold = Color(hex: "D4AF37")
    private let lightGold = Color(hex: "F5E6A3")

    var body: some View {
        NavigationStack {
            List {
                ForEach(addictions) { addiction in
                    let type = AddictionTracker.shared.addictionType(for: addiction)
                    let days = StreakEngine.daysSince(addiction.startDate)

                    HStack(spacing: 12) {
                        Button {
                            editingAddiction = addiction
                        } label: {
                            HStack(spacing: 12) {
                                Image(type.iconName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 38, height: 38)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text((addiction.name ?? "").uppercased())
                                        .font(.system(size: 14, weight: .semibold, design: .serif))
                                        .foregroundColor(.white)
                                        .tracking(0.5)
                                    Text("\(days) days clean")
                                        .font(.system(size: 12, weight: .medium, design: .serif))
                                        .foregroundColor(gold.opacity(0.6))
                                }

                                Spacer()

                                if addiction.dailyCost > 0 {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(CostCalculator.formatCurrency(addiction.dailyCost, currencyCode: addiction.currency) + "/day")
                                            .font(.system(size: 11, design: .serif))
                                            .foregroundColor(.white.opacity(0.3))
                                        Text(CostCalculator.formatCurrency(
                                            CostCalculator.moneySaved(dailyCost: addiction.dailyCost, startDate: addiction.startDate),
                                            currencyCode: addiction.currency
                                        ))
                                        .font(.system(size: 14, weight: .bold, design: .serif))
                                        .foregroundColor(lightGold)
                                    }
                                }

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(gold.opacity(0.3))
                            }
                        }
                        .accessibilityIdentifier("habits.row.\(addiction.name ?? "")")
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            AddictionTracker.shared.deleteAddiction(addiction, context: viewContext)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                    .listRowBackground(
                        Color(hex: "111111")
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(gold.opacity(0.04), lineWidth: 0.5)
                            )
                    )
                }
                .onMove(perform: moveAddictions)
            }
            .scrollContentBackground(.hidden)
            .background(Color(hex: "080808"))
            .navigationTitle("My Addictions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(.system(size: 15, weight: .semibold, design: .serif))
                                .foregroundColor(gold)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showAddNew = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(gold)
                        }
                        .accessibilityIdentifier("habits.add")

                        Menu {
                            Button {
                                resetOrder()
                            } label: {
                                Label("Reset Order", systemImage: "arrow.counterclockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 15))
                                .foregroundColor(gold)
                        }
                    }
                }
            }
            .sheet(item: $editingAddiction) { addiction in
                EditAddictionView(addiction: addiction)
            }
            .sheet(isPresented: $showAddNew) {
                AddNewAddictionView(existingTypes: addictions.compactMap { AddictionTracker.shared.addictionType(for: $0) })
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

    private func resetOrder() {
        let sorted = addictions.sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
        for (index, item) in sorted.enumerated() {
            item.sortOrder = Int32(index)
        }
        AddictionTracker.shared.saveContext(viewContext)
        HapticManager.shared.notification(.success)
    }

    private func moveAddictions(from source: IndexSet, to destination: Int) {
        var items = Array(addictions)
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.sortOrder = Int32(index)
        }
        AddictionTracker.shared.saveContext(viewContext)
    }
}

// MARK: - Edit Addiction View
struct EditAddictionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let addiction: CDAddiction

    @State private var dailyCost: String = ""
    @State private var motivation: String = ""

    private let gold = Color(hex: "D4AF37")
    private let lightGold = Color(hex: "F5E6A3")

    private var addictionType: AddictionType {
        AddictionTracker.shared.addictionType(for: addiction)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "080808").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Image(addictionType.iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .padding(.top, 24)

                        Text((addiction.name ?? "").uppercased())
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundColor(lightGold)
                            .tracking(2)

                        // Daily spending
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DAILY SPENDING")
                                .font(.system(size: 11, weight: .semibold, design: .serif))
                                .foregroundColor(gold.opacity(0.6))
                                .tracking(1.5)

                            HStack {
                                Text(Locale.current.currencySymbol ?? "$")
                                    .font(.system(size: 16, design: .serif))
                                    .foregroundColor(gold.opacity(0.5))
                                TextField("0", text: $dailyCost)
                                    .keyboardType(.decimalPad)
                                    .foregroundColor(lightGold)
                                    .font(.system(size: 22, weight: .bold, design: .serif))
                                    .accessibilityIdentifier("editHabit.dailyCost")
                            }
                            .padding()
                            .background(Color(hex: "111111"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(gold.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 20)

                        // Motivation
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WHY YOU'RE QUITTING")
                                .font(.system(size: 11, weight: .semibold, design: .serif))
                                .foregroundColor(gold.opacity(0.6))
                                .tracking(1.5)

                            TextField("Your motivation...", text: $motivation)
                                .font(.system(size: 15, design: .serif))
                                .foregroundColor(.white.opacity(0.8))
                                .padding()
                                .background(Color(hex: "111111"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(gold.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 20)

                        // Quit date
                        VStack(alignment: .leading, spacing: 8) {
                            Text("QUIT DATE")
                                .font(.system(size: 11, weight: .semibold, design: .serif))
                                .foregroundColor(gold.opacity(0.6))
                                .tracking(1.5)

                            HStack {
                                Text(formatDate(addiction.startDate))
                                    .font(.system(size: 15, weight: .medium, design: .serif))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                Text("\(StreakEngine.daysSince(addiction.startDate)) days ago")
                                    .font(.system(size: 14, weight: .bold, design: .serif))
                                    .foregroundColor(gold.opacity(0.7))
                            }
                            .padding()
                            .background(Color(hex: "111111"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(gold.opacity(0.1), lineWidth: 1)
                            )
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
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 15, design: .serif))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveChanges()
                        dismiss()
                    } label: {
                        Text("Save")
                            .font(.system(size: 15, weight: .bold, design: .serif))
                            .foregroundColor(gold)
                    }
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

// MARK: - Add New Addiction View
struct AddNewAddictionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let existingTypes: [AddictionType]

    @State private var selectedType: AddictionType?
    @State private var dailyCost: String = ""
    @State private var motivation: String = ""
    @State private var startDate: Date = Date()

    private let gold = Color(hex: "D4AF37")
    private let lightGold = Color(hex: "F5E6A3")

    private var availableTypes: [AddictionType] {
        AddictionType.allCases.filter { !existingTypes.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "080808").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        if availableTypes.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(gold)
                                Text("You're tracking all addictions!")
                                    .font(.system(size: 16, weight: .medium, design: .serif))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.top, 60)
                        } else {
                            Text("CHOOSE ADDICTION")
                                .font(.system(size: 11, weight: .semibold, design: .serif))
                                .foregroundColor(gold.opacity(0.6))
                                .tracking(1.5)
                                .padding(.top, 20)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 12)], spacing: 12) {
                                ForEach(availableTypes) { type in
                                    Button {
                                        selectedType = type
                                        HapticManager.shared.selection()
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(type.iconName)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 36, height: 36)
                                            Text(type.localizedName)
                                                .font(.system(size: 11, weight: .medium, design: .serif))
                                                .foregroundColor(.white.opacity(0.8))
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color(hex: selectedType == type ? "1A1608" : "111111"))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedType == type ? gold.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
                                        )
                                    }
                                    .accessibilityIdentifier("addHabit.type.\(type.rawValue)")
                                }
                            }
                            .padding(.horizontal, 20)

                            if selectedType != nil {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("DAILY SPENDING")
                                        .font(.system(size: 11, weight: .semibold, design: .serif))
                                        .foregroundColor(gold.opacity(0.6))
                                        .tracking(1.5)

                                    HStack {
                                        Text("$")
                                            .font(.system(size: 16, design: .serif))
                                            .foregroundColor(gold.opacity(0.5))
                                        TextField("0", text: $dailyCost)
                                            .keyboardType(.decimalPad)
                                            .foregroundColor(lightGold)
                                            .font(.system(size: 22, weight: .bold, design: .serif))
                                            .accessibilityIdentifier("addHabit.dailyCost")
                                    }
                                    .padding()
                                    .background(Color(hex: "111111"))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(gold.opacity(0.1), lineWidth: 1)
                                    )
                                }
                                .padding(.horizontal, 20)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("QUIT DATE")
                                        .font(.system(size: 11, weight: .semibold, design: .serif))
                                        .foregroundColor(gold.opacity(0.6))
                                        .tracking(1.5)

                                    DatePicker("", selection: $startDate, in: ...Date(), displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .tint(gold)
                                        .padding()
                                        .background(Color(hex: "111111"))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(gold.opacity(0.1), lineWidth: 1)
                                        )
                                }
                                .padding(.horizontal, 20)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("WHY YOU'RE QUITTING")
                                        .font(.system(size: 11, weight: .semibold, design: .serif))
                                        .foregroundColor(gold.opacity(0.6))
                                        .tracking(1.5)

                                    TextField("Your motivation...", text: $motivation)
                                        .font(.system(size: 15, design: .serif))
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding()
                                        .background(Color(hex: "111111"))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(gold.opacity(0.1), lineWidth: 1)
                                        )
                                }
                                .padding(.horizontal, 20)

                                Button {
                                    addAddiction()
                                } label: {
                                    Text("ADD ADDICTION")
                                        .font(.system(size: 15, weight: .bold, design: .serif))
                                        .tracking(2)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 54)
                                        .background(
                                            LinearGradient(
                                                colors: [gold, Color(hex: "8B6914")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .cornerRadius(14)
                                        .shadow(color: gold.opacity(0.3), radius: 12, y: 4)
                                }
                                .padding(.horizontal, 20)
                            }

                            Spacer().frame(height: 40)
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .navigationTitle("Add Addiction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 15, design: .serif))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func addAddiction() {
        guard let type = selectedType else { return }
        let _ = AddictionTracker.shared.createAddiction(
            name: type.rawValue,
            type: type,
            startDate: startDate,
            dailyCost: Double(dailyCost) ?? 0,
            motivation: motivation,
            context: viewContext
        )
        HapticManager.shared.notification(.success)
        dismiss()
    }
}
