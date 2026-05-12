import Foundation
import RevenueCat
import SwiftUI

// MARK: - Premium Product IDs
enum SubscriptionProduct: String, CaseIterable {
    case monthly = "com.quitall.premium.monthly"
    case yearly = "com.quitall.premium.yearly"
    case lifetime = "com.quitall.premium.lifetime"
}

// MARK: - Paywall Manager — Hard Paywall, RevenueCat
@Observable
final class PaywallManager {
    static let shared = PaywallManager()
    static let monthlyProductID = SubscriptionProduct.monthly.rawValue
    static let yearlyProductID = SubscriptionProduct.yearly.rawValue
    static let lifetimeProductID = SubscriptionProduct.lifetime.rawValue

    private static let revenueCatAPIKey = "test_MgfVZTSRdBnQaTZBlBlcDfluoBU"
    private static let entitlementIDs = ["premium", "Quit All Premium"]

    var isSubscribed: Bool = false
    var packages: [Package] = []
    var purchaseError: String?
    var isLoading: Bool = false

    private init() {
        configureRevenueCat()
        Task { await checkEntitlements() }
    }

    var hasAccess: Bool {
        isSubscribed
    }

    var monthlyPackage: Package? {
        package(for: Self.monthlyProductID, type: .monthly)
    }

    var yearlyPackage: Package? {
        package(for: Self.yearlyProductID, type: .annual)
    }

    var lifetimePackage: Package? {
        package(for: Self.lifetimeProductID, type: .lifetime)
    }

    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        purchaseError = nil

        do {
            let offerings = try await Purchases.shared.offerings()
            let offering = offerings.current ?? offerings.offering(identifier: "default")
            packages = offering?.availablePackages ?? []
            print("[PaywallManager] RevenueCat packages: \(packages.map { $0.storeProduct.productIdentifier })")
            if packages.isEmpty {
                purchaseError = "No purchase options are available right now."
            }
        } catch {
            print("[PaywallManager] Error loading products: \(error)")
            purchaseError = "Failed to load purchase options."
        }

        await checkEntitlements()
        isLoading = false
    }

    // MARK: - Purchase
    func purchase(_ package: Package) async -> Bool {
        isLoading = true
        purchaseError = nil

        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(customerInfo: result.customerInfo)
            isLoading = false
            return !result.userCancelled && hasAccess
        } catch {
            purchaseError = "Purchase failed. Please try again."
            await checkEntitlements()
            isLoading = false
            return false
        }
    }

    // MARK: - Restore
    func restorePurchases() async {
        isLoading = true
        purchaseError = nil

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            apply(customerInfo: customerInfo)
        } catch {
            purchaseError = "Restore failed. Please try again."
            await checkEntitlements()
        }

        isLoading = false
    }

    // MARK: - Check Entitlements
    func checkEntitlements() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            apply(customerInfo: customerInfo)
        } catch {
            isSubscribed = false
        }
    }

    // MARK: - Listen for Updates
    func listenForTransactions() async {
        do {
            for try await customerInfo in Purchases.shared.customerInfoStream {
                apply(customerInfo: customerInfo)
            }
        } catch {
            print("[PaywallManager] Customer info stream ended: \(error)")
        }
    }

    // MARK: - Check if eligible for introductory offer (free trial)
    func isEligibleForTrial(_ package: Package?) async -> Bool {
        guard let package,
              package.storeProduct.introductoryDiscount?.paymentMode == .freeTrial else { return false }
        let status = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: package.storeProduct)
        return status.isEligible
    }

    func package(for productID: String) -> Package? {
        packages.first { $0.storeProduct.productIdentifier == productID }
    }

    private func package(for productID: String, type: PackageType) -> Package? {
        packages.first { $0.storeProduct.productIdentifier == productID }
            ?? packages.first { $0.packageType == type }
    }

    private func apply(customerInfo: CustomerInfo) {
        isSubscribed = Self.entitlementIDs.contains {
            customerInfo.entitlements[$0]?.isActive == true
        }
    }

    private func configureRevenueCat() {
        guard !Purchases.isConfigured else { return }
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: Self.revenueCatAPIKey)
    }
}
