import SwiftUI

/// Desktop `TextShimmer`: a 1.5s masked sweep over tertiary text while a row is running.
struct TextShimmer<Content: View>: View {
    var active: Bool
    @ViewBuilder var content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false

    var body: some View {
        content()
            .mask {
                if active && !reduceMotion {
                    GeometryReader { geometry in
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.65), location: 0),
                                .init(color: .white.opacity(0.65), location: 0.4),
                                .init(color: .white, location: 0.5),
                                .init(color: .white.opacity(0.65), location: 0.6),
                                .init(color: .white.opacity(0.65), location: 1),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 3)
                        .offset(x: phase ? 0 : -geometry.size.width * 2)
                    }
                } else {
                    Color.white
                }
            }
            .onAppear { animate() }
            .onChange(of: active) { _ in animate() }
            .onChange(of: reduceMotion) { _ in animate() }
    }

    private func animate() {
        phase = false
        guard active, !reduceMotion else { return }
        withAnimation(.linear(duration: 1.5).delay(0.3).repeatForever(autoreverses: false)) {
            phase = true
        }
    }
}

extension TextShimmer where Content == Text {
    init(text: String, active: Bool) {
        self.active = active
        self.content = { Text(text) }
    }
}
