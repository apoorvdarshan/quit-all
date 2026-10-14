import XCTest
@testable import Quit_All

/// The SOS screen shows 15 memes and up to 15 bundled offline video loops.
final class ContentLibraryTests: QuitAllTestCase {
    func testEveryHabitHasEnoughMemesForAnSOSSession() {
        let library = MemeLibrary.shared
        for type in AddictionType.allCases {
            let memes = library.memesForType(type)
            XCTAssertGreaterThanOrEqual(memes.count, 15, type.rawValue)
            XCTAssertTrue(memes.allSatisfy { $0.addictionType == type.rawValue }, type.rawValue)
            XCTAssertTrue(memes.allSatisfy { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }, type.rawValue)

            let session = library.randomMemes(for: type, count: 15)
            XCTAssertEqual(session.count, 15, type.rawValue)
            XCTAssertEqual(Set(session.map(\.id)).count, 15, "\(type.rawValue): no repeats in one session")
        }
    }

    func testMemeFiltersCombineHabitAndCategory() {
        let library = MemeLibrary.shared
        XCTAssertEqual(Set(library.allMemes.map(\.category)), Set(MemeCategory.allCases))
        XCTAssertEqual(library.filteredMemes(type: nil, category: nil).count, library.allMemes.count)

        let roasts = library.filteredMemes(type: .alcohol, category: .roast)
        XCTAssertFalse(roasts.isEmpty)
        XCTAssertTrue(roasts.allSatisfy { $0.addictionType == "Alcohol" && $0.category == .roast })
        XCTAssertEqual(
            library.memesForCategory(.distraction).count,
            AddictionType.allCases.map { library.filteredMemes(type: $0, category: .distraction).count }.reduce(0, +)
        )
    }

    func testEveryManifestLoopIsBundled() throws {
        let manifestURL = try XCTUnwrap(Bundle.main.url(forResource: "VideoLoops", withExtension: "json"))
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
        let library = LocalVideoLoopLibrary.shared

        let bundled = AddictionType.allCases.flatMap { library.loops(for: $0) }
        XCTAssertEqual(bundled.count, manifest.loops.count, "every VideoLoops.json entry resolves to a bundled file")
        XCTAssertEqual(Set(bundled.map(\.id)).count, bundled.count, "loop ids are unique")
        for loop in bundled {
            XCTAssertTrue(FileManager.default.fileExists(atPath: loop.url.path), loop.id)
        }
        for type in AddictionType.allCases {
            XCTAssertFalse(library.loops(for: type).isEmpty, "\(type.rawValue) has offline loops")
        }
    }

    func testRandomLoopsPreferFreshClipsWithoutRepeats() throws {
        let library = LocalVideoLoopLibrary.shared
        let smoking = library.loops(for: .smoking)
        let recent = Set(smoking.prefix(5).map(\.id))

        let picked = library.randomLoops(preferredTypes: [.smoking], count: 10, excluding: recent)

        XCTAssertEqual(picked.count, 10)
        XCTAssertEqual(Set(picked.map(\.id)).count, 10)
        XCTAssertTrue(picked.allSatisfy { !recent.contains($0.id) }, "recently shown clips come last")
        XCTAssertTrue(library.randomLoops(preferredTypes: [.smoking], count: 0, excluding: []).isEmpty)
        XCTAssertEqual(library.randomLoops(for: .caffeine, count: 3).map(\.addictionType), [.caffeine, .caffeine, .caffeine])
    }

    private struct Manifest: Decodable {
        struct Loop: Decodable {
            let fileName: String
        }
        let loops: [Loop]
    }
}
