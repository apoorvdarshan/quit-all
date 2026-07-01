import Foundation
import UIKit
import RevenueCat

// MARK: - Tip Jar — optional consumable tips to support the app
@Observable
final class TipManager {
    static let shared = TipManager()

    static let productIDs = [
        "com.quitall.tip.small",
        "com.quitall.tip.medium",
        "com.quitall.tip.large",
        "com.quitall.tip.huge",
    ]

    struct TipOption: Identifiable {
        let id: String
        let title: String
        let price: String
        let emoji: String
        fileprivate let product: StoreProduct
    }

    var options: [TipOption] = []
    var isLoading = false
    var isPurchasing = false
    var showThankYou = false
    var errorMessage: String?

    private init() {}

    private static func emoji(for productID: String) -> String {
        switch productID {
        case "com.quitall.tip.small": return "☕️"
        case "com.quitall.tip.medium": return "🍩"
        case "com.quitall.tip.large": return "🍔"
        case "com.quitall.tip.huge": return "🎁"
        default: return "💛"
        }
    }

    func loadProducts() async {
        guard options.isEmpty else { return }
        isLoading = true
        await PaywallManager.ensureConfigured()
        let products = await Purchases.shared.products(Self.productIDs)
        options = products
            .sorted { $0.price < $1.price }
            .map {
                TipOption(
                    id: $0.productIdentifier,
                    title: $0.localizedTitle,
                    price: $0.localizedPriceString,
                    emoji: Self.emoji(for: $0.productIdentifier),
                    product: $0
                )
            }
        isLoading = false
    }

    func purchase(_ option: TipOption) async {
        isPurchasing = true
        errorMessage = nil
        await PaywallManager.ensureConfigured()
        do {
            let result = try await Purchases.shared.purchase(product: option.product)
            if !result.userCancelled {
                HapticManager.shared.notification(.success)
                showThankYou = true
            }
        } catch {
            errorMessage = "Purchase couldn't be completed. Please try again."
        }
        isPurchasing = false
    }
}
