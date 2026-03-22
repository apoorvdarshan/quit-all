import StoreKit
import SwiftUI

// MARK: - Subscription Product IDs
enum SubscriptionProduct: String, CaseIterable {
    case monthly = "com.quitall.premium.monthly"
    case yearly = "com.quitall.premium.yearly"
}

// MARK: - Paywall Manager — Hard Paywall with 3-Day Free Trial
@Observable
final class PaywallManager {
    static let shared = PaywallManager()

    var isSubscribed: Bool = false
    var isInTrial: Bool = false
    var products: [Product] = []
    var purchaseError: String?
    var isLoading: Bool = false

    private let trialStartKey = "trial_start_date"
    private let trialDays = 3

    private init() {
        isSubscribed = UserDefaults.standard.bool(forKey: "isSubscribed")
        checkTrialStatus()
    }

    // MARK: - Access Check
    var hasAccess: Bool {
        isSubscribed || isInTrial
    }

    // MARK: - Trial Management
    func startTrial() {
        if UserDefaults.standard.object(forKey: trialStartKey) == nil {
            UserDefaults.standard.set(Date(), forKey: trialStartKey)
        }
        checkTrialStatus()
    }

    func checkTrialStatus() {
        guard let trialStart = UserDefaults.standard.object(forKey: trialStartKey) as? Date else {
            isInTrial = false
            return
        }
        let trialEnd = Calendar.current.date(byAdding: .day, value: trialDays, to: trialStart)!
        isInTrial = Date() < trialEnd
    }

    var trialDaysRemaining: Int {
        guard let trialStart = UserDefaults.standard.object(forKey: trialStartKey) as? Date else { return 0 }
        let trialEnd = Calendar.current.date(byAdding: .day, value: trialDays, to: trialStart)!
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: trialEnd).day ?? 0)
    }

    var hasUsedTrial: Bool {
        UserDefaults.standard.object(forKey: trialStartKey) != nil
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
