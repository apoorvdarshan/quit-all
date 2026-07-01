import Foundation
import RevenueCat
import SwiftUI

// MARK: - Premium Product IDs
enum SubscriptionProduct: String, CaseIterable {
    case weekly = "com.quitall.premium.weekly"
    case yearly = "com.quitall.premium.yearly"
    case lifetime = "com.quitall.premium.lifetime"
}

// MARK: - Paywall Manager — Hard Paywall, RevenueCat
@Observable
final class PaywallManager {
    static let shared = PaywallManager()
    static let weeklyProductID = SubscriptionProduct.weekly.rawValue
    static let yearlyProductID = SubscriptionProduct.yearly.rawValue
    static let lifetimeProductID = SubscriptionProduct.lifetime.rawValue

    private static let fallbackRevenueCatAPIKey = "appl_ubtsOyRubEENNaebBFqLgcfxYBx"
    private static let appConfigURL = URL(string: "https://www.quit-all.com/api/app-config")!
    private static var revenueCatConfigurationTask: Task<Void, Never>?
    private static let entitlementIDs = ["premium", "Quit All Premium"]

    var isSubscribed: Bool = false
    var packages: [Package] = []
    var purchaseError: String?
    var isLoading: Bool = false

    private init() {
        Self.startRevenueCatConfiguration()
        Task { await checkEntitlements() }
    }

    var hasAccess: Bool {
        isSubscribed
    }

    var weeklyPackage: Package? {
        package(for: Self.weeklyProductID, type: .weekly)
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
            await Self.ensureRevenueCatConfigured()
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
            await Self.ensureRevenueCatConfigured()
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
            await Self.ensureRevenueCatConfigured()
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
            await Self.ensureRevenueCatConfigured()
            let customerInfo = try await Purchases.shared.customerInfo()
            apply(customerInfo: customerInfo)
        } catch {
            isSubscribed = false
        }
    }

    // MARK: - Listen for Updates
    func listenForTransactions() async {
        await Self.ensureRevenueCatConfigured()
        for await customerInfo in Purchases.shared.customerInfoStream {
            apply(customerInfo: customerInfo)
        }
    }

    // MARK: - Check if eligible for introductory offer (free trial)
    func isEligibleForTrial(_ package: Package?) async -> Bool {
        guard let package,
              package.storeProduct.introductoryDiscount?.paymentMode == .freeTrial else { return false }
        await Self.ensureRevenueCatConfigured()
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

    private static func ensureRevenueCatConfigured() async {
        startRevenueCatConfiguration()
        await revenueCatConfigurationTask?.value
    }

    private static func startRevenueCatConfiguration() {
        guard revenueCatConfigurationTask == nil else { return }

        revenueCatConfigurationTask = Task {
            let apiKey = await fetchRevenueCatAPIKey()

            guard !Purchases.isConfigured else { return }
            #if DEBUG
            Purchases.logLevel = .debug
            #endif
            Purchases.configure(withAPIKey: apiKey)
        }
    }

    private static func fetchRevenueCatAPIKey() async -> String {
        var components = URLComponents(url: appConfigURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "bundleId", value: Bundle.main.bundleIdentifier)
        ]

        var request = URLRequest(url: components?.url ?? appConfigURL)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 2
        request.setValue("application/json", forHTTPHeaderField: "accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return fallbackRevenueCatAPIKey
            }

            let config = try JSONDecoder().decode(AppConfigResponse.self, from: data)
            let apiKey = config.revenueCatAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            return apiKey.isEmpty ? fallbackRevenueCatAPIKey : apiKey
        } catch {
            return fallbackRevenueCatAPIKey
        }
    }
}

private struct AppConfigResponse: Decodable {
    let revenueCatAPIKey: String
}
