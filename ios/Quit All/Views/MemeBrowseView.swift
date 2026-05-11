import SwiftUI

// MARK: - Meme Browse View
// Browsable library with local video loops + text memes, filterable by type and category.
struct MemeBrowseView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: AddictionType? = nil
    @State private var selectedCategory: MemeCategory? = nil
    @State private var klipyLoops: [KlipyMediaItem] = []
    @State private var videoLoops: [LocalVideoLoop] = []
    @State private var klipyLoadTask: Task<Void, Never>?

    private var filteredMemes: [MemeItem] {
        MemeLibrary.shared.filteredMemes(type: selectedType, category: selectedCategory)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Type filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(label: "All", isSelected: selectedType == nil) {
                            selectedType = nil
                            klipyLoadTask?.cancel()
                            klipyLoops = []
                            videoLoops = []
                        }
                        ForEach(AddictionType.allCases, id: \.self) { type in
                            filterChip(
                                label: "\(type.emoji) \(type.rawValue)",
                                isSelected: selectedType == type,
                                color: type.color
                            ) {
                                selectedType = selectedType == type ? nil : type
                                if let t = selectedType {
                                    loadLoops(for: t)
                                } else {
                                    klipyLoadTask?.cancel()
                                    klipyLoops = []
                                    videoLoops = []
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(label: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(MemeCategory.allCases, id: \.self) { cat in
                            filterChip(
                                label: "\(cat.emoji) \(cat.rawValue)",
                                isSelected: selectedCategory == cat
                            ) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        // Video loop section (if a type is selected)
                        if !klipyLoops.isEmpty || !videoLoops.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Loops")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        if !klipyLoops.isEmpty {
                                            ForEach(klipyLoops) { loop in
                                                RemoteGIFView(url: loop.gifURL)
                                                    .frame(width: 180, height: 180)
                                                    .background(Color(hex: "111111"))
                                                    .cornerRadius(12)
                                                    .overlay(alignment: .topTrailing) {
                                                        sourceBadge("KLIPY")
                                                    }
                                                    .clipped()
                                            }
                                        } else {
                                            ForEach(videoLoops) { loop in
                                                LoopingVideoView(url: loop.url)
                                                    .frame(width: 180, height: 180)
                                                    .background(Color(hex: "111111"))
                                                    .cornerRadius(12)
                                                    .overlay(alignment: .topTrailing) {
                                                        sourceBadge("OFFLINE")
                                                    }
                                                    .clipped()
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .frame(height: 180)
                            }
                        }

                        // Text memes grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(filteredMemes) { meme in
                                memeCard(meme)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color(hex: "0A0A0A"))
            .navigationTitle("Memes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onDisappear {
                klipyLoadTask?.cancel()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func filterChip(label: String, isSelected: Bool, color: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.selection()
            action()
        }) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? color : Color(hex: "141414"))
                .cornerRadius(20)
        }
    }

    private func memeCard(_ meme: MemeItem) -> some View {
        let type = AddictionType(rawValue: meme.addictionType) ?? .smoking

        return VStack(spacing: 8) {
            Text(meme.category.emoji)
                .font(.system(size: 32))

            Text(meme.text)
                .font(.caption)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(4)

            Text(meme.category.rawValue)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(type.color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(Color(hex: "141414"))
        .cornerRadius(16)
    }

    private func loadLoops(for type: AddictionType) {
        klipyLoadTask?.cancel()
        klipyLoops = []
        videoLoops = LocalVideoLoopLibrary.shared.loops(for: type)
        klipyLoadTask = Task {
            let remoteLoops = await KlipyMediaLibrary.shared.searchLoops(for: type, count: 24)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                klipyLoops = remoteLoops
            }
        }
    }

    private func sourceBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .serif))
            .foregroundColor(text == "KLIPY" ? .black : .white.opacity(0.75))
            .tracking(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(text == "KLIPY" ? Color(hex: "D4AF37") : Color.black.opacity(0.55))
            .cornerRadius(10)
            .padding(8)
    }
}
