import SwiftUI
import CoreData

// MARK: - SOS Craving Screen
// Full screen takeover with local video loops + countdown + trigger + outcome.
struct SOSView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let addiction: CDAddiction

    @State private var phase: SOSPhase = .memes
    @State private var timerSeconds = 300
    @State private var timer: Timer?
    @State private var currentMemeIndex = 0
    @State private var memes: [MemeItem] = []
    @State private var klipyLoops: [KlipyMediaItem] = []
    @State private var videoLoops: [LocalVideoLoop] = []
    @State private var klipyLoadTask: Task<Void, Never>?
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

    private let gold = Color(hex: "D4AF37")
    private let lightGold = Color(hex: "F5E6A3")
    private let darkRed = Color(hex: "8B0000")

    var body: some View {
        ZStack {
            Color(hex: "080808").ignoresSafeArea()

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
        .onDisappear {
            timer?.invalidate()
            klipyLoadTask?.cancel()
        }
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

            Image(addictionType.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Phase 1: Video Loop + Meme Distraction (TikTok-style swipe)
    private var memePhase: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentMemeIndex) {
                ForEach(Array(memes.enumerated()), id: \.element.id) { index, meme in
                    VStack(spacing: 16) {
                        Spacer()

                        mediaView(index: index, meme: meme)

                        // Meme text below
                        Text(meme.text)
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundColor(lightGold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Text(meme.category.localizedName.uppercased(with: Locale.current))
                            .font(.system(size: 11, weight: .semibold, design: .serif))
                            .foregroundColor(gold.opacity(0.7))
                            .tracking(1.5)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(gold.opacity(0.1))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(gold.opacity(0.2), lineWidth: 1)
                            )

                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            Text("SWIPE FOR MORE")
                .font(.system(size: 10, weight: .medium, design: .serif))
                .foregroundColor(gold.opacity(0.3))
                .tracking(1.5)
                .padding(.bottom, 8)

            Button {
                HapticManager.shared.impact(.medium)
                withAnimation(.spring(duration: 0.4)) {
                    phase = .trigger
                }
            } label: {
                Text("I'M READY TO CHECK IN")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .tracking(1.5)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(colors: [gold.opacity(0.8), Color(hex: "8B6914")], startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(gold.opacity(0.3), lineWidth: 1))
                    .shadow(color: gold.opacity(0.3), radius: 12, y: 6)
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
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(lightGold)

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
                            Text(trigger.localizedName)
                                .font(.system(size: 14, weight: .medium, design: .serif))
                        }
                        .foregroundColor(selectedTrigger == trigger ? .black : .white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedTrigger == trigger ? gold : Color(hex: "111111"))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedTrigger == trigger ? gold : gold.opacity(0.08), lineWidth: 1)
                        )
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
                    Text("DID YOU MAKE IT?")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .tracking(1.5)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(colors: [gold.opacity(0.8), Color(hex: "8B6914")], startPoint: .top, endPoint: .bottom)
                        )
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(gold.opacity(0.3), lineWidth: 1))
                        .shadow(color: gold.opacity(0.3), radius: 12, y: 6)
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
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundColor(lightGold)

            Text("Be honest. No judgment.")
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(.white.opacity(0.35))
                .tracking(0.5)

            HStack(spacing: 16) {
                Button {
                    HapticManager.shared.cravingSurvived()
                    handleOutcome(survived: true)
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 40))
                            .foregroundColor(gold)
                        Text("YES")
                            .font(.system(size: 18, weight: .black, design: .serif))
                            .foregroundColor(.white)
                            .tracking(2)
                        Text("I made it")
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .background(gold.opacity(0.1))
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(gold.opacity(0.4), lineWidth: 1)
                    )
                }

                Button {
                    HapticManager.shared.relapse()
                    handleOutcome(survived: false)
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "xmark.seal.fill")
                            .font(.system(size: 40))
                            .foregroundColor(darkRed)
                        Text("NO")
                            .font(.system(size: 18, weight: .black, design: .serif))
                            .foregroundColor(.white)
                            .tracking(2)
                        Text("I gave in")
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .background(Color(hex: "111111"))
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(darkRed.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Logic

    private func startSession() {
        memes = MemeLibrary.shared.randomMemes(for: addictionType, count: 15)
        videoLoops = LocalVideoLoopLibrary.shared.randomLoops(for: addictionType, count: 15)
        klipyLoops = []
        klipyLoadTask?.cancel()
        klipyLoadTask = Task {
            let remoteLoops = await KlipyMediaLibrary.shared.searchLoops(for: addictionType, count: 15)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                klipyLoops = remoteLoops
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timerSeconds > 0 {
                timerSeconds -= 1
            }
            elapsedSeconds += 1
        }
    }

    @ViewBuilder
    private func mediaView(index: Int, meme: MemeItem) -> some View {
        if index < klipyLoops.count {
            RemoteGIFView(url: klipyLoops[index].gifURL)
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .background(Color(hex: "111111"))
                .cornerRadius(16)
                .overlay(alignment: .topTrailing) {
                    sourceBadge("KLIPY")
                }
                .clipped()
                .padding(.horizontal, 20)
        } else if index < videoLoops.count {
            LoopingVideoView(url: videoLoops[index].url)
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .background(Color(hex: "111111"))
                .cornerRadius(16)
                .overlay(alignment: .topTrailing) {
                    sourceBadge("OFFLINE")
                }
                .clipped()
                .padding(.horizontal, 20)
        } else {
            Text(meme.category.emoji)
                .font(.system(size: 72))
        }
    }

    private func sourceBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .serif))
            .foregroundColor(text == "KLIPY" ? .black : .white.opacity(0.75))
            .tracking(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(text == "KLIPY" ? gold : Color.black.opacity(0.55))
            .cornerRadius(10)
            .padding(8)
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

// MARK: - Notification Names
extension Notification.Name {
    static let showRelapseView = Notification.Name("showRelapseView")
    static let resetApp = Notification.Name("resetApp")
}
