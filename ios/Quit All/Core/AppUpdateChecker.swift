import Combine
import Foundation
import UIKit

// MARK: - App Update Checker
// Uses Apple's public lookup endpoint by bundle id; no App Store Connect key is needed.
@MainActor
final class AppUpdateChecker: ObservableObject {
    static let shared = AppUpdateChecker()

    @Published private(set) var isChecking = false
    @Published private(set) var latestVersion: String?
    @Published private(set) var appStoreURL: URL?
    @Published private(set) var statusMessage: String?
    @Published private(set) var lastCheckedAt: Date?

    private let refreshInterval: TimeInterval = 6 * 60 * 60

    private init() {}

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var isUpdateAvailable: Bool {
        guard let latestVersion else { return false }
        return Self.isVersion(latestVersion, newerThan: currentVersion)
    }

    var displayStatus: String {
        if isChecking {
            return "Checking App Store"
        }

        if isUpdateAvailable, let latestVersion {
            return "Version \(latestVersion) is available"
        }

        if let statusMessage {
            return statusMessage
        }

        return "Tap to check for updates"
    }

    func checkForUpdate(force: Bool = false) async {
        // Simulator tests never call the App Store lookup endpoint.
        guard !isChecking, !AppTestEnvironment.isActive else { return }

        if !force,
           let lastCheckedAt,
           Date().timeIntervalSince(lastCheckedAt) < refreshInterval {
            return
        }

        guard let bundleID = Bundle.main.bundleIdentifier,
              var components = URLComponents(string: "https://itunes.apple.com/lookup") else {
            statusMessage = "Could not read app bundle"
            return
        }

        components.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID)
        ]

        guard let url = components.url else {
            statusMessage = "Could not build update check"
            return
        }

        isChecking = true
        statusMessage = nil

        defer {
            isChecking = false
            lastCheckedAt = Date()
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                statusMessage = "Could not check right now"
                return
            }

            let lookup = try JSONDecoder().decode(AppStoreLookupResponse.self, from: data)
            guard let result = lookup.results.first else {
                latestVersion = nil
                appStoreURL = nil
                statusMessage = "App Store listing not found yet"
                return
            }

            latestVersion = result.version
            appStoreURL = result.appStoreURL
            statusMessage = isUpdateAvailable ? nil : "You're on the latest version"
        } catch {
            statusMessage = "Could not check right now"
        }
    }

    func openAppStore() {
        guard let appStoreURL else { return }
        UIApplication.shared.open(appStoreURL)
    }

    static func isVersion(_ storeVersion: String, newerThan currentVersion: String) -> Bool {
        let storeParts = numericParts(from: storeVersion)
        let currentParts = numericParts(from: currentVersion)
        let count = max(storeParts.count, currentParts.count)

        for index in 0..<count {
            let storePart = index < storeParts.count ? storeParts[index] : 0
            let currentPart = index < currentParts.count ? currentParts[index] : 0

            if storePart != currentPart {
                return storePart > currentPart
            }
        }

        return false
    }

    private static func numericParts(from version: String) -> [Int] {
        let parts = version
            .split(separator: ".")
            .map { component -> Int in
                let numericPrefix = component.split { !$0.isNumber }.first
                return numericPrefix.flatMap { Int($0) } ?? 0
            }

        return parts.isEmpty ? [0] : parts
    }
}

private struct AppStoreLookupResponse: Decodable {
    let results: [AppStoreLookupResult]
}

private struct AppStoreLookupResult: Decodable {
    let version: String
    let trackViewUrl: URL?
    let trackId: Int?

    var appStoreURL: URL? {
        trackViewUrl ?? trackId.flatMap { URL(string: "https://apps.apple.com/app/id\($0)") }
    }
}
