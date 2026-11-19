import SwiftUI

/// Keep forms readable in a wide window while retaining the system safe areas.
extension View {
    func readableContent(maxWidth: CGFloat = 720) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

/// A native sidebar on iPad/Duo, with the existing tab bar on older systems.
struct AdaptiveTabPresentation: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.tabViewStyle(.sidebarAdaptable)
        } else {
            content
        }
    }
}

/// Reflows cards without replacing their identities or losing local state.
struct AdaptiveCardsLayout: Layout {
    var columns: Int
    var spacing: CGFloat = 20

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let columns = columnCount(for: width)
        let cellWidth = max(0, (width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        let heights = rowHeights(subviews: subviews, width: cellWidth, columns: columns)
        return CGSize(width: width, height: heights.reduce(0, +) + spacing * CGFloat(max(0, heights.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = columnCount(for: bounds.width)
        let width = max(0, (bounds.width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        let heights = rowHeights(subviews: subviews, width: width, columns: columns)
        var y = bounds.minY
        for (index, subview) in subviews.enumerated() {
            let column = index % columns
            subview.place(at: CGPoint(x: bounds.minX + CGFloat(column) * (width + spacing), y: y),
                          anchor: .topLeading, proposal: ProposedViewSize(width: width, height: nil))
            if column == columns - 1 { y += heights[index / columns] + spacing }
        }
    }

    private func columnCount(for width: CGFloat) -> Int {
        // A card needs at least 320 points, including its internal padding.
        max(1, min(columns, Int((max(0, width) + spacing) / (320 + spacing))))
    }

    private func rowHeights(subviews: Subviews, width: CGFloat, columns: Int) -> [CGFloat] {
        stride(from: 0, to: subviews.count, by: columns).map { start in
            (start..<min(start + columns, subviews.count)).map {
                subviews[$0].sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            }.max() ?? 0
        }
    }
}
