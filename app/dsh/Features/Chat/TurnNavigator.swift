import SwiftUI
import DSHProtocol

/// Desktop tick geometry with a wider touch lane and long-press preview on phones.
struct TurnNavigator: View {
    let items: [TranscriptTurnMark]
    let activeTurn: Int?
    let busyTurn: Int?
    let onNavigate: (TranscriptTurnMark) -> Void
    @State private var previewTurn: Int?
    @State private var touching = false

    var body: some View {
        GeometryReader { geometry in
            if items.count >= 2 {
                let height = min(420, max(0, geometry.size.height - 64), CGFloat(items.count * 16 + 12))
                HStack(spacing: 8) {
                    if let item = items.first(where: { $0.turn == previewTurn }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.prompt.isEmpty ? label(item.turn) : item.prompt)
                                .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                            if !item.response.isEmpty {
                                Text(item.response).font(.system(size: 12)).foregroundStyle(T.text3).lineLimit(3)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .frame(width: min(280, max(1, geometry.size.width - 72)), alignment: .leading)
                        .background(T.surface, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                        .accessibilityIdentifier("transcriptTurnPreview")
                        .onTapGesture { previewTurn = nil }
                    }
                    ScrollViewReader { reader in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(items) { item in
                                    Button {
                                        previewTurn = nil
                                        onNavigate(item)
                                    } label: {
                                        ZStack(alignment: .trailing) {
                                            Color.clear
                                            Capsule().fill(item.turn == activeTurn ? T.ink : T.borderStrong)
                                                .opacity(item.anchorKey == nil && item.turn != activeTurn ? 0.6 : 1)
                                                .frame(width: item.turn == activeTurn ? 20 : (item.anchorKey == nil ? 8 : 12), height: 2)
                                            if item.turn == busyTurn {
                                                Circle().fill(T.ink).frame(width: 4, height: 4).frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                        .frame(width: 44, height: 16).contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .highPriorityGesture(LongPressGesture().onEnded { _ in previewTurn = item.turn })
                                    .accessibilityLabel(item.anchorKey == nil ? L.t("加载并跳转到\(label(item.turn))", "Load and jump to \(label(item.turn))") : L.t("跳转到\(label(item.turn))", "Jump to \(label(item.turn))"))
                                    .accessibilityValue(item.turn == busyTurn ? L.t("正在加载", "Loading") : (item.turn == activeTurn ? L.t("当前轮次", "Current turn") : ""))
                                    .accessibilityAddTraits(item.turn == activeTurn ? [.isSelected] : [])
                                    .accessibilityIdentifier("transcript-turn-\(item.turn)")
                                    .accessibilityAction(named: L.t("预览", "Preview")) { previewTurn = item.turn }
                                    .id(item.turn)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .frame(width: 44, height: height)
                        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in touching = true; previewTurn = nil }.onEnded { _ in touching = false })
                        .onAppear { if let activeTurn { reader.scrollTo(activeTurn, anchor: .center) } }
                        .onChange(of: activeTurn) { turn in
                            if !touching, let turn { reader.scrollTo(turn, anchor: .center) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 12)
                .accessibilityIdentifier("transcriptTurnNavigator")
            }
        }
    }

    private func label(_ turn: Int) -> String { L.t("第\(turn)轮", "Turn \(turn)") }
}

struct TranscriptViewport: Equatable {
    var rows: [String: CGRect] = [:]
    var bottom: CGFloat?
}

struct TranscriptViewportKey: PreferenceKey {
    static let defaultValue = TranscriptViewport()
    static func reduce(value: inout TranscriptViewport, nextValue: () -> TranscriptViewport) {
        let next = nextValue()
        value.rows.merge(next.rows, uniquingKeysWith: { _, new in new })
        if let bottom = next.bottom { value.bottom = bottom }
    }
}

struct TranscriptRowMeasurement: View {
    let key: String
    var body: some View {
        GeometryReader { geometry in
            Color.clear.preference(key: TranscriptViewportKey.self,
                value: TranscriptViewport(rows: [key: geometry.frame(in: .named("chatTranscriptViewport"))]))
        }
    }
}
