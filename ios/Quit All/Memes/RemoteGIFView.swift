import SwiftUI
import WebKit

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

        func load(url: URL, in webView: WKWebView) {
            guard currentURL != url else { return }
            currentURL = url

            let escapedURL = url.absoluteString
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "\"", with: "&quot;")

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
                <img src="\(escapedURL)" alt="">
              </body>
            </html>
            """

            webView.loadHTMLString(html, baseURL: nil)
        }
    }
}
