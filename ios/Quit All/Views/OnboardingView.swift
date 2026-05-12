import SwiftUI
import CoreData
import StoreKit

private enum OnboardingPreviewMedia: Identifiable {
    case remote(KlipyMediaItem)
    case local(LocalVideoLoop)

    var id: String {
        switch self {
        case .remote(let item):
            return item.id
        case .local(let loop):
            return loop.id
        }
    }

    var sourceLabel: String {
        switch self {
        case .remote:
            return "KLIPY"
        case .local:
            return "OFFLINE"
        }
    }
}

// MARK: - Onboarding Funnel View
struct OnboardingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var hasCompletedOnboarding: Bool

    // Flow state
    @State private var currentStep = 0  // 0-8
    @State private var selectedAddictions: Set<AddictionType> = []
    @State private var addictionCosts: [AddictionType: String] = [:]
    @State private var addictionMotivations: [AddictionType: String] = [:]
    @State private var addictionStartDates: [AddictionType: Date] = [:]
    @State private var currentDetailIndex = 0
    @State private var selectedCurrency = "USD"
    @State private var selectedSymptoms: Set<String> = []

    private let currencies = [
        ("USD", "$", "US Dollar"),
        ("EUR", "€", "Euro"),
        ("GBP", "£", "British Pound"),
        ("INR", "₹", "Indian Rupee"),
        ("CAD", "C$", "Canadian Dollar"),
        ("AUD", "A$", "Australian Dollar"),
        ("JPY", "¥", "Japanese Yen"),
        ("CNY", "¥", "Chinese Yuan"),
        ("BRL", "R$", "Brazilian Real"),
    ]
    @State private var featurePageIndex = 0
    @State private var onboardingPreviewMedia: [OnboardingPreviewMedia] = []
    @State private var onboardingPreviewLoadTask: Task<Void, Never>?
    @State private var isLoadingOnboardingPreview = false
    @State private var analysisProgress: Double = 0
    @State private var didRequestOnboardingReview = false
    @State private var showConfetti = false

    private let gold = Color(hex: "D4AF37")
    private let lightGold = Color(hex: "F5E6A3")
    private let totalSteps = 9
    private let onboardingPreviewCount = 4
    private let onboardingFallbackRecentKey = "onboarding_fallback_loop_recent_ids"

    private var sortedSelected: [AddictionType] {
        Array(selectedAddictions).sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        ZStack {
            Color(hex: "080808").ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                progressBar
                    .padding(.top, 8)

                // Steps
                Group {
                    switch currentStep {
                    case 0: quizStep
                    case 1: detailStep
                    case 2: analysisStep
                    case 3: symptomsStep
                    case 4: featuresStep
                    case 5: reviewsStep
                    case 6: planStep
                    case 7: ratingStep
                    case 8: paywallStep
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startOnboardingPreviewPreload()
        }
        .onChange(of: currentStep) { _, newStep in
            if newStep >= 1 {
                startOnboardingPreviewPreload()
            }
        }
        .onDisappear {
            onboardingPreviewLoadTask?.cancel()
            onboardingPreviewLoadTask = nil
        }
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 3)
                Rectangle()
                    .fill(
                        LinearGradient(colors: [gold, lightGold], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * CGFloat(currentStep + 1) / CGFloat(totalSteps), height: 3)
                    .animation(.spring(duration: 0.5), value: currentStep)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Gold CTA Button
    private func goldButton(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.impact(.medium)
            action()
        } label: {
            Text(localized(title))
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundColor(.white)
                .tracking(1.5)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: enabled ? [gold.opacity(0.9), Color(hex: "8B6914")] : [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .cornerRadius(16)
                .shadow(color: enabled ? gold.opacity(0.3) : .clear, radius: 12, y: 6)
        }
        .disabled(!enabled)
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }

    // MARK: - Step 0: Quiz — Addiction Selection
    private var quizStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 16)

            Image("app_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)

            Text("What are you\nquitting?")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundColor(lightGold)
                .multilineTextAlignment(.center)

            Text("SELECT ALL THAT APPLY")
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .foregroundColor(.white.opacity(0.3))
                .tracking(2)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(AddictionType.allCases, id: \.self) { type in
                        quizCard(type)
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()

            goldButton("CONTINUE", enabled: !selectedAddictions.isEmpty) {
                for type in selectedAddictions {
                    if addictionStartDates[type] == nil {
                        addictionStartDates[type] = Date()
                    }
                }
                withAnimation(.spring(duration: 0.4)) {
                    currentStep = 1
                    currentDetailIndex = 0
                }
            }
        }
    }

    private func quizCard(_ type: AddictionType) -> some View {
        let isSelected = selectedAddictions.contains(type)

        return Button {
            HapticManager.shared.selection()
            withAnimation(.spring(duration: 0.3)) {
                if isSelected { selectedAddictions.remove(type) }
                else { selectedAddictions.insert(type) }
            }
        } label: {
            VStack(spacing: 8) {
                Image(type.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                Text(type.localizedName.uppercased(with: Locale.current))
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundColor(isSelected ? lightGold : .white.opacity(0.5))
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(isSelected ? gold.opacity(0.12) : Color(hex: "111111"))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? gold.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Step 1: Detail Input
    private var detailStep: some View {
        let addictions = sortedSelected
        guard currentDetailIndex < addictions.count else { return AnyView(EmptyView()) }
        let type = addictions[currentDetailIndex]

        return AnyView(
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 20)

                        Image(type.iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 72, height: 72)

                        Text(String(format: localized("Quitting %@"), type.localizedName))
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundColor(lightGold)

                        VStack(alignment: .leading, spacing: 16) {
                            inputField(label: "DAILY SPENDING") {
                                HStack(spacing: 0) {
                                    // Currency symbol as dropdown
                                    Menu {
                                        ForEach(currencies, id: \.0) { code, symbol, name in
                                            Button {
                                                selectedCurrency = code
                                            } label: {
                                                HStack {
                                                    Text("\(symbol) \(localized(name))")
                                                    if selectedCurrency == code {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(currencies.first { $0.0 == selectedCurrency }?.1 ?? "$")
                                                .font(.system(size: 20, weight: .bold, design: .serif))
                                                .foregroundColor(gold)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(gold.opacity(0.5))
                                        }
                                        .padding(.trailing, 10)
                                    }

                                    // Amount input
                                    TextField("0", text: binding(for: type, in: $addictionCosts))
                                        .keyboardType(.decimalPad)
                                        .foregroundColor(lightGold)
                                        .font(.system(size: 22, weight: .bold, design: .serif))
                                }
                            }

                            inputField(label: "WHY ARE YOU QUITTING?") {
                                TextField("For my health, family...", text: binding(for: type, in: $addictionMotivations))
                                    .font(.system(size: 15, design: .serif))
                                    .foregroundColor(.white.opacity(0.8))
                            }

                            inputField(label: "WHEN DID YOU LAST DO IT?") {
                                DatePicker("", selection: dateBinding(for: type), in: ...Date(), displayedComponents: [.date])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .tint(gold)
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
                                if currentDetailIndex > 0 { currentDetailIndex -= 1 }
                                else { currentStep = 0 }
                            }
                        } label: {
                            Text("BACK")
                                .font(.system(size: 14, weight: .semibold, design: .serif))
                                .foregroundColor(gold)
                                .tracking(1)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(hex: "111111"))
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(gold.opacity(0.15), lineWidth: 1))
                        }
                    }

                    goldButton(currentDetailIndex == addictions.count - 1 ? "ANALYZE" : "NEXT") {
                        if currentDetailIndex < addictions.count - 1 {
                            withAnimation(.spring(duration: 0.3)) { currentDetailIndex += 1 }
                        } else {
                            saveAddictions()
                            withAnimation(.spring(duration: 0.4)) { currentStep = 2 }
                        }
                    }
                }
                .padding(.horizontal, currentDetailIndex > 0 || currentStep > 0 ? 20 : 0)
            }
        )
    }

    private func inputField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
                                Text(localized(label))
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .foregroundColor(gold.opacity(0.6))
                .tracking(1.5)

            content()
                .padding()
                .background(Color(hex: "111111"))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(gold.opacity(0.1), lineWidth: 1))
        }
    }

    // MARK: - Step 2: Analysis (fake loading)
    private var analysisStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("ANALYZING YOUR HABITS")
                .font(.system(size: 12, weight: .bold, design: .serif))
                .foregroundColor(gold)
                .tracking(3)

            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 6)
                    .frame(width: 160, height: 160)
                Circle()
                    .trim(from: 0, to: analysisProgress)
                    .stroke(
                        LinearGradient(colors: [gold, lightGold], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(analysisProgress * 100))%")
                    .font(.system(size: 40, weight: .black, design: .serif))
                    .foregroundColor(lightGold)
                    .contentTransition(.numericText())
            }

            VStack(spacing: 8) {
                let totalCost = selectedAddictions.reduce(0.0) { $0 + (Double(addictionCosts[$1] ?? "0") ?? 0) }

                Text("You spend \(CostCalculator.formatCurrency(totalCost * 30, currencyCode: selectedCurrency))/month")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(.white.opacity(analysisProgress > 0.5 ? 0.8 : 0))

                Text("That's \(CostCalculator.formatCurrency(totalCost * 365, currencyCode: selectedCurrency))/year you could save")
                    .font(.system(size: 14, design: .serif))
                    .foregroundColor(gold.opacity(analysisProgress > 0.8 ? 0.7 : 0))
            }
            .animation(.easeIn(duration: 0.3), value: analysisProgress)

            Spacer()
        }
        .onAppear { runAnalysis() }
    }

    private func runAnalysis() {
        analysisProgress = 0
        let steps = 30
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                withAnimation(.spring(duration: 0.2)) {
                    analysisProgress = Double(i) / Double(steps)
                }
                if i == steps {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(duration: 0.4)) { currentStep = 3 }
                    }
                }
            }
        }
    }

    // MARK: - Step 3: Symptoms
    private var symptomsStep: some View {
        let symptoms = ["Anxiety & stress", "Sleep problems", "Financial stress", "Relationship issues",
                        "Health concerns", "Guilt & shame", "Low energy", "Social pressure"]

        return VStack(spacing: 20) {
            Spacer().frame(height: 30)

            Text("Do you experience\nany of these?")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(lightGold)
                .multilineTextAlignment(.center)

            Text("SELECT ALL THAT APPLY")
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .foregroundColor(.white.opacity(0.3))
                .tracking(2)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(symptoms, id: \.self) { symptom in
                    let isSelected = selectedSymptoms.contains(symptom)
                    Button {
                        HapticManager.shared.selection()
                        if isSelected { selectedSymptoms.remove(symptom) }
                        else { selectedSymptoms.insert(symptom) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? gold : .white.opacity(0.2))
                            Text(localized(symptom))
                                .font(.system(size: 13, weight: .medium, design: .serif))
                                .foregroundColor(isSelected ? lightGold : .white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 14)
                        .background(isSelected ? gold.opacity(0.1) : Color(hex: "111111"))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? gold.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            goldButton("CONTINUE") {
                withAnimation(.spring(duration: 0.4)) { currentStep = 4 }
            }
        }
    }

    // MARK: - Step 4: Features
    private var featuresStep: some View {
        let features: [(icon: String, title: String, desc: String)] = [
            ("exclamationmark.triangle.fill", "SOS CRAVING BUTTON", "Klipy GIF loops and memes when urges hit. Swipe while the craving passes."),
            ("chart.bar.fill", "SMART TRACKING", "Know your triggers, danger times, and patterns. Your data reveals what works."),
            ("trophy.fill", "MILESTONE REWARDS", "Celebrate every win with health facts. Share your progress with shareable cards."),
            ("arrow.counterclockwise", "NO JUDGMENT", "Log relapses without shame. Restart instantly. Your streak history is always saved."),
        ]

        return VStack(spacing: 20) {
            Spacer().frame(height: 30)

            Text("How Quit All\nhelps you")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(lightGold)
                .multilineTextAlignment(.center)

            TabView(selection: $featurePageIndex) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    VStack(spacing: 20) {
                        Spacer()
                        onboardingGIFPreview(for: index)

                        Text(localized(feature.title))
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                            .tracking(2)

                        Text(localized(feature.desc))
                            .font(.system(size: 15, design: .serif))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            goldButton("CONTINUE") {
                withAnimation(.spring(duration: 0.4)) { currentStep = 5 }
            }
        }
        .onAppear {
            startOnboardingPreviewPreload()
        }
    }

    private func onboardingGIFPreview(for index: Int) -> some View {
        let media = onboardingPreviewMedia.indices.contains(index) ? onboardingPreviewMedia[index] : nil

        return ZStack(alignment: .topTrailing) {
            previewContent(for: media)

            if let sourceLabel = media?.sourceLabel {
                Text(sourceLabel)
                    .font(.system(size: 9, weight: .bold, design: .serif))
                    .foregroundColor(sourceLabel == "KLIPY" ? .black : .white.opacity(0.75))
                    .tracking(0.8)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(sourceLabel == "KLIPY" ? gold : Color.black.opacity(0.55))
                    .cornerRadius(10)
                    .padding(8)
            }
        }
        .frame(width: 240, height: 150)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(gold.opacity(0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func previewContent(for media: OnboardingPreviewMedia?) -> some View {
        if let media {
            switch media {
            case .remote(let item):
                RemoteGIFView(url: item.gifURL)
                    .frame(width: 240, height: 150)
                    .background(Color(hex: "111111"))
                    .clipped()
            case .local(let loop):
                LoopingVideoView(url: loop.url)
                    .frame(width: 240, height: 150)
                    .background(Color(hex: "111111"))
                    .clipped()
            }
        } else {
            loadingPreview
        }
    }

    private var loadingPreview: some View {
        VStack(spacing: 12) {
            if isLoadingOnboardingPreview {
                ProgressView()
                    .tint(gold)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundColor(gold)
            }
            Text("LOADING GIF PREVIEW")
                .font(.system(size: 10, weight: .bold, design: .serif))
                .foregroundColor(.white.opacity(0.45))
                .tracking(1.2)
        }
        .frame(width: 240, height: 150)
        .background(Color(hex: "111111"))
    }

    private func loadOnboardingPreviewGIF() async {
        guard onboardingPreviewMedia.isEmpty, !isLoadingOnboardingPreview else { return }

        isLoadingOnboardingPreview = true
        defer { isLoadingOnboardingPreview = false }

        let preferredTypes = sortedSelected.shuffled()
        let fallbackMedia = selectOnboardingFallbackLoops(preferredTypes: preferredTypes, count: onboardingPreviewCount)
        onboardingPreviewMedia = fallbackMedia

        let type = preferredTypes.randomElement() ?? .smoking
        let loops = await KlipyMediaLibrary.shared.searchLoops(for: type, count: onboardingPreviewCount * 2)
        guard !Task.isCancelled else { return }

        let remoteItems = Array(loops
            .shuffled()
            .prefix(onboardingPreviewCount))
        await RemoteGIFCache.shared.preload(urls: remoteItems.map(\.gifURL))
        guard !Task.isCancelled, currentStep < 4 else { return }

        let remoteMedia = remoteItems.map(OnboardingPreviewMedia.remote)
        onboardingPreviewMedia = Array((remoteMedia + fallbackMedia).prefix(onboardingPreviewCount))
    }

    private func startOnboardingPreviewPreload() {
        guard onboardingPreviewLoadTask == nil, onboardingPreviewMedia.isEmpty else { return }
        onboardingPreviewLoadTask = Task {
            await loadOnboardingPreviewGIF()
            await MainActor.run {
                onboardingPreviewLoadTask = nil
            }
        }
    }

    private func selectOnboardingFallbackLoops(preferredTypes: [AddictionType], count: Int) -> [OnboardingPreviewMedia] {
        guard count > 0 else { return [] }

        let recentIDs = UserDefaults.standard.stringArray(forKey: onboardingFallbackRecentKey) ?? []
        let loops = LocalVideoLoopLibrary.shared.randomLoops(
            preferredTypes: preferredTypes,
            count: count,
            excluding: Set(recentIDs)
        )

        let newIDs = loops.map(\.id)
        let updatedIDs = newIDs + recentIDs.filter { !newIDs.contains($0) }
        UserDefaults.standard.set(Array(updatedIDs.prefix(12)), forKey: onboardingFallbackRecentKey)

        return loops.map(OnboardingPreviewMedia.local)
    }

    // MARK: - Step 5: App Benefits
    private var reviewsStep: some View {
        let benefits: [(icon: String, title: String, detail: String)] = [
            ("bolt.heart.fill", "Fast help during cravings", "Open SOS mode, swipe through GIF loops, and ride out the urge one minute at a time."),
            ("chart.line.uptrend.xyaxis", "Real progress tracking", "See streaks, savings, milestones, and patterns from the habits you chose."),
            ("arrow.counterclockwise.circle.fill", "Relapse without shame", "Log a slip, keep your history, and restart with a clean plan immediately."),
            ("bell.badge.fill", "Smarter reminders", "Use notifications and danger-time prompts to stay ready before cravings peak."),
        ]

        return VStack(spacing: 20) {
            Spacer().frame(height: 30)

            Text("Built for the\nhard moments")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(lightGold)
                .multilineTextAlignment(.center)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(benefits, id: \.title) { benefit in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: benefit.icon)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(gold)
                                .frame(width: 30, height: 30)
                                .background(gold.opacity(0.1))
                                .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(localized(benefit.title))
                                    .font(.system(size: 15, weight: .bold, design: .serif))
                                    .foregroundColor(.white)

                                Text(localized(benefit.detail))
                                    .font(.system(size: 13, design: .serif))
                                    .foregroundColor(.white.opacity(0.58))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .background(Color(hex: "111111"))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(gold.opacity(0.08), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
            }

            goldButton("CONTINUE") {
                withAnimation(.spring(duration: 0.4)) { currentStep = 6 }
            }
        }
    }

    // MARK: - Step 6: Custom Plan
    private var planStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 30)

            Text("Your quit plan\nis ready")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(lightGold)
                .multilineTextAlignment(.center)

            ScrollView {
                VStack(spacing: 12) {
                    // Selected addictions summary
                    ForEach(sortedSelected, id: \.self) { type in
                        HStack(spacing: 12) {
                            Image(type.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.localizedName.uppercased(with: Locale.current))
                                    .font(.system(size: 13, weight: .bold, design: .serif))
                                    .foregroundColor(.white)
                                    .tracking(0.5)
                                let cost = Double(addictionCosts[type] ?? "0") ?? 0
                                if cost > 0 {
                                    Text("Saving \(CostCalculator.formatCurrency(cost, currencyCode: selectedCurrency))/day")
                                        .font(.system(size: 12, design: .serif))
                                        .foregroundColor(gold.opacity(0.6))
                                }
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(gold)
                        }
                        .padding(14)
                        .background(Color(hex: "111111"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)

                    // Timeline
                    VStack(alignment: .leading, spacing: 0) {
                        timelineItem(time: "DAY 1", text: "Withdrawal peaks. SOS button is your best friend.", isFirst: true)
                        timelineItem(time: "WEEK 1", text: "Worst is over. Your body is already healing.")
                        timelineItem(time: "MONTH 1", text: "Habit officially broken. Brain rewired.")
                        timelineItem(time: "YEAR 1", text: "You changed your life. Risk drops 50%.", isLast: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }

            goldButton("SEE MY PLAN") {
                withAnimation(.spring(duration: 0.4)) { currentStep = 7 }
            }
        }
    }

    private func timelineItem(time: String, text: String, isFirst: Bool = false, isLast: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle().fill(gold.opacity(0.2)).frame(width: 2, height: 12)
                }
                Circle().fill(gold).frame(width: 10, height: 10)
                if !isLast {
                    Rectangle().fill(gold.opacity(0.2)).frame(width: 2, height: 30)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(localized(time))
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .foregroundColor(gold)
                    .tracking(1)
                Text(localized(text))
                    .font(.system(size: 13, design: .serif))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, isFirst ? 0 : 4)
        }
    }

    // MARK: - Step 7: Native Rating
    private var ratingStep: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 32))
                            .foregroundColor(gold)
                    }
                }

                Text("How is Quit All\nso far?")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundColor(lightGold)
                    .multilineTextAlignment(.center)

                Text("A quick App Store rating helps more people find the app when they need it.")
                    .font(.system(size: 15, design: .serif))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
            }

            Spacer()

            Button {
                HapticManager.shared.impact(.medium)
                if didRequestOnboardingReview {
                    withAnimation(.spring(duration: 0.4)) { currentStep = 8 }
                } else {
                    requestOnboardingReview()
                    didRequestOnboardingReview = true
                }
            } label: {
                Text(didRequestOnboardingReview ? "CONTINUE" : "RATE QUIT ALL")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .tracking(1.5)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: [gold.opacity(0.9), Color(hex: "8B6914")], startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(16)
                    .shadow(color: gold.opacity(0.3), radius: 12, y: 6)
            }
            .padding(.horizontal, 20)

            Button {
                HapticManager.shared.selection()
                withAnimation(.spring(duration: 0.4)) { currentStep = 8 }
            } label: {
                Text("MAYBE LATER")
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundColor(gold.opacity(0.55))
                    .tracking(1.2)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Step 8: Paywall
    private var paywallStep: some View {
        PaywallView {
            HapticManager.shared.notification(.success)
            showConfetti = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                completeOnboarding()
            }
        }
    }

    private func requestOnboardingReview() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        SKStoreReviewController.requestReview(in: windowScene)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
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

            let addiction = AddictionTracker.shared.createAddiction(
                name: type.rawValue,
                type: type,
                startDate: startDate,
                dailyCost: cost,
                motivation: motivation,
                context: viewContext
            )
            addiction.currency = selectedCurrency
            AddictionTracker.shared.saveContext(viewContext)
        }
    }

    private func completeOnboarding() {
        Task {
            _ = await NotificationManager.shared.requestPermission()
            AddictionTracker.shared.loadActiveAddictions(context: viewContext)
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
        hasCompletedOnboarding = true
    }
}
