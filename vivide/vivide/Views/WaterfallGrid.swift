import SwiftUI

enum WaterfallGridMetrics {
    static let defaultSpacing: CGFloat = 10
    static let horizontalPadding: CGFloat = 16

    static func columnCount(for containerWidth: CGFloat) -> Int {
        switch containerWidth {
        case 520...: return 4
        case 390..<520: return 3
        default: return 2
        }
    }

    /// Normalizes height / width for column balancing. Extreme panoramas or portraits are clamped.
    static func normalizedHeightToWidth(width: Int, height: Int) -> CGFloat {
        guard width > 0, height > 0 else { return 1 }
        let ratio = CGFloat(height) / CGFloat(width)
        return min(max(ratio, 0.55), 1.85)
    }

    /// Width / height used by SwiftUI `aspectRatio`, with the same clamp applied.
    static func displayAspectRatio(width: Int, height: Int) -> CGFloat {
        let heightToWidth = normalizedHeightToWidth(width: width, height: height)
        return 1 / heightToWidth
    }
}

enum WaterfallColumnDistribution {
    static func distribute<Item>(
        items: [Item],
        columnCount: Int,
        normalizedHeight: (Item) -> CGFloat
    ) -> [[Item]] {
        guard columnCount > 0 else { return [] }

        var columns = Array(repeating: [Item](), count: columnCount)
        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)

        for item in items {
            let shortestIndex = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[shortestIndex].append(item)
            columnHeights[shortestIndex] += normalizedHeight(item)
        }

        return columns
    }
}

struct WaterfallGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let columnCount: Int
    let spacing: CGFloat
    let normalizedHeight: (Item) -> CGFloat
    @ViewBuilder let content: (Item) -> Content

    private var columns: [[Item]] {
        WaterfallColumnDistribution.distribute(
            items: items,
            columnCount: max(columnCount, 1),
            normalizedHeight: normalizedHeight
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, columnItems in
                LazyVStack(spacing: spacing) {
                    ForEach(columnItems) { item in
                        content(item)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct AdaptiveWaterfallGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    let normalizedHeight: (Item) -> CGFloat
    @ViewBuilder let content: (Item) -> Content

    @State private var containerWidth: CGFloat = UIScreen.main.bounds.width - WaterfallGridMetrics.horizontalPadding * 2

    var body: some View {
        WaterfallGrid(
            items: items,
            columnCount: WaterfallGridMetrics.columnCount(for: containerWidth),
            spacing: spacing,
            normalizedHeight: normalizedHeight,
            content: content
        )
        .background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: WaterfallWidthPreferenceKey.self, value: proxy.size.width)
            }
        }
        .onPreferenceChange(WaterfallWidthPreferenceKey.self) { width in
            guard width > 0, abs(width - containerWidth) > 0.5 else { return }
            containerWidth = width
        }
    }
}

private struct WaterfallWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
