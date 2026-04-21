import Foundation
import SwiftUI
import UIKit
import ImageIO

// MARK: - Giphy Manager
// Fetches GIFs from Giphy API for meme display.
@Observable
final class GiphyManager {
    static let shared = GiphyManager()

    // API key loaded from Env.swift (generated from .env at build time)
    private let apiKey = EnvConfig.giphyAPIKey
    private let baseURL = "https://api.giphy.com/v1/gifs"

    var cachedGifs: [String: [GiphyGif]] = [:]

    private init() {}

    struct GiphyGif: Identifiable {
        let id: String
        let title: String
        let gifURL: URL
        let previewURL: URL
    }

    // Search terms per addiction type
    static func searchTerms(for type: AddictionType) -> [String] {
        switch type {
        case .smoking, .vaping:
            return ["quit smoking funny", "lungs healthy meme", "smoking fail", "fresh air meme", "anti smoking funny"]
        case .alcohol:
            return ["hangover funny", "sober life meme", "drunk fail", "morning after drinking", "sober motivation"]
        case .porn:
            return ["touch grass funny", "go outside meme", "brain rot", "dopamine detox", "self improvement meme"]
        case .socialMedia:
            return ["phone addiction funny", "doom scrolling meme", "screen time meme", "touch grass", "phone zombie"]
        case .weed:
            return ["stoner couch locked", "quit weed funny", "lazy meme", "brain fog meme", "sober energy"]
        case .gambling:
            return ["gambling fail", "casino loss meme", "money gone", "broke meme funny", "house always wins"]
        case .overspending:
            return ["broke meme", "impulse buying funny", "bank account empty", "shopping addiction meme", "saving money"]
        case .caffeine:
            return ["coffee addiction funny", "no coffee meme", "caffeine withdrawal", "morning without coffee", "too much coffee"]
        }
    }

    func searchGifs(query: String, limit: Int = 20) async -> [GiphyGif] {
        guard !apiKey.isEmpty else { return [] }

        if let cached = cachedGifs[query], !cached.isEmpty {
            return cached
        }

        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search?api_key=\(apiKey)&q=\(encoded)&limit=\(limit)&rating=pg") else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GiphyResponse.self, from: data)

            let gifs = response.data.compactMap { item -> GiphyGif? in
                guard let originalURL = item.images.fixed_height?.url ?? item.images.original?.url,
                      let previewURLStr = item.images.fixed_height_small?.url ?? item.images.fixed_height?.url,
                      let gifURL = URL(string: originalURL),
                      let previewURL = URL(string: previewURLStr) else {
                    return nil
                }
                return GiphyGif(id: item.id, title: item.title, gifURL: gifURL, previewURL: previewURL)
            }

            cachedGifs[query] = gifs
            return gifs
        } catch {
            return []
        }
    }

    func randomGifs(for type: AddictionType, count: Int = 15) async -> [GiphyGif] {
        let terms = Self.searchTerms(for: type)
        let term = terms.randomElement() ?? "motivation"
        return await searchGifs(query: term, limit: count)
    }

    // MARK: - Giphy Response Models
    private struct GiphyResponse: Codable {
        let data: [GiphyItem]
    }
    private struct GiphyItem: Codable {
        let id: String
        let title: String
        let images: GiphyImages
    }
    private struct GiphyImages: Codable {
        let original: GiphyImage?
        let fixed_height: GiphyImage?
        let fixed_height_small: GiphyImage?
    }
    private struct GiphyImage: Codable {
        let url: String
    }
}

// MARK: - Animated GIF View using UIKit
struct GIFImageView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        loadGif(into: imageView)
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {}

    private func loadGif(into imageView: UIImageView) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
                let frameCount = CGImageSourceGetCount(source)
                var images: [UIImage] = []
                var duration: Double = 0

                for i in 0..<frameCount {
                    guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
                    images.append(UIImage(cgImage: cgImage))

                    if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                       let gifProps = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                        let delay = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                            ?? gifProps[kCGImagePropertyGIFDelayTime as String] as? Double
                            ?? 0.1
                        duration += delay
                    }
                }

                await MainActor.run {
                    imageView.animationImages = images
                    imageView.animationDuration = duration
                    imageView.animationRepeatCount = 0
                    imageView.startAnimating()
                    imageView.image = images.first
                }
            } catch {}
        }
    }
}
