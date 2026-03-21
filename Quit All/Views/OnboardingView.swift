import SwiftUI
import CoreData

// MARK: - Onboarding View
struct OnboardingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var hasCompletedOnboarding: Bool

    @State private var currentStep = 0
    @State private var selectedAddictions: Set<AddictionType> = []
    @State private var addictionCosts: [AddictionType: String] = [:]
    @State private var addictionMotivations: [AddictionType: String] = [:]
    @State private var addictionStartDates: [AddictionType: Date] = [:]
    @State private var currentDetailIndex = 0

    private var sortedSelected: [AddictionType] {
        Array(selectedAddictions).sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        ZStack {
            Color(hex: "0A0A0A").ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar

                switch currentStep {
                case 0:
                    addictionSelectionStep
                case 1:
                    detailInputStep
                default:
                    EmptyView()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        let totalSteps = 1 + sortedSelected.count
        let currentProgress = currentStep == 0 ? 0 : currentDetailIndex + 1

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: geo.size.width * CGFloat(currentProgress) / CGFloat(max(1, totalSteps)), height: 4)
                    .animation(.spring(duration: 0.4), value: currentProgress)
            }
        }
        .frame(height: 4)
        .padding(.top, 8)
    }

    // MARK: - Step 1: Select Addictions
    private var addictionSelectionStep: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            Text("What are you quitting?")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Select all that apply")
                .font(.subheadline)
                .foregroundColor(.gray)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(AddictionType.allCases, id: \.self) { type in
                        addictionCard(type)
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()

            Button {
                HapticManager.shared.impact(.medium)
                guard !selectedAddictions.isEmpty else { return }
                for type in selectedAddictions {
                    if addictionStartDates[type] == nil {
                        addictionStartDates[type] = Date()
                    }
                }
                withAnimation(.spring(duration: 0.4)) {
                    currentStep = 1
                    currentDetailIndex = 0
                }
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedAddictions.isEmpty ? Color.gray : Color.white)
                    .cornerRadius(16)
            }
            .disabled(selectedAddictions.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    private func addictionCard(_ type: AddictionType) -> some View {
        let isSelected = selectedAddictions.contains(type)

        return Button {
            HapticManager.shared.selection()
            withAnimation(.spring(duration: 0.3)) {
                if isSelected {
                    selectedAddictions.remove(type)
                } else {
                    selectedAddictions.insert(type)
                }
            }
        } label: {
            VStack(spacing: 8) {
                Text(type.emoji)
                    .font(.system(size: 36))
                Text(type.rawValue)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(isSelected ? type.color.opacity(0.3) : Color(hex: "141414"))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? type.color : Color.clear, lineWidth: 2)
            )
        }
    }

    // MARK: - Step 2: Details per addiction
    private var detailInputStep: some View {
        let addictions = sortedSelected
        guard currentDetailIndex < addictions.count else {
            return AnyView(EmptyView())
        }
        let type = addictions[currentDetailIndex]

        return AnyView(
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 40)

                        Text(type.emoji)
                            .font(.system(size: 60))

                        Text("Quitting \(type.rawValue)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 16) {
                            // Cost input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("How much do you spend per day?")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)

                                HStack {
                                    Text(Locale.current.currencySymbol ?? "$")
                                        .foregroundColor(.gray)
                                    TextField("0", text: binding(for: type, in: $addictionCosts))
                                        .keyboardType(.decimalPad)
                                        .foregroundColor(.white)
                                        .font(.title2.weight(.semibold))
                                }
                                .padding()
                                .background(Color(hex: "141414"))
                                .cornerRadius(12)
                            }

                            // Motivation input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Why are you quitting?")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)

                                TextField("For my health, family...", text: binding(for: type, in: $addictionMotivations))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color(hex: "141414"))
                                    .cornerRadius(12)
                            }

                            // Last use date
                            VStack(alignment: .leading, spacing: 8) {
                                Text("When did you last do it?")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)

                                DatePicker("", selection: dateBinding(for: type), in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .tint(type.color)
                                    .padding()
                                    .background(Color(hex: "141414"))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer().frame(height: 20)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

                HStack(spacing: 12) {
                    if currentDetailIndex > 0 || currentStep > 0 {
                        Button {
                            HapticManager.shared.selection()
                            withAnimation(.spring(duration: 0.3)) {
                                if currentDetailIndex > 0 {
                                    currentDetailIndex -= 1
                                } else {
                                    currentStep = 0
                                }
                            }
                        } label: {
                            Text("Back")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(hex: "141414"))
                                .cornerRadius(16)
                        }
                    }

                    Button {
                        HapticManager.shared.impact(.medium)
                        if currentDetailIndex < addictions.count - 1 {
                            withAnimation(.spring(duration: 0.3)) {
                                currentDetailIndex += 1
                            }
                        } else {
                            saveAddictions()
                        }
                    } label: {
                        Text(currentDetailIndex == addictions.count - 1 ? "Start My Journey" : "Next")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(type.color)
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        )
    }

    // MARK: - Helpers

    private func binding(for type: AddictionType, in dict: Binding<[AddictionType: String]>) -> Binding<String> {
        Binding(
            get: { dict.wrappedValue[type] ?? "" },
            set: { dict.wrappedValue[type] = $0 }
        )
    }

    private func dateBinding(for type: AddictionType) -> Binding<Date> {
        Binding(
            get: { addictionStartDates[type] ?? Date() },
            set: { addictionStartDates[type] = $0 }
        )
    }

    private func saveAddictions() {
        for type in selectedAddictions {
            let cost = Double(addictionCosts[type] ?? "0") ?? 0
            let motivation = addictionMotivations[type] ?? ""
            let startDate = addictionStartDates[type] ?? Date()

            _ = AddictionTracker.shared.createAddiction(
                name: type.rawValue,
                type: type,
                startDate: startDate,
                dailyCost: cost,
                motivation: motivation,
                context: viewContext
            )
        }

        // Request notification permission
        Task {
            _ = await NotificationManager.shared.requestPermission()
            let addictions = AddictionTracker.shared.activeAddictions
            for addiction in addictions {
                let aType = AddictionTracker.shared.addictionType(for: addiction)
                await NotificationManager.shared.scheduleSmartNotifications(
                    addictionName: addiction.name ?? "",
                    addictionType: aType,
                    startDate: addiction.startDate ?? Date(),
                    context: viewContext
                )
            }
        }

        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.spring(duration: 0.5)) {
            hasCompletedOnboarding = true
        }
    }
}
