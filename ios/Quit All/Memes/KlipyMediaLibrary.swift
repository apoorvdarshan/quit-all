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

    private init() {}

    func searchLoops(for type: AddictionType, count: Int) async -> [KlipyMediaItem] {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query(for: type)),
            URLQueryItem(name: "limit", value: "\(count)"),
            URLQueryItem(name: "media_filter", value: "tinygif,nanogif,gifpreview")
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
            return decoded.results.compactMap { result in
                guard let mediaFormat = result.bestAnimatedFormat else { return nil }

                return KlipyMediaItem(
                    id: "klipy-\(result.id)",
                    title: result.title,
                    gifURL: mediaFormat.url,
                    previewURL: result.mediaFormats.gifPreview?.url
                )
            }
        } catch {
            return []
        }
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
