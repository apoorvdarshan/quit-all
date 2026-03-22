import SwiftUI
import StoreKit

// MARK: - Paywall View
struct PaywallView: View {
    let onComplete: () -> Void

    @State private var selectedProduct: Product?
    @State private var isPurchasing = false

    private let gold = Color(hex: "D4AF37")
    private let lightGold = Color(hex: "F5E6A3")

    var body: some View {
        ZStack {
            Color(hex: "080808").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    // Header
                    VStack(spacing: 8) {
                        Text("UNLOCK EVERYTHING")
                            .font(.system(size: 12, weight: .bold, design: .serif))
                            .foregroundColor(gold)
                            .tracking(3)

                        Text("Start Your\nFree Trial")
                            .font(.system(size: 34, weight: .bold, design: .serif))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [lightGold, gold],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .multilineTextAlignment(.center)
                    }

                    // Features list
                    VStack(alignment: .leading, spacing: 14) {
                        featureRow(icon: "flame.fill", text: "SOS craving intervention with GIFs")
                        featureRow(icon: "chart.bar.fill", text: "Advanced stats & pattern detection")
                        featureRow(icon: "trophy.fill", text: "Milestones with shareable cards")
                        featureRow(icon: "dollarsign.circle.fill", text: "Cost calculator & savings projections")
                        featureRow(icon: "bell.fill", text: "Smart notifications at danger times")
                        featureRow(icon: "arrow.counterclockwise", text: "No-shame relapse tracking")
                    }
                    .padding(.horizontal, 24)

                    // Subscription options
                    VStack(spacing: 12) {
                        // Yearly — recommended
                        subscriptionCard(
                            title: "YEARLY",
                            price: "$49.99/year",
                            subtitle: "$4.17/month",
                            badge: "SAVE 48%",
                            isSelected: selectedProduct?.id == SubscriptionProduct.yearly.rawValue
                        ) {
                            selectProduct(id: SubscriptionProduct.yearly.rawValue)
                        }

                        // Monthly
                        subscriptionCard(
                            title: "MONTHLY",
                            price: "$7.99/month",
                            subtitle: "",
                            badge: nil,
                            isSelected: selectedProduct?.id == SubscriptionProduct.monthly.rawValue
                        ) {
                            selectProduct(id: SubscriptionProduct.monthly.rawValue)
                        }
                    }
                    .padding(.horizontal, 20)

                    // CTA button
                    Button {
                        Task { await purchase() }
                    } label: {
                        HStack {
                            if isPurchasing {
                                ProgressView().tint(.white)
                            } else {
                                Text("START FREE TRIAL")
                                    .font(.system(size: 16, weight: .bold, design: .serif))
                                    .tracking(2)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
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

                    // Trial info
                    Text("3-day free trial, then auto-renews.\nCancel anytime in Settings.")
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(.white.opacity(0.3))
                        .multilineTextAlignment(.center)

                    // Restore + Skip
                    HStack(spacing: 24) {
                        Button {
                            Task { await PaywallManager.shared.restorePurchases() }
                        } label: {
                            Text("Restore Purchases")
                                .font(.system(size: 13, weight: .medium, design: .serif))
                                .foregroundColor(gold.opacity(0.5))
                        }

                        Button {
                            onComplete()
                        } label: {
                            Text("No thanks")
                                .font(.system(size: 13, weight: .medium, design: .serif))
                                .foregroundColor(.white.opacity(0.25))
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await PaywallManager.shared.loadProducts()
            // Default select yearly
            selectedProduct = PaywallManager.shared.products.last
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(gold)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundColor(.white.opacity(0.8))
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
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(gold.opacity(0.6))
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? gold : Color.white.opacity(0.2), lineWidth: 2)
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
                    .stroke(isSelected ? gold.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
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
}
