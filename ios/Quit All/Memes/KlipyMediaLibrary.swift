import Foundation

// MARK: - Klipy Media Library
// Fetches remote GIF-style loops through the Cloudflare proxy so the API key stays server-side.
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
    private let maxPageRequestsPerLoad = 3

    private init() {}

    func searchLoops(for type: AddictionType, count: Int) async -> [KlipyMediaItem] {
        let savedState = searchState(for: type)
        let activeQuery = savedState.position == nil
            ? queryVariants(for: type).randomElement() ?? query(for: type)
            : savedState.query ?? query(for: type)
        var nextPosition = savedState.position
        var collectedItems: [KlipyMediaItem] = []

        for _ in 0..<maxPageRequestsPerLoad {
            guard let page = await fetchPage(query: activeQuery, limit: count, position: nextPosition) else {
                break
            }

            collectedItems.append(contentsOf: page.items)
            nextPosition = page.nextPosition
            storeSearchState(query: activeQuery, position: nextPosition, for: type)

            if uniqueItems(from: collectedItems).count >= count || nextPosition == nil {
                break
            }
        }

        if collectedItems.isEmpty, savedState.position != nil {
            clearSearchState(for: type)
            let fallbackQuery = queryVariants(for: type).randomElement() ?? query(for: type)
            guard let page = await fetchPage(query: fallbackQuery, limit: count, position: nil) else { return [] }
            collectedItems = page.items
            storeSearchState(query: fallbackQuery, position: page.nextPosition, for: type)
        }

        return selectFreshItems(collectedItems, for: type, count: count)
    }

    private func fetchPage(query: String, limit: Int, position: String?) async -> KlipySearchPage? {
        guard let url = pageURL(query: query, limit: limit, position: position) else { return nil }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
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

            return KlipySearchPage(items: items, nextPosition: decoded.next)
        } catch {
            return nil
        }
    }

    private func pageURL(query: String, limit: Int, position: String?) -> URL? {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "media_filter", value: "tinygif,nanogif,gifpreview"),
            URLQueryItem(name: "client_nonce", value: UUID().uuidString)
        ]

        if let position {
            queryItems.append(URLQueryItem(name: "pos", value: position))
        }

        components?.queryItems = queryItems
        return components?.url
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

    private func searchState(for type: AddictionType) -> (query: String?, position: String?) {
        (
            UserDefaults.standard.string(forKey: searchQueryDefaultsKey(for: type)),
            UserDefaults.standard.string(forKey: searchPositionDefaultsKey(for: type))
        )
    }

    private func storeSearchState(query: String, position: String?, for type: AddictionType) {
        UserDefaults.standard.set(query, forKey: searchQueryDefaultsKey(for: type))

        if let position {
            UserDefaults.standard.set(position, forKey: searchPositionDefaultsKey(for: type))
        } else {
            UserDefaults.standard.removeObject(forKey: searchPositionDefaultsKey(for: type))
        }
    }

    private func clearSearchState(for type: AddictionType) {
        UserDefaults.standard.removeObject(forKey: searchQueryDefaultsKey(for: type))
        UserDefaults.standard.removeObject(forKey: searchPositionDefaultsKey(for: type))
    }

    private func searchQueryDefaultsKey(for type: AddictionType) -> String {
        "klipy_search_query_\(type.rawValue)"
    }

    private func searchPositionDefaultsKey(for type: AddictionType) -> String {
        "klipy_search_position_\(type.rawValue)"
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

private struct KlipySearchPage {
    let items: [KlipyMediaItem]
    let nextPosition: String?
}

private struct KlipySearchResponse: Decodable {
    let results: [KlipyResult]
    let next: String?
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
