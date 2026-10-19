import SwiftUI
import DSHProtocol

/// Desktop `MenuView` `.menu` is `max-height: 400px` with a scrolling
/// `.viewport`. Measure the rows and only take the leftover height when
/// content actually overflows — never stretch a short catalog to the
/// remaining transcript.
struct MenuViewViewport<Content: View>: View {
    var maxHeight: CGFloat
    @ViewBuilder var content: Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            content
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: MenuViewViewportHeightKey.self, value: geo.size.height)
                    }
                )
        }
        .frame(maxHeight: min(measuredHeight, maxHeight), alignment: .top)
        .onPreferenceChange(MenuViewViewportHeightKey.self) { next in
            if next != contentHeight { contentHeight = next }
        }
    }

    private var measuredHeight: CGFloat {
        contentHeight > 0 ? contentHeight : maxHeight
    }
}

private struct MenuViewViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
