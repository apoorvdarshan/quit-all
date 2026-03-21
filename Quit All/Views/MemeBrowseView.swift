import SwiftUI

// MARK: - Meme Browse View
// Full browsable library of addiction memes with category/type filters.
struct MemeBrowseView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: AddictionType? = nil
    @State private var selectedCategory: MemeCategory? = nil

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
                        }
                        ForEach(AddictionType.allCases, id: \.self) { type in
                            filterChip(
                                label: "\(type.emoji) \(type.rawValue)",
                                isSelected: selectedType == type,
                                color: type.color
                            ) {
                                selectedType = selectedType == type ? nil : type
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

                // Meme grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(filteredMemes) { meme in
                            memeCard(meme)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
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
}
