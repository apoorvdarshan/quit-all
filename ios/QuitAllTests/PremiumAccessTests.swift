import XCTest
@testable import Quit_All

final class PremiumAccessTests: QuitAllTestCase {
    func testPremiumNeedsAnActiveAppEntitlement() {
        XCTAssertTrue(PaywallManager.grantsPremium { $0 == "premium" })
        XCTAssertTrue(PaywallManager.grantsPremium { $0 == "Quit All Premium" })
        XCTAssertFalse(PaywallManager.grantsPremium { _ in false }, "no active entitlement")
        XCTAssertFalse(PaywallManager.grantsPremium { $0 == "pro" }, "another app's entitlement")
    }

    func testProductIdentifiersMatchTheStore() {
        // Must match App Store Connect, store/catalog/products.json and Products.storekit.
        XCTAssertEqual(
            SubscriptionProduct.allCases.map(\.rawValue),
            ["com.quitall.premium.weekly", "com.quitall.premium.yearly", "com.quitall.premium.lifetime"]
        )
        XCTAssertEqual(PaywallManager.weeklyProductID, SubscriptionProduct.weekly.rawValue)
        XCTAssertEqual(PaywallManager.yearlyProductID, SubscriptionProduct.yearly.rawValue)
        XCTAssertEqual(PaywallManager.lifetimeProductID, SubscriptionProduct.lifetime.rawValue)
    }

    func testSimulatorTestsNeverReachTheStoreOrUnlockPremium() async {
        XCTAssertTrue(AppTestEnvironment.isActive)
        XCTAssertFalse(AppTestEnvironment.grantsPremium)

        let manager = PaywallManager.shared
        XCTAssertFalse(manager.hasAccess)

        await manager.loadProducts()
        XCTAssertTrue(manager.packages.isEmpty)
        XCTAssertNil(manager.purchaseError)
        XCTAssertNil(manager.weeklyPackage)
        XCTAssertNil(manager.yearlyPackage)
        XCTAssertNil(manager.lifetimePackage)

        await manager.restorePurchases()
        await manager.checkEntitlements()
        XCTAssertFalse(manager.hasAccess, "restoring without an entitlement keeps the paywall")
        XCTAssertFalse(manager.isLoading)
    }
}

final class AppUpdateCheckerTests: QuitAllTestCase {
    func testStoreVersionMustBeStrictlyNewer() {
        XCTAssertTrue(AppUpdateChecker.isVersion("1.2.2", newerThan: "1.2.1"))
        XCTAssertTrue(AppUpdateChecker.isVersion("1.10", newerThan: "1.9"))
        XCTAssertTrue(AppUpdateChecker.isVersion("2", newerThan: "1.9.9"))
        XCTAssertTrue(AppUpdateChecker.isVersion("1.3b2", newerThan: "1.2.9"))
        XCTAssertFalse(AppUpdateChecker.isVersion("1.2.1", newerThan: "1.2.1"))
        XCTAssertFalse(AppUpdateChecker.isVersion("1.2", newerThan: "1.2.0"))
        XCTAssertFalse(AppUpdateChecker.isVersion("1.2.1", newerThan: "1.3"))
        XCTAssertFalse(AppUpdateChecker.isVersion("beta", newerThan: "1.0"))
    }

    func testCurrentVersionComesFromTheBundle() {
        let checker = AppUpdateChecker.shared
        XCTAssertEqual(checker.currentVersion, Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        XCTAssertNotNil(checker.currentVersion.range(of: #"^\d+(\.\d+){0,2}$"#, options: .regularExpression))
    }

    func testTestsNeverQueryTheAppStore() async {
        let checker = AppUpdateChecker.shared
        await checker.checkForUpdate(force: true)
        XCTAssertFalse(checker.isChecking)
        XCTAssertNil(checker.latestVersion)
        XCTAssertFalse(checker.isUpdateAvailable)
        XCTAssertEqual(checker.displayStatus, "Tap to check for updates")
    }
}
