import Foundation

// MARK: - Klipy Media Library
// Fetches remote GIF-style loops through the Vercel proxy so the API key stays server-side.
struct KlipyMediaItem: Identifiable, Hashable {
    let id: String
    let title: String
    let gifURL: URL
    let previewURL: URL?
}

final class KlipyMediaLibrary {
    static let shared = KlipyMediaLibrary()

    private let endpoint = URL(string: "https://www.quit-all.com/api/klipy/v2/search")!
    private let recentItemLimit = 80

    private init() {}

    func searchLoops(for type: AddictionType, count: Int) async -> [KlipyMediaItem] {
        let fetchLimit = min(max(count * 4, count), 50)

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: queryVariants(for: type).randomElement() ?? query(for: type)),
            URLQueryItem(name: "limit", value: "\(fetchLimit)"),
            URLQueryItem(name: "media_filter", value: "tinygif,nanogif,gifpreview"),
            URLQueryItem(name: "client_nonce", value: UUID().uuidString)
        ]

        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return []
            }

            let decoded = try JSONDecoder().decode(KlipySearchResponse.self, from: data)
            let items: [KlipyMediaItem] = decoded.results.compactMap { result -> KlipyMediaItem? in
                guard let mediaFormat = result.bestAnimatedFormat else { return nil }

                return KlipyMediaItem(
                    id: "klipy-\(result.id)",
                    title: result.title,
                    gifURL: mediaFormat.url,
                    previewURL: result.mediaFormats.gifPreview?.url
                )
            }

            return selectFreshItems(items, for: type, count: count)
        } catch {
            return []
        }
    }

    private func selectFreshItems(_ items: [KlipyMediaItem], for type: AddictionType, count: Int) -> [KlipyMediaItem] {
        let uniqueItems = uniqueItems(from: items)
        guard !uniqueItems.isEmpty else { return [] }

        let recentIDs = Set(recentItemIDs(for: type))
        let freshItems = uniqueItems.filter { !recentIDs.contains($0.id) }.shuffled()
        let fallbackItems = uniqueItems.filter { recentIDs.contains($0.id) }.shuffled()
        let selectedItems = Array((freshItems + fallbackItems).prefix(count))

        storeRecentItemIDs(selectedItems.map(\.id), for: type)
        return selectedItems
    }

    private func uniqueItems(from items: [KlipyMediaItem]) -> [KlipyMediaItem] {
        var seenIDs = Set<String>()
        return items.filter { item in
            seenIDs.insert(item.id).inserted
        }
    }

    private func recentItemIDs(for type: AddictionType) -> [String] {
        UserDefaults.standard.stringArray(forKey: recentDefaultsKey(for: type)) ?? []
    }

    private func storeRecentItemIDs(_ ids: [String], for type: AddictionType) {
        guard !ids.isEmpty else { return }

        let idSet = Set(ids)
        let existingIDs = recentItemIDs(for: type).filter { !idSet.contains($0) }
        let mergedIDs = Array((ids + existingIDs).prefix(recentItemLimit))

        UserDefaults.standard.set(mergedIDs, forKey: recentDefaultsKey(for: type))
    }

    private func recentDefaultsKey(for type: AddictionType) -> String {
        "klipy_recent_items_\(type.rawValue)"
    }

    private func query(for type: AddictionType) -> String {
        switch type {
        case .smoking:
            return "quit smoking meme"
        case .vaping:
            return "quit vaping meme"
        case .alcohol:
            return "sober meme"
        case .porn:
            return "self control meme"
        case .socialMedia:
            return "doomscrolling meme"
        case .weed:
            return "quit weed meme"
        case .gambling:
            return "gambling meme"
        case .overspending:
            return "broke meme"
        case .caffeine:
            return "coffee meme"
        }
    }

    private func queryVariants(for type: AddictionType) -> [String] {
        switch type {
        case .smoking:
            return ["quit smoking meme", "smoking meme", "cigarette meme", "no smoking meme", "nicotine meme"]
        case .vaping:
            return ["quit vaping meme", "vaping meme", "no vaping meme", "nicotine meme", "bad habit meme"]
        case .alcohol:
            return ["sober meme", "sobriety meme", "no alcohol meme", "hangover meme", "drinking meme"]
        case .porn:
            return ["self control meme", "discipline meme", "focus meme", "willpower meme", "brain meme"]
        case .socialMedia:
            return ["doomscrolling meme", "social media meme", "phone addiction meme", "screen time meme", "internet meme"]
        case .weed:
            return ["quit weed meme", "weed meme", "sober meme", "stoner meme", "discipline meme"]
        case .gambling:
            return ["gambling meme", "casino meme", "bad luck meme", "money meme", "risk meme"]
        case .overspending:
            return ["broke meme", "shopping meme", "saving money meme", "budget meme", "wallet meme"]
        case .caffeine:
            return ["coffee meme", "caffeine meme", "no coffee meme", "sleepy meme", "energy meme"]
        }
    }
}

private struct KlipySearchResponse: Decodable {
    let results: [KlipyResult]
}

private struct KlipyResult: Decodable {
    let id: String
    let title: String
    let mediaFormats: KlipyMediaFormats

    var bestAnimatedFormat: KlipyMediaFormat? {
        mediaFormats.tinyGif ?? mediaFormats.nanoGif
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case mediaFormats = "media_formats"
    }
}

private struct KlipyMediaFormats: Decodable {
    let tinyGif: KlipyMediaFormat?
    let nanoGif: KlipyMediaFormat?
    let gifPreview: KlipyMediaFormat?

    enum CodingKeys: String, CodingKey {
        case tinyGif = "tinygif"
        case nanoGif = "nanogif"
        case gifPreview = "gifpreview"
    }
}

private struct KlipyMediaFormat: Decodable {
    let url: URL
}
