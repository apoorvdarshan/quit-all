import SwiftUI
import CoreData

// MARK: - SOS Craving Screen
// Full screen takeover with meme distraction + countdown + outcome logging.
struct SOSView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let addiction: CDAddiction

    @State private var phase: SOSPhase = .memes
    @State private var timerSeconds = 300  // 5 minute countdown
    @State private var timer: Timer?
    @State private var currentMemeIndex = 0
    @State private var memes: [MemeItem] = []
    @State private var selectedTrigger: CravingTrigger?
    @State private var showConfetti = false
    @State private var elapsedSeconds = 0

    private var addictionType: AddictionType {
        AddictionTracker.shared.addictionType(for: addiction)
    }

    enum SOSPhase {
        case memes
        case trigger
        case outcome
    }

    var body: some View {
        ZStack {
            Color(hex: "0A0A0A").ignoresSafeArea()

            VStack(spacing: 0) {
                header

                switch phase {
                case .memes:
                    memePhase
                case .trigger:
                    triggerPhase
                case .outcome:
                    outcomePhase
                }
            }

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { startSession() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Hold on")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(formatTime(timerSeconds))
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundColor(.white)
            }

            Spacer()

            Text(addictionType.emoji)
                .font(.title2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Phase 1: Memes
    private var memePhase: some View {
        VStack {
            TabView(selection: $currentMemeIndex) {
                ForEach(Array(memes.enumerated()), id: \.element.id) { index, meme in
                    VStack(spacing: 24) {
                        Spacer()

                        // Big emoji based on category
                        Text(meme.category.emoji)
                            .font(.system(size: 72))

                        Text(meme.text)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Text(meme.category.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundColor(addictionType.color)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(addictionType.color.opacity(0.15))
                            .cornerRadius(20)

                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            Text("Swipe for more")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
                .padding(.bottom, 8)

            Button {
                HapticManager.shared.impact(.medium)
                withAnimation(.spring(duration: 0.4)) {
                    phase = .trigger
                }
            } label: {
                Text("I'm ready to check in")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(addictionType.color)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Phase 2: What triggered this?
    private var triggerPhase: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("What triggered this craving?")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(CravingTrigger.allCases, id: \.self) { trigger in
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(duration: 0.2)) {
                            selectedTrigger = trigger
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(trigger.emoji)
                            Text(trigger.rawValue)
                                .font(.subheadline)
                        }
                        .foregroundColor(selectedTrigger == trigger ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedTrigger == trigger ? addictionType.color : Color(hex: "141414"))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            if selectedTrigger != nil {
                Button {
                    HapticManager.shared.impact(.medium)
                    withAnimation(.spring(duration: 0.4)) {
                        phase = .outcome
                    }
                } label: {
                    Text("Did you make it?")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(addictionType.color)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer().frame(height: 32)
        }
    }

    // MARK: - Phase 3: Outcome
    private var outcomePhase: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Did you make it through?")
                .font(.title.weight(.bold))
                .foregroundColor(.white)

            Text("Be honest. No judgment.")
                .font(.subheadline)
                .foregroundColor(.gray)

            HStack(spacing: 16) {
                Button {
                    HapticManager.shared.cravingSurvived()
                    handleOutcome(survived: true)
                } label: {
                    VStack(spacing: 8) {
                        Text("✅")
                            .font(.system(size: 48))
                        Text("YES")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                        Text("I made it")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                }

                Button {
                    HapticManager.shared.relapse()
                    handleOutcome(survived: false)
                } label: {
                    VStack(spacing: 8) {
                        Text("😔")
                            .font(.system(size: 48))
                        Text("NO")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                        Text("I gave in")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .background(Color(hex: "141414"))
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Logic

    private func startSession() {
        memes = MemeLibrary.shared.randomMemes(for: addictionType, count: 15)

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timerSeconds > 0 {
                timerSeconds -= 1
            }
            elapsedSeconds += 1
        }
    }

    private func handleOutcome(survived: Bool) {
        CravingLogger.shared.logCraving(
            addiction: addiction,
            trigger: selectedTrigger ?? .other,
            survived: survived,
            duration: elapsedSeconds,
            context: viewContext
        )

        if survived {
            showConfetti = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        } else {
            dismiss()
            NotificationCenter.default.post(name: .showRelapseView, object: addiction)
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, color: Color, size: CGFloat, rotation: Double)] = []

    var body: some View {
        GeometryReader { geo in
            ForEach(particles, id: \.id) { particle in
                RoundedRectangle(cornerRadius: 2)
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size * 1.5)
                    .rotationEffect(.degrees(particle.rotation))
                    .position(x: particle.x, y: particle.y)
            }
        }
        .onAppear { generateConfetti() }
    }

    private func generateConfetti() {
        let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]
        let w = UIScreen.main.bounds.width

        for i in 0..<50 {
            let startX = CGFloat.random(in: 0...w)
            particles.append((
                id: i,
                x: startX,
                y: -20,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...12),
                rotation: Double.random(in: 0...360)
            ))

            withAnimation(.interpolatingSpring(stiffness: 20, damping: 5).delay(Double(i) * 0.02)) {
                particles[i].y = CGFloat.random(in: 200...UIScreen.main.bounds.height)
                particles[i].rotation += Double.random(in: 180...720)
            }
        }
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let showRelapseView = Notification.Name("showRelapseView")
}
