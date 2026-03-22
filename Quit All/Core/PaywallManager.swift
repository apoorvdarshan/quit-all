import StoreKit
import SwiftUI

// MARK: - Subscription Product IDs
enum SubscriptionProduct: String, CaseIterable {
    case monthly = "com.quitall.premium.monthly"
    case yearly = "com.quitall.premium.yearly"
}

// MARK: - Paywall Manager
@Observable
final class PaywallManager {
    static let shared = PaywallManager()

    var isSubscribed: Bool = false
    var products: [Product] = []
    var purchaseError: String?
    var isLoading: Bool = false

    private init() {
        // Check saved subscription state
        isSubscribed = UserDefaults.standard.bool(forKey: "isSubscribed")
    }

    var hasAccess: Bool {
        isSubscribed
    }

    // MARK: - StoreKit 2

    func loadProducts() async {
        isLoading = true
        do {
            let productIDs = SubscriptionProduct.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            purchaseError = "Failed to load subscription options."
        }
        isLoading = false
    }

    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                isSubscribed = true
                UserDefaults.standard.set(true, forKey: "isSubscribed")
                await transaction.finish()
                isLoading = false
                return true

            case .userCancelled:
                isLoading = false
                return false

            case .pending:
                purchaseError = "Purchase is pending approval."
                isLoading = false
                return false

            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            purchaseError = "Purchase failed. Please try again."
            isLoading = false
            return false
        }
    }

    func restorePurchases() async {
        isLoading = true
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == SubscriptionProduct.monthly.rawValue ||
                    transaction.productID == SubscriptionProduct.yearly.rawValue {
                    isSubscribed = true
                    UserDefaults.standard.set(true, forKey: "isSubscribed")
                }
            }
        }
        isLoading = false
    }

    func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                isSubscribed = true
                UserDefaults.standard.set(true, forKey: "isSubscribed")
                await transaction.finish()
            }
        }
    }

    // Skip paywall — free basic mode
    func skipPaywall() {
        // User proceeds without subscription
        // Features will be gated elsewhere
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
