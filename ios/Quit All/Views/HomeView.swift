import SwiftUI
import CoreData
import Combine

// MARK: - Home Dashboard View
struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var updateChecker = AppUpdateChecker.shared

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \CDAddiction.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \CDAddiction.startDate, ascending: true)
        ],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default
    ) private var addictions: FetchedResults<CDAddiction>

    @State private var selectedAddiction: CDAddiction?
    @State private var showSOS = false
    @State private var showMilestones = false
    @State private var showCost = false
    @State private var showMemes = false
    @State private var showRelapse = false
    @State private var relapseAddiction: CDAddiction?
    @State private var streakTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // Force refresh to update streak display
    @State private var refreshID = UUID()

    var body: some View {
        TabView {
            dashboardTab
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            statsTab
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }

            SettingsView(showsDoneButton: false)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .badge(updateChecker.isUpdateAvailable ? Text("") : nil)
        }
        .tint(Color(hex: "D4AF37"))
        .preferredColorScheme(.dark)
        .task {
            await updateChecker.checkForUpdate()
        }
    }

    private var dashboardTab: some View {
        NavigationStack {
            ZStack {
                Color(hex: "080808").ignoresSafeArea()

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

    @ViewBuilder
    private var statsTab: some View {
        if let addiction = selectedAddiction ?? addictions.first {
            StatsView(addiction: addiction, showsDoneButton: false)
        } else {
            NavigationStack {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "D4AF37").opacity(0.7))
                    Text("No stats yet")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                    Text("Add a habit to start tracking progress.")
                        .font(.system(size: 14, design: .serif))
                        .foregroundColor(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "080808"))
                .navigationTitle("Stats")
                .navigationBarTitleDisplayMode(.inline)
            }
            .preferredColorScheme(.dark)
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
                        VStack(spacing: 5) {
                            Image(type.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                            Text(addiction.name ?? "")
                                .font(.system(size: 11, weight: .semibold, design: .serif))
                                .foregroundColor(isSelected ? Color(hex: "D4AF37") : .white.opacity(0.7))
                                .textCase(.uppercase)
                                .tracking(0.5)
                            Text("\(StreakEngine.daysSince(addiction.startDate))d")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(type.color)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isSelected ? Color(hex: "1A1608") : Color(hex: "111111"))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? Color(hex: "D4AF37").opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
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
                    .stroke(Color(hex: "1A1A1A"), lineWidth: 10)
                    .frame(width: 260, height: 260)

                // Subtle track
                Circle()
                    .stroke(Color(hex: "D4AF37").opacity(0.08), lineWidth: 10)
                    .frame(width: 260, height: 260)

                // Progress ring — gold gradient
                Circle()
                    .trim(from: 0, to: progress.progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "D4AF37"), Color(hex: "F5E6A3"), Color(hex: "D4AF37")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 260, height: 260)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color(hex: "D4AF37").opacity(0.4), radius: 8)
                    .animation(.spring(duration: 1.0), value: progress.progress)

                // Streak number
                VStack(spacing: 4) {
                    Text(streak.value)
                        .font(.system(size: 92, weight: .black, design: .serif))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "F5E6A3"), Color(hex: "D4AF37"), Color(hex: "C5962C")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .contentTransition(.numericText())
                        .shadow(color: Color(hex: "D4AF37").opacity(0.3), radius: 12)

                    Text("\(streak.unit) clean from \(addiction.name?.lowercased() ?? "")")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(1)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: 200)
                }
            }
            .onTapGesture {
                HapticManager.shared.selection()
                showMilestones = true
            }

            // Stats row
            HStack(spacing: 24) {
                statBadge(iconName: "icon_money_saved", value: CostCalculator.formatCurrency(moneySaved, currencyCode: addiction.currency), label: "Saved")
                    .onTapGesture {
                        HapticManager.shared.selection()
                        showCost = true
                    }

                if hoursSaved > 0 {
                    statBadge(iconName: "icon_life_saved", value: CostCalculator.formatHoursSaved(hoursSaved), label: "Life saved")
                }

                statBadge(iconName: "icon_calendar", value: formatCleanSince(addiction.startDate), label: "Clean since")
            }
            .padding(.horizontal, 20)

            // Next milestone hint
            if let nextMilestone = progress.nextMilestone {
                Text("Next: \(nextMilestone.title)")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(Color(hex: "D4AF37").opacity(0.6))
                    .tracking(0.5)
                    .padding(.top, 4)
            }

            Spacer()
        }
    }

    private func statBadge(iconName: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 26)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "F5E6A3"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .serif))
                .foregroundColor(.white.opacity(0.35))
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(hex: "111111"))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "D4AF37").opacity(0.1), lineWidth: 1)
        )
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
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .tracking(2)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "8B0000"), Color(hex: "5C0000")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(hex: "8B0000").opacity(0.5), radius: 16, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(hex: "D4AF37").opacity(0.3), lineWidth: 1)
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
            .shadow(color: Color(hex: "8B0000").opacity(isPulsing ? 0.6 : 0.15), radius: isPulsing ? 24 : 8, y: 4)
            .animation(
                .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
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
