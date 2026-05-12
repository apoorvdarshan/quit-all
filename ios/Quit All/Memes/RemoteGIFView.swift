import SwiftUI
import WebKit

final class RemoteGIFCache: @unchecked Sendable {
    static let shared = RemoteGIFCache()

    private let cache = NSCache<NSURL, NSData>()

    private init() {
        cache.countLimit = 80
        cache.totalCostLimit = 35 * 1024 * 1024
    }

    func data(for url: URL) async -> Data? {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached as Data
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 12

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            cache.setObject(data as NSData, forKey: key, cost: data.count)
            return data
        } catch {
            return nil
        }
    }

    func preload(urls: [URL]) async {
        let uniqueURLs = Array(Set(urls)).prefix(24)
        await withTaskGroup(of: Void.self) { group in
            for url in uniqueURLs {
                group.addTask {
                    _ = await self.data(for: url)
                }
            }
        }
    }
}

// MARK: - Remote GIF View
// WKWebView reliably animates remote GIFs without adding a third-party dependency.
struct RemoteGIFView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.load(url: url, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(url: url, in: webView)
    }

    final class Coordinator {
        private var currentURL: URL?
        private var loadTask: Task<Void, Never>?

        func load(url: URL, in webView: WKWebView) {
            guard currentURL != url else { return }
            loadTask?.cancel()
            currentURL = url

            webView.loadHTMLString(Self.html(source: nil), baseURL: nil)

            loadTask = Task { [weak self, weak webView] in
                let source: String
                if let data = await RemoteGIFCache.shared.data(for: url) {
                    source = "data:image/gif;base64,\(data.base64EncodedString())"
                } else {
                    source = url.absoluteString
                }

                await MainActor.run { [weak self, weak webView] in
                    guard !Task.isCancelled,
                          self?.currentURL == url,
                          let webView else { return }

                    webView.loadHTMLString(Self.html(source: source), baseURL: nil)
                }
            }
        }

        private static func html(source: String?) -> String {
            let imageHTML: String
            if let source {
                let escapedSource = source
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "\"", with: "&quot;")
                imageHTML = "<img src=\"\(escapedSource)\" alt=\"\">"
            } else {
                imageHTML = ""
            }

            let html = """
            <!doctype html>
            <html>
              <head>
                <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
                <style>
                  html, body {
                    margin: 0;
                    width: 100%;
                    height: 100%;
                    overflow: hidden;
                    background: #111111;
                  }
                  img {
                    width: 100%;
                    height: 100%;
                    object-fit: contain;
                    display: block;
                  }
                </style>
              </head>
              <body>
                \(imageHTML)
              </body>
            </html>
            """

            return html
        }
    }
}
