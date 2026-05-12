import SwiftUI
import RevenueCat

// MARK: - Hard Paywall — RevenueCat
struct PaywallView: View {
    let onComplete: () -> Void

    @State private var selectedProductId: String = SubscriptionProduct.yearly.rawValue
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var trialEligibleProductIDs = Set<String>()

    private let gold = Color(hex: "D4AF37")
    private let lightGold = Color(hex: "F5E6A3")
    private let premiumFeatures = [
        PaywallFeature(icon: "bolt.heart.fill", text: "SOS craving video loops"),
        PaywallFeature(icon: "chart.bar.fill", text: "Advanced stats"),
        PaywallFeature(icon: "trophy.fill", text: "Shareable milestones"),
        PaywallFeature(icon: "dollarsign.circle.fill", text: "Savings calculator"),
        PaywallFeature(icon: "bell.fill", text: "Smart danger reminders"),
        PaywallFeature(icon: "arrow.counterclockwise", text: "Relapse tracking"),
        PaywallFeature(icon: "face.smiling.fill", text: "2,790+ motivational memes")
    ]

    var body: some View {
        ZStack {
            Color(hex: "080808").ignoresSafeArea()

            GeometryReader { proxy in
                let isCompact = proxy.size.height < 760
                let isVeryCompact = proxy.size.height < 700

                VStack(spacing: isVeryCompact ? 7 : (isCompact ? 9 : 12)) {
                    paywallHeader(isCompact: isCompact, isVeryCompact: isVeryCompact)

                    featuresGrid(isCompact: isCompact)

                    subscriptionPlans(isCompact: isCompact, isVeryCompact: isVeryCompact)

                    purchaseButton(isCompact: isCompact)

                    billingInfo(isCompact: isCompact)

                    bottomLinks(isCompact: isCompact)
                }
                .padding(.horizontal, isCompact ? 14 : 20)
                .padding(.top, proxy.safeAreaInsets.top + (isVeryCompact ? 2 : 8))
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 8))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .task {
            await PaywallManager.shared.loadProducts()
            // Default select yearly
            // Default yearly selected — products may not load until RevenueCat returns an offering
            selectedProductId = SubscriptionProduct.yearly.rawValue

            // Check trial eligibility from RevenueCat
            var eligibleIDs = Set<String>()
            for package in PaywallManager.shared.packages {
                if await PaywallManager.shared.isEligibleForTrial(package) {
                    eligibleIDs.insert(package.storeProduct.productIdentifier)
                }
            }
            trialEligibleProductIDs = eligibleIDs
        }
    }

    // MARK: - Helpers

    private func paywallHeader(isCompact: Bool, isVeryCompact: Bool) -> some View {
        VStack(spacing: isVeryCompact ? 4 : 7) {
            Image("app_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: isVeryCompact ? 38 : 48, height: isVeryCompact ? 38 : 48)

            VStack(spacing: isVeryCompact ? 2 : 5) {
                Text(selectedProductIsTrialEligible ? "START YOUR FREE TRIAL" : "UNLOCK EVERYTHING")
                    .font(.system(size: isCompact ? 10 : 11, weight: .bold, design: .serif))
                    .foregroundColor(gold)
                    .tracking(2.5)
                    .lineLimit(1)

                Text(selectedProductIsTrialEligible ? "Try Free for 3 Days" : "Go Premium")
                    .font(.system(size: isVeryCompact ? 27 : (isCompact ? 31 : 36), weight: .bold, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: selectedProductIsTrialEligible ? [lightGold, gold, Color(hex: "C5962C")] : [lightGold, gold],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("Unlock every feature in Quit All.")
                    .font(.system(size: isCompact ? 12 : 14, design: .serif))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func featuresGrid(isCompact: Bool) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: isCompact ? 6 : 8),
                GridItem(.flexible(), spacing: isCompact ? 6 : 8)
            ],
            spacing: isCompact ? 6 : 8
        ) {
            ForEach(premiumFeatures) { feature in
                featurePill(feature, isCompact: isCompact)
            }
        }
    }

    private func featurePill(_ feature: PaywallFeature, isCompact: Bool) -> some View {
        HStack(spacing: isCompact ? 5 : 7) {
            Image(systemName: feature.icon)
                .font(.system(size: isCompact ? 9 : 10, weight: .bold))
                .foregroundColor(gold)
                .frame(width: isCompact ? 16 : 18, height: isCompact ? 16 : 18)

            Text(localized(feature.text))
                .font(.system(size: isCompact ? 10 : 11, weight: .medium, design: .serif))
                .foregroundColor(.white.opacity(0.72))
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, isCompact ? 7 : 9)
        .frame(height: isCompact ? 31 : 36)
        .background(Color(hex: "111111"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func subscriptionPlans(isCompact: Bool, isVeryCompact: Bool) -> some View {
        VStack(spacing: isVeryCompact ? 7 : 9) {
            subscriptionCard(
                title: "LIFETIME",
                price: formattedPrice(for: SubscriptionProduct.lifetime.rawValue, fallback: "$99.99 one-time"),
                subtitle: "One-time purchase",
                badge: "FOREVER",
                isSelected: selectedProductId == SubscriptionProduct.lifetime.rawValue,
                isCompact: isCompact
            ) {
                selectProduct(id: SubscriptionProduct.lifetime.rawValue)
            }

            subscriptionCard(
                title: "YEARLY",
                price: formattedPrice(for: SubscriptionProduct.yearly.rawValue, fallback: "$49.99/year"),
                subtitle: yearlySubtitle,
                badge: "SAVE 58%",
                isSelected: selectedProductId == SubscriptionProduct.yearly.rawValue,
                isCompact: isCompact
            ) {
                selectProduct(id: SubscriptionProduct.yearly.rawValue)
            }

            subscriptionCard(
                title: "MONTHLY",
                price: formattedPrice(for: SubscriptionProduct.monthly.rawValue, fallback: "$9.99/month"),
                subtitle: "Billed monthly",
                badge: nil,
                isSelected: selectedProductId == SubscriptionProduct.monthly.rawValue,
                isCompact: isCompact
            ) {
                selectProduct(id: SubscriptionProduct.monthly.rawValue)
            }
        }
    }

    private func purchaseButton(isCompact: Bool) -> some View {
        Button {
            Task { await purchase() }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(purchaseButtonTitle)
                        .font(.system(size: isCompact ? 13 : 15, weight: .bold, design: .serif))
                        .tracking(1.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? 50 : 56)
            .background(
                LinearGradient(
                    colors: [gold, Color(hex: "8B6914")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(15)
            .shadow(color: gold.opacity(0.34), radius: 12, y: 4)
        }
        .disabled(isPurchasing)
    }

    private func billingInfo(isCompact: Bool) -> some View {
        VStack(spacing: 3) {
            Text(billingLine)
                .font(.system(size: isCompact ? 10 : 11, weight: .medium, design: .serif))
                .foregroundColor(.white.opacity(0.34))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let error = PaywallManager.shared.purchaseError {
                Text(error)
                    .font(.system(size: isCompact ? 10 : 11, design: .serif))
                    .foregroundColor(Color(hex: "8B0000"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(height: isCompact ? 27 : 32)
    }

    private var billingLine: String {
        if selectedProductId == SubscriptionProduct.lifetime.rawValue {
            return localized("One-time purchase. No renewal.")
        }
        if selectedProductIsTrialEligible {
            return localized("3 days free, then auto-renews. Cancel anytime in Settings.")
        }
        return localized("Cancel anytime in iPhone Settings.")
    }

    private func bottomLinks(isCompact: Bool) -> some View {
        HStack(spacing: 10) {
            Button {
                Task { await restore() }
            } label: {
                HStack(spacing: 5) {
                    if isRestoring {
                        ProgressView().tint(gold.opacity(0.5)).scaleEffect(0.7)
                    }
                    Text("Restore")
                        .font(.system(size: isCompact ? 10 : 11, weight: .medium, design: .serif))
                        .foregroundColor(gold.opacity(0.45))
                        .lineLimit(1)
                }
            }
            .disabled(isRestoring)

            Spacer(minLength: 6)

            Link("Privacy", destination: URL(string: "https://quit-all.com/privacy")!)
            Text("|").foregroundColor(.white.opacity(0.12))
            Link("Terms", destination: URL(string: "https://quit-all.com/terms")!)
        }
        .font(.system(size: isCompact ? 10 : 11, design: .serif))
        .foregroundColor(.white.opacity(0.24))
        .frame(height: isCompact ? 18 : 22)
    }

    private var selectedProductIsTrialEligible: Bool {
        trialEligibleProductIDs.contains(selectedProductId)
    }

    private var purchaseButtonTitle: String {
        if selectedProductId == SubscriptionProduct.lifetime.rawValue {
            return localized("BUY LIFETIME")
        }
        return localized(selectedProductIsTrialEligible ? "START FREE TRIAL" : "SUBSCRIBE NOW")
    }

    private var yearlySubtitle: String {
        if let product = PaywallManager.shared.yearlyPackage {
            let monthly = product.storeProduct.price / 12
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = product.storeProduct.currencyCode
            let monthlyStr = formatter.string(from: monthly as NSDecimalNumber) ?? "$4.17"
            return "\(monthlyStr)/month — best value"
        }
        return "$4.17/month — best value"
    }

    private func formattedPrice(for productId: String, fallback: String) -> String {
        guard let product = PaywallManager.shared.package(for: productId) else {
            return fallback
        }
        if product.storeProduct.productIdentifier == SubscriptionProduct.lifetime.rawValue {
            return "\(product.localizedPriceString) \(localized("one-time"))"
        }
        let period = product.storeProduct.productIdentifier.contains("yearly") ? "/year" : "/month"
        return "\(product.localizedPriceString)\(period)"
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(gold)
                .frame(width: 22, height: 22)
                .background(gold.opacity(0.1))
                .cornerRadius(6)
            Text(localized(text))
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(.white.opacity(0.75))
        }
    }

    private func subscriptionCard(title: String, price: String, subtitle: String, badge: String?, isSelected: Bool, isCompact: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: isCompact ? 2 : 3) {
                    HStack(spacing: 8) {
                        Text(localized(title))
                            .font(.system(size: isCompact ? 12 : 14, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                            .tracking(1)
                        if let badge = badge {
                            Text(localized(badge))
                                .font(.system(size: isCompact ? 8 : 10, weight: .bold, design: .serif))
                                .foregroundColor(.black)
                                .padding(.horizontal, isCompact ? 6 : 8)
                                .padding(.vertical, isCompact ? 2 : 3)
                                .background(gold)
                                .cornerRadius(6)
                        }
                    }
                    Text(price)
                        .font(.system(size: isCompact ? 11 : 13, design: .serif))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(localized(subtitle))
                        .font(.system(size: isCompact ? 10 : 12, design: .serif))
                        .foregroundColor(gold.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected ? gold : Color.white.opacity(0.15), lineWidth: 2)
                        .frame(width: isCompact ? 21 : 24, height: isCompact ? 21 : 24)
                    if isSelected {
                        Circle()
                            .fill(gold)
                            .frame(width: isCompact ? 12 : 14, height: isCompact ? 12 : 14)
                    }
                }
            }
            .padding(.horizontal, isCompact ? 12 : 16)
            .padding(.vertical, isCompact ? 9 : 12)
            .background(Color(hex: isSelected ? "1A1608" : "111111"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? gold.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private func selectProduct(id: String) {
        HapticManager.shared.selection()
        selectedProductId = id
    }

    private func purchase() async {
        guard let product = PaywallManager.shared.package(for: selectedProductId) else {
            PaywallManager.shared.purchaseError = "Products not available. Please try again."
            return
        }
        isPurchasing = true
        let success = await PaywallManager.shared.purchase(product)
        isPurchasing = false
        if success {
            HapticManager.shared.notification(.success)
            onComplete()
        }
    }

    private func restore() async {
        isRestoring = true
        await PaywallManager.shared.restorePurchases()
        isRestoring = false
        if PaywallManager.shared.hasAccess {
            HapticManager.shared.notification(.success)
            onComplete()
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PaywallFeature: Identifiable {
    let icon: String
    let text: String

    var id: String { text }
}
