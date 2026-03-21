import Foundation

// MARK: - Meme Library Manager
// Manages local text memes for browsing and SOS screen.
@Observable
final class MemeLibrary {
    static let shared = MemeLibrary()

    var allMemes: [MemeItem] = []

    private init() {
        loadAllMemes()
    }

    func loadAllMemes() {
        allMemes = AddictionType.allCases.flatMap { type in
            MemeDataLibrary.textMemes(for: type)
        }
    }

    func memesForType(_ type: AddictionType) -> [MemeItem] {
        allMemes.filter { $0.addictionType == type.rawValue }
    }

    func memesForCategory(_ category: MemeCategory) -> [MemeItem] {
        allMemes.filter { $0.category == category }
    }

    func filteredMemes(type: AddictionType?, category: MemeCategory?) -> [MemeItem] {
        var result = allMemes
        if let type = type {
            result = result.filter { $0.addictionType == type.rawValue }
        }
        if let category = category {
            result = result.filter { $0.category == category }
        }
        return result
    }

    func randomMeme(for type: AddictionType) -> MemeItem? {
        memesForType(type).randomElement()
    }

    func randomMemes(for type: AddictionType, count: Int = 10) -> [MemeItem] {
        Array(memesForType(type).shuffled().prefix(count))
    }
}
