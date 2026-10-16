import SwiftUI
import DSHProtocol

/// Desktop `TextShimmer`: a 1.5s masked sweep over tertiary text while a row is running.
struct TextShimmer<Content: View>: View {
    var active: Bool
    @ViewBuilder var content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false

    var body: some View {
        let body = content()
        body
            .overlay {
                if active && !reduceMotion {
                    body
                        .foregroundStyle(T.caption)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white, location: 0.4),
                                    .init(color: .white, location: 0.6),
                                    .init(color: .clear, location: 1),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .scaleEffect(x: 1.4, y: 1, anchor: .center)
                            .offset(x: phase ? 80 : -80)
                        )
                        .allowsHitTesting(false)
                }
            }
            .onAppear { animate() }
            .onChange(of: active) { _ in animate() }
    }

    private func animate() {
        guard active, !reduceMotion else { return }
        phase = false
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
