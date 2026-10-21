import SwiftUI
import DSHProtocol

/// Matches `.details`: inline split on desktop, a 92%-width end overlay below 760pt.
struct TrajectoryInspectorLayout<Rows: View, Detail: View>: View {
    let isPresented: Bool
    @ViewBuilder var rows: () -> Rows
    @ViewBuilder var detail: () -> Detail
    @State private var resizedWidth: CGFloat?
    @State private var dragStartWidth: CGFloat?

    var body: some View {
        GeometryReader { geometry in
            let narrow = geometry.size.width <= 760
            let width = narrow
                ? min(geometry.size.width * 0.92, 420)
                : min(max(resizedWidth ?? geometry.size.width * 0.38, 320), geometry.size.width - 280, resizedWidth == nil ? 440 : .infinity)
            ZStack(alignment: .trailing) {
                rows().padding(.trailing, isPresented && !narrow ? width : 0)
                if isPresented {
                    detail()
                        .frame(width: width)
                        .shadow(color: narrow ? .black.opacity(0.14) : .clear, radius: 16, x: -12)
                        .overlay(alignment: .leading) {
                            if !narrow {
                                Color.clear
                                    .frame(width: 8)
                                    .contentShape(Rectangle())
                                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                                        if dragStartWidth == nil { dragStartWidth = width }
                                        resizedWidth = min(max((dragStartWidth ?? width) - value.translation.width, 320), geometry.size.width - 280)
                                    }.onEnded { _ in dragStartWidth = nil })
                                    .accessibilityLabel(TrajL.en ? "Resize details" : "调整详情宽度")
                                    .accessibilityAdjustableAction { direction in
                                        resizedWidth = min(max(width + (direction == .increment ? 24 : -24), 320), geometry.size.width - 280)
                                    }
                            }
                        }
                }
            }
            .clipped()
        }
    }
}

/// Official `ui-trajectory` inspector header, tabs and overview typography.
struct TrajectoryInspectorFrame<Tab: Hashable, Content: View>: View {
    let title: String
    let location: String
    var kind: String? = nil
    let tabs: [Tab]
    let selection: Tab
    let label: (Tab) -> String
    let onSelect: (Tab) -> Void
    let onDismiss: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if let kind {
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(badgeForeground(kind))
                        .padding(.horizontal, 5)
                        .frame(height: 19)
                        .background(badgeBackground(kind), in: RoundedRectangle(cornerRadius: 3))
                        .accessibilityAddTraits(.isHeader)
                } else {
                    Circle().fill(T.text2).frame(width: 5, height: 5)
                    Text(title)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(T.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                Text(location)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(T.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("trajectoryInspector.location")
                Button(action: onDismiss) {
                    Text("×")
                        .font(.system(size: 18))
                        .foregroundStyle(T.text2)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(TrajL.detailsClose)
            }
            .lineLimit(1)
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .frame(height: 42)
            .overlay(alignment: .bottom) { T.border.frame(height: 0.5) }
            .accessibilityIdentifier("trajectoryInspector.header")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(tabs, id: \.self) { tab in
                        Button { onSelect(tab) } label: {
                            Text(label(tab))
                                .font(.system(size: 13))
                                .foregroundStyle(selection == tab ? T.businessPrimary : T.text3)
                                .padding(.horizontal, 9)
                                .frame(height: 34)
                                .overlay(alignment: .bottom) {
                                    if selection == tab {
                                        T.businessPrimary.frame(height: 2).padding(.horizontal, 9)
                                    }
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selection == tab ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 34)
            .overlay(alignment: .bottom) { T.border.frame(height: 0.5) }
            .accessibilityIdentifier("trajectoryInspector.tabs")

            ScrollView {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            .id(selection)
            .accessibilityIdentifier("trajectoryInspector.content")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.surface)
        .overlay(alignment: .leading) { T.borderL3.frame(width: 0.5) }
        .accessibilityIdentifier("trajectoryInspector")
        .accessibilityAction(.escape, onDismiss)
    }

    private func badgeForeground(_ kind: String) -> Color {
        switch kind {
        case TrajL.kindUser: return T.businessPrimary
        case TrajL.kindContext: return T.trajectoryContext
        case TrajL.kindAssistant: return T.trajectoryAssistant
        case TrajL.kindTool: return T.warnText
        case TrajL.kindSubtool: return T.warnText.opacity(0.62)
        default: return T.text2
        }
    }

    private func badgeBackground(_ kind: String) -> Color {
        switch kind {
        case TrajL.kindUser: return T.tint
        case TrajL.kindContext: return T.trajectoryContextBg
        case TrajL.kindAssistant: return T.trajectoryAssistantBg
        case TrajL.kindTool: return T.warnTint
        case TrajL.kindSubtool: return T.warnTint.opacity(0.58)
        default: return T.fill2
        }
    }
}

struct TrajectoryOverviewLine: View {
    let label: String
    let value: String
    var valueColor: Color = T.ink
    var onOpen: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(label).foregroundStyle(T.text3).frame(width: 94, alignment: .leading)
            if let onOpen {
                Button(action: onOpen) {
                    HStack(spacing: 1) {
                        Text(value).foregroundStyle(valueColor)
                        OfficialGlyph(kind: .chevronRight, size: 12, color: T.caption)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label) \(value)")
            } else {
                Text(value).foregroundStyle(valueColor).textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 13))
        .frame(minHeight: 22, alignment: .leading)
    }
}

struct TrajectoryOverviewSection<Content: View>: View {
    let title: String
    var onOpen: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let onOpen {
                    Button(action: onOpen) { heading }
                        .buttonStyle(.plain)
                } else {
                    heading
                }
            }
            .padding(.bottom, 3)
            .frame(height: 24, alignment: .bottomLeading)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heading: some View {
        HStack(spacing: 3) {
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(T.text2)
            if onOpen != nil {
                OfficialGlyph(kind: .chevronRight, size: 12, color: T.caption)
            }
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isHeader)
    }
}
