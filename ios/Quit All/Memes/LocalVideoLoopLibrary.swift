import AVFoundation
import SwiftUI
import UIKit

// MARK: - Local Video Loop Library
// Loads bundled silent MP4/MOV loops from VideoLoops.json.
struct LocalVideoLoop: Identifiable, Hashable {
    let id: String
    let addictionType: AddictionType
    let title: String
    let url: URL
}

@Observable
final class LocalVideoLoopLibrary {
    static let shared = LocalVideoLoopLibrary()

    private var hasLoaded = false
    private var loopsByType: [AddictionType: [LocalVideoLoop]] = [:]

    private init() {}

    func randomLoops(for type: AddictionType, count: Int) -> [LocalVideoLoop] {
        loadIfNeeded()
        return Array((loopsByType[type] ?? []).shuffled().prefix(count))
    }

    func loops(for type: AddictionType) -> [LocalVideoLoop] {
        loadIfNeeded()
        return loopsByType[type] ?? []
    }

    private func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true

        guard let manifestURL = Bundle.main.url(forResource: "VideoLoops", withExtension: "json"),
              let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(VideoLoopManifest.self, from: data) else {
            return
        }

        let loops = manifest.loops.compactMap { record -> LocalVideoLoop? in
            guard let type = AddictionType(rawValue: record.addictionType),
                  let url = resolveAssetURL(fileName: record.fileName) else {
                return nil
            }

            return LocalVideoLoop(
                id: record.id ?? "\(type.rawValue)-\(record.fileName)",
                addictionType: type,
                title: record.title ?? type.rawValue,
                url: url
            )
        }

        loopsByType = Dictionary(grouping: loops, by: \.addictionType)
    }

    private func resolveAssetURL(fileName: String) -> URL? {
        let nsFileName = fileName as NSString
        let resourceName = nsFileName.deletingPathExtension
        let ext = nsFileName.pathExtension.isEmpty ? nil : nsFileName.pathExtension

        if let url = Bundle.main.url(forResource: resourceName, withExtension: ext) {
            return url
        }

        for subdirectory in ["VideoLoops", "Memes/VideoLoops"] {
            if let url = Bundle.main.url(forResource: resourceName, withExtension: ext, subdirectory: subdirectory) {
                return url
            }
        }

        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        let resourceURL = URL(fileURLWithPath: resourcePath)
        let files = FileManager.default.enumerator(at: resourceURL, includingPropertiesForKeys: nil)
        while let candidate = files?.nextObject() as? URL {
            if candidate.lastPathComponent == fileName {
                return candidate
            }
        }

        return nil
    }
}

private struct VideoLoopManifest: Decodable {
    let loops: [VideoLoopRecord]
}

private struct VideoLoopRecord: Decodable {
    let id: String?
    let addictionType: String
    let fileName: String
    let title: String?
}

// MARK: - Looping Video View
struct LoopingVideoView: UIViewRepresentable {
    let url: URL
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> LoopingPlayerView {
        let view = LoopingPlayerView()
        context.coordinator.configure(url: url, videoGravity: videoGravity, on: view)
        return view
    }

    func updateUIView(_ view: LoopingPlayerView, context: Context) {
        context.coordinator.configure(url: url, videoGravity: videoGravity, on: view)
    }

    static func dismantleUIView(_ view: LoopingPlayerView, coordinator: Coordinator) {
        coordinator.stop()
        view.playerLayer.player = nil
    }

    final class Coordinator {
        private var currentURL: URL?
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?

        func configure(url: URL, videoGravity: AVLayerVideoGravity, on view: LoopingPlayerView) {
            view.playerLayer.videoGravity = videoGravity

            guard currentURL != url else {
                player?.play()
                return
            }

            stop()

            let item = AVPlayerItem(url: url)
            let queue = AVQueuePlayer()
            queue.isMuted = true
            queue.actionAtItemEnd = .none

            looper = AVPlayerLooper(player: queue, templateItem: item)
            player = queue
            currentURL = url
            view.playerLayer.player = queue
            queue.play()
        }

        func stop() {
            player?.pause()
            looper = nil
            player = nil
            currentURL = nil
        }
    }
}

final class LoopingPlayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
