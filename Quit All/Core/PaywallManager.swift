import StoreKit
import SwiftUI

// MARK: - Subscription Product IDs
enum SubscriptionProduct: String, CaseIterable {
    case monthly = "com.quitall.premium.monthly"
    case yearly = "com.quitall.premium.yearly"
}

// MARK: - Paywall Manager — Hard Paywall, Native StoreKit Trial
@Observable
final class PaywallManager {
    static let shared = PaywallManager()

    var isSubscribed: Bool = false
    var products: [Product] = []
    var purchaseError: String?
    var isLoading: Bool = false

    private init() {
        // Check entitlements on init
        Task { await checkEntitlements() }
    }

    var hasAccess: Bool {
        isSubscribed
    }

    // MARK: - Check Entitlements (native StoreKit)
    func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == SubscriptionProduct.monthly.rawValue ||
                    transaction.productID == SubscriptionProduct.yearly.rawValue {
                    isSubscribed = true
                    return
                }
            }
        }
        isSubscribed = false
    }

    // MARK: - Load Products
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

    // MARK: - Purchase
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                isSubscribed = true
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

    // MARK: - Restore
    func restorePurchases() async {
        isLoading = true
        await checkEntitlements()
        isLoading = false
    }

    // MARK: - Listen for Updates
    func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                isSubscribed = true
                await transaction.finish()
            }
        }
    }

    // MARK: - Check if eligible for introductory offer (free trial)
    func isEligibleForTrial(_ product: Product) async -> Bool {
        await product.subscription?.isEligibleForIntroOffer ?? false
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
