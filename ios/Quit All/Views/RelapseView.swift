import SwiftUI
import CoreData

// MARK: - Relapse View
// No shame. No red. Just understanding and restart.
struct RelapseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let addiction: CDAddiction

    @State private var selectedActivity: RelapseActivity?
    @State private var selectedMood: Mood?
    @State private var nextTimePlan = ""
    @State private var currentStep = 0
    @State private var isComplete = false

    private var addictionType: AddictionType {
        AddictionTracker.shared.addictionType(for: addiction)
    }

    private var streakBroken: Int {
        StreakEngine.daysSince(addiction.startDate)
    }

    var body: some View {
        ZStack {
            Color(hex: "080808").ignoresSafeArea()

            VStack {
                // Close button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if isComplete {
                    restartView
                } else {
                    Group {
                        switch currentStep {
                        case 0: acknowledgmentStep
                        case 1: activityStep
                        case 2: moodStep
                        case 3: planStep
                        default: EmptyView()
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Step 0: Acknowledgment
    private var acknowledgmentStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Okay. That happened.")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "F5E6A3"))

            if streakBroken > 0 {
                Text("Your streak of \(streakBroken) days is saved in history.")
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Text("Let's understand what happened.")
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(.white.opacity(0.35))

            Spacer()

            Button {
                HapticManager.shared.impact(.medium)
                withAnimation(.spring(duration: 0.3)) {
                    currentStep = 1
                }
            } label: {
                Text("CONTINUE")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundColor(Color(hex: "D4AF37"))
                    .tracking(1.5)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "111111"))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Step 1: What were you doing?
    private var activityStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)

            Text("What were you doing\nbefore it happened?")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "F5E6A3"))
                .multilineTextAlignment(.center)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(RelapseActivity.allCases, id: \.self) { activity in
                    activityButton(activity)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            if selectedActivity != nil {
                nextButton { currentStep = 2 }
            }

            Spacer().frame(height: 32)
        }
    }

    private func activityButton(_ activity: RelapseActivity) -> some View {
        Button {
            HapticManager.shared.selection()
            selectedActivity = activity
        } label: {
            VStack(spacing: 6) {
                Text(activity.emoji)
                    .font(.title2)
                Text(activity.rawValue)
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(selectedActivity == activity ? .black : .white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(selectedActivity == activity ? Color(hex: "D4AF37") : Color(hex: "111111"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedActivity == activity ? Color(hex: "D4AF37") : Color(hex: "D4AF37").opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - Step 2: How are you feeling?
    private var moodStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            Text("How are you feeling\nright now?")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "F5E6A3"))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    moodButton(mood)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            if selectedMood != nil {
                nextButton { currentStep = 3 }
            }

            Spacer().frame(height: 32)
        }
    }

    private func moodButton(_ mood: Mood) -> some View {
        Button {
            HapticManager.shared.selection()
            selectedMood = mood
        } label: {
            VStack(spacing: 6) {
                Text(mood.emoji)
                    .font(.system(size: 36))
                Text(mood.rawValue)
                    .font(.caption)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selectedMood == mood ? Color(hex: "D4AF37").opacity(0.2) : Color(hex: "111111"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedMood == mood ? Color(hex: "D4AF37").opacity(0.6) : Color(hex: "D4AF37").opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - Step 3: What will you do differently?
    private var planStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            Text("What will you do\ndifferently next time?")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "F5E6A3"))
                .multilineTextAlignment(.center)

            TextField("Type here...", text: $nextTimePlan, axis: .vertical)
                .foregroundColor(.white)
                .lineLimit(3...6)
                .padding()
                .background(Color(hex: "111111"))
                .cornerRadius(12)
                .padding(.horizontal, 20)

            Spacer()

            Button {
                HapticManager.shared.impact(.heavy)
                saveRelapse()
            } label: {
                Text("SAVE & START OVER")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .tracking(1.5)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient(colors: [Color(hex: "D4AF37").opacity(0.8), Color(hex: "8B6914")], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // MARK: - Shared Next Button
    private func nextButton(action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.impact(.medium)
            withAnimation(.spring(duration: 0.3)) { action() }
        } label: {
            Text("NEXT")
                .font(.system(size: 14, weight: .bold, design: .serif))
                .foregroundColor(.white)
                .tracking(1.5)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(LinearGradient(colors: [Color(hex: "D4AF37").opacity(0.8), Color(hex: "8B6914")], startPoint: .top, endPoint: .bottom))
                .cornerRadius(16)
        }
        .padding(.horizontal, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Restart View
    private var restartView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(addictionType.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)

            Text("New streak begins now.")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "F5E6A3"))

            Text("You're not starting from zero.\nYou're starting from experience.")
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("LET'S GO")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .tracking(1.5)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient(colors: [Color(hex: "D4AF37").opacity(0.8), Color(hex: "8B6914")], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Save
    private func saveRelapse() {
        AddictionTracker.shared.logRelapse(
            for: addiction,
            whatHappened: selectedActivity?.rawValue ?? "",
            feeling: selectedMood?.rawValue ?? "",
            nextTimePlan: nextTimePlan,
            context: viewContext
        )

        withAnimation(.spring(duration: 0.5)) {
            isComplete = true
        }
    }
}
