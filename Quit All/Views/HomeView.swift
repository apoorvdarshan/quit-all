import SwiftUI
import CoreData
import Combine

// MARK: - Home Dashboard View
struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDAddiction.startDate, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default
    ) private var addictions: FetchedResults<CDAddiction>

    @State private var selectedAddiction: CDAddiction?
    @State private var showSOS = false
    @State private var showStats = false
    @State private var showSettings = false
    @State private var showMilestones = false
    @State private var showCost = false
    @State private var showMemes = false
    @State private var showRelapse = false
    @State private var relapseAddiction: CDAddiction?
    @State private var streakTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // Force refresh to update streak display
    @State private var refreshID = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0A0A0A").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Multiple addiction cards (horizontal scroll)
                    if addictions.count > 1 {
                        multiAddictionCards
                    }

                    // Main streak display
                    if let addiction = selectedAddiction ?? addictions.first {
                        mainStreakDisplay(addiction)
                    }

                    Spacer()

                    // SOS Button
                    sosButton
                }
                .id(refreshID)
            }
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.gray)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showStats = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .onReceive(streakTimer) { _ in
                refreshID = UUID()
            }
            .onAppear {
                AddictionTracker.shared.loadActiveAddictions(context: viewContext)
                if selectedAddiction == nil {
                    selectedAddiction = addictions.first
                }
            }
            .fullScreenCover(isPresented: $showSOS) {
                if let addiction = selectedAddiction ?? addictions.first {
                    SOSView(addiction: addiction)
                }
            }
            .sheet(isPresented: $showStats) {
                if let addiction = selectedAddiction ?? addictions.first {
                    StatsView(addiction: addiction)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showMilestones) {
                if let addiction = selectedAddiction ?? addictions.first {
                    MilestonesView(addiction: addiction)
                }
            }
            .sheet(isPresented: $showCost) {
                if let addiction = selectedAddiction ?? addictions.first {
                    CostView(addiction: addiction)
                }
            }
            .sheet(isPresented: $showMemes) {
                MemeBrowseView()
            }
            .fullScreenCover(isPresented: $showRelapse) {
                if let addiction = relapseAddiction {
                    RelapseView(addiction: addiction)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showRelapseView)) { notification in
                if let addiction = notification.object as? CDAddiction {
                    relapseAddiction = addiction
                }
            }
            .onChange(of: showSOS) { _, isShowing in
                // When SOS dismisses and we have a pending relapse, show it
                if !isShowing && relapseAddiction != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showRelapse = true
                    }
                }
            }
            .onChange(of: showRelapse) { _, isShowing in
                if !isShowing {
                    relapseAddiction = nil
                }
            }
        }
    }

    // MARK: - Multi Addiction Cards
    private var multiAddictionCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(addictions) { addiction in
                    let type = AddictionTracker.shared.addictionType(for: addiction)
                    let isSelected = addiction == selectedAddiction

                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(duration: 0.3)) {
                            selectedAddiction = addiction
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(type.emoji)
                                .font(.title2)
                            Text(addiction.name ?? "")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.white)
                            Text("\(StreakEngine.daysSince(addiction.startDate))d")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(type.color)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(isSelected ? type.color.opacity(0.2) : Color(hex: "141414"))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? type.color : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    // MARK: - Main Streak Display
    private func mainStreakDisplay(_ addiction: CDAddiction) -> some View {
        let type = AddictionTracker.shared.addictionType(for: addiction)
        let streak = StreakEngine.formatStreak(startDate: addiction.startDate)
        let progress = StreakEngine.progressToNextMilestone(startDate: addiction.startDate)
        let moneySaved = CostCalculator.moneySaved(dailyCost: addiction.dailyCost, startDate: addiction.startDate)
        let hoursSaved = CostCalculator.hoursSaved(addictionType: type, dailyUnits: type.defaultDailyUnits, startDate: addiction.startDate)

        return VStack(spacing: 20) {
            Spacer()

            // Circular progress ring with streak number
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 12)
                    .frame(width: 260, height: 260)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress.progress)
                    .stroke(
                        type.color,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 260, height: 260)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 1.0), value: progress.progress)

                // Streak number
                VStack(spacing: 4) {
                    Text(streak.value)
                        .font(.system(size: 96, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())

                    Text("\(streak.unit) clean from \(addiction.name?.lowercased() ?? "")")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            .onTapGesture {
                HapticManager.shared.selection()
                showMilestones = true
            }

            // Stats row
            HStack(spacing: 24) {
                statBadge(emoji: "💰", value: CostCalculator.formatCurrency(moneySaved, currencyCode: addiction.currency), label: "Saved")
                    .onTapGesture {
                        HapticManager.shared.selection()
                        showCost = true
                    }

                if hoursSaved > 0 {
                    statBadge(emoji: "⏰", value: CostCalculator.formatHoursSaved(hoursSaved), label: "Life saved")
                }

                statBadge(emoji: "📅", value: formatCleanSince(addiction.startDate), label: "Clean since")
            }
            .padding(.horizontal, 20)

            // Next milestone hint
            if let nextMilestone = progress.nextMilestone {
                Text("Next: \(nextMilestone.title)")
                    .font(.caption)
                    .foregroundColor(type.color.opacity(0.8))
                    .padding(.top, 4)
            }

            Spacer()
        }
    }

    private func statBadge(emoji: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(.title3)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(hex: "141414"))
        .cornerRadius(12)
    }

    private func formatCleanSince(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    // MARK: - SOS Button
    private var sosButton: some View {
        Button {
            HapticManager.shared.sosButton()
            showSOS = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                Text("I'M CRAVING")
                    .font(.headline.weight(.bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.red)
                    .shadow(color: .red.opacity(0.4), radius: 12, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .pulsingAnimation()
    }
}

// MARK: - Pulsing Animation Modifier
struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.02 : 1.0)
            .animation(
                .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

extension View {
    func pulsingAnimation() -> some View {
        modifier(PulsingModifier())
    }
}
