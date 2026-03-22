import SwiftUI
import StoreKit

// MARK: - Hard Paywall — Native StoreKit Trial
struct PaywallView: View {
    let onComplete: () -> Void

    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var isTrialEligible = false

    private let gold = Color(hex: "D4AF37")
    private let lightGold = Color(hex: "F5E6A3")

    var body: some View {
        ZStack {
            Color(hex: "080808").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    Image("app_logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)

                    VStack(spacing: 10) {
                        if isTrialEligible {
                            Text("START YOUR FREE TRIAL")
                                .font(.system(size: 12, weight: .bold, design: .serif))
                                .foregroundColor(gold)
                                .tracking(3)

                            Text("Try Free\nfor 3 Days")
                                .font(.system(size: 38, weight: .bold, design: .serif))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [lightGold, gold, Color(hex: "C5962C")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .multilineTextAlignment(.center)
                        } else {
                            Text("UNLOCK EVERYTHING")
                                .font(.system(size: 12, weight: .bold, design: .serif))
                                .foregroundColor(gold)
                                .tracking(3)

                            Text("Go Premium")
                                .font(.system(size: 38, weight: .bold, design: .serif))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [lightGold, gold],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }

                        Text("Unlock every feature in Quit All.")
                            .font(.system(size: 15, design: .serif))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        featureRow(icon: "flame.fill", text: "SOS craving intervention with GIFs")
                        featureRow(icon: "chart.bar.fill", text: "Advanced stats & pattern detection")
                        featureRow(icon: "trophy.fill", text: "Milestones with shareable cards")
                        featureRow(icon: "dollarsign.circle.fill", text: "Cost calculator & savings projections")
                        featureRow(icon: "bell.fill", text: "Smart notifications at danger times")
                        featureRow(icon: "arrow.counterclockwise", text: "No-shame relapse tracking")
                        featureRow(icon: "face.smiling.fill", text: "2,790+ motivational memes")
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)

                    // Subscription cards
                    VStack(spacing: 12) {
                        subscriptionCard(
                            title: "YEARLY",
                            price: formattedPrice(for: SubscriptionProduct.yearly.rawValue, fallback: "$49.99/year"),
                            subtitle: yearlySubtitle,
                            badge: "SAVE 48%",
                            isSelected: selectedProduct?.id == SubscriptionProduct.yearly.rawValue
                        ) {
                            selectProduct(id: SubscriptionProduct.yearly.rawValue)
                        }

                        subscriptionCard(
                            title: "MONTHLY",
                            price: formattedPrice(for: SubscriptionProduct.monthly.rawValue, fallback: "$7.99/month"),
                            subtitle: "Billed monthly",
                            badge: nil,
                            isSelected: selectedProduct?.id == SubscriptionProduct.monthly.rawValue
                        ) {
                            selectProduct(id: SubscriptionProduct.monthly.rawValue)
                        }
                    }
                    .padding(.horizontal, 20)

                    // CTA
                    Button {
                        Task { await purchase() }
                    } label: {
                        HStack {
                            if isPurchasing {
                                ProgressView().tint(.white)
                            } else {
                                Text(isTrialEligible ? "START FREE TRIAL" : "SUBSCRIBE NOW")
                                    .font(.system(size: 15, weight: .bold, design: .serif))
                                    .tracking(2)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            LinearGradient(
                                colors: [gold, Color(hex: "8B6914")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: gold.opacity(0.4), radius: 16, y: 6)
                    }
                    .disabled(isPurchasing)
                    .padding(.horizontal, 20)

                    // Trial/billing info
                    VStack(spacing: 6) {
                        if isTrialEligible {
                            Text("3 days free, then auto-renews.")
                                .font(.system(size: 12, weight: .medium, design: .serif))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        Text("Cancel anytime in iPhone Settings.")
                            .font(.system(size: 11, design: .serif))
                            .foregroundColor(.white.opacity(0.25))
                    }

                    // Error
                    if let error = PaywallManager.shared.purchaseError {
                        Text(error)
                            .font(.system(size: 13, design: .serif))
                            .foregroundColor(Color(hex: "8B0000"))
                            .padding(.horizontal, 20)
                    }

                    // Restore
                    Button {
                        Task { await restore() }
                    } label: {
                        HStack(spacing: 6) {
                            if isRestoring {
                                ProgressView().tint(gold.opacity(0.5)).scaleEffect(0.8)
                            }
                            Text("Restore Purchases")
                                .font(.system(size: 13, weight: .medium, design: .serif))
                                .foregroundColor(gold.opacity(0.4))
                        }
                    }
                    .disabled(isRestoring)

                    // Legal
                    HStack(spacing: 16) {
                        Link("Privacy Policy", destination: URL(string: "https://quit-all.vercel.app/privacy")!)
                        Text("·").foregroundColor(.white.opacity(0.15))
                        Link("Terms of Service", destination: URL(string: "https://quit-all.vercel.app/terms")!)
                    }
                    .font(.system(size: 11, design: .serif))
                    .foregroundColor(.white.opacity(0.2))
                    .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .task {
            await PaywallManager.shared.loadProducts()
            // Default select yearly
            selectedProduct = PaywallManager.shared.products.last

            // Check trial eligibility from StoreKit
            if let yearly = PaywallManager.shared.products.last {
                isTrialEligible = await PaywallManager.shared.isEligibleForTrial(yearly)
            }
        }
    }

    // MARK: - Helpers

    private var yearlySubtitle: String {
        if let product = PaywallManager.shared.products.first(where: { $0.id == SubscriptionProduct.yearly.rawValue }) {
            let monthly = product.price / 12
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = product.priceFormatStyle.currencyCode
            let monthlyStr = formatter.string(from: monthly as NSDecimalNumber) ?? "$4.17"
            return "\(monthlyStr)/month — best value"
        }
        return "$4.17/month — best value"
    }

    private func formattedPrice(for productId: String, fallback: String) -> String {
        guard let product = PaywallManager.shared.products.first(where: { $0.id == productId }) else {
            return fallback
        }
        let period = product.id.contains("yearly") ? "/year" : "/month"
        return "\(product.displayPrice)\(period)"
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(gold)
                .frame(width: 22, height: 22)
                .background(gold.opacity(0.1))
                .cornerRadius(6)
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(.white.opacity(0.75))
        }
    }

    private func subscriptionCard(title: String, price: String, subtitle: String, badge: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 14, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                            .tracking(1)
                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold, design: .serif))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(gold)
                                .cornerRadius(6)
                        }
                    }
                    Text(price)
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(.white.opacity(0.5))
                    Text(subtitle)
                        .font(.system(size: 12, design: .serif))
                        .foregroundColor(gold.opacity(0.5))
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected ? gold : Color.white.opacity(0.15), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle()
                            .fill(gold)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(16)
            .background(Color(hex: isSelected ? "1A1608" : "111111"))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? gold.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private func selectProduct(id: String) {
        HapticManager.shared.selection()
        selectedProduct = PaywallManager.shared.products.first { $0.id == id }
    }

    private func purchase() async {
        guard let product = selectedProduct else { return }
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
}
