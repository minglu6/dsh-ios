import SwiftUI
import DSHProtocol

struct SettingsSelectOption: Identifiable {
    let id: String
    let title: String
    var icon: OfficialGlyph.Kind? = nil
}

/// Desktop PreferenceRow / Menu: a trailing selector and an end-aligned portal.
struct SettingsSelect: View {
    let id: String
    let title: String
    let value: String
    let options: [SettingsSelectOption]
    var fallbackLabel: String = ""
    var enabled = true
    var loading = false
    @Binding var active: String?
    let onSelect: (String) -> Void
    @ScaledMetric(relativeTo: .subheadline) private var fontSize: CGFloat = 14
    @AccessibilityFocusState private var focused: Bool

    private var open: Bool { active == id }
    private var label: String { options.first { $0.id == value }?.title ?? fallbackLabel }

    var body: some View {
        Button { active = open ? nil : id } label: {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: fontSize))
                    .fixedSize(horizontal: false, vertical: true)
                OfficialGlyph(kind: .chevronDown, size: 14, color: T.text2)
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
            .foregroundStyle(T.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(open ? T.hoverBg : T.fill2, in: RoundedRectangle(cornerRadius: CGFloat(settingsPermissionSelectorRadiusPoints)))
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(title)
        .accessibilityValue(label)
        .accessibilityIdentifier(id == "permission" ? settingsPermissionSelectSymbol() : "settingsSelect.\(id)")
        .accessibilityFocused($focused)
        .anchorPreference(key: SettingsSelectAnchors.self, value: .bounds) { anchor in
            [id: SettingsSelectPresentation(anchor: anchor, content: open && enabled ? AnyView(menu) : nil)]
        }
        .onChange(of: enabled) { allowed in
            if !allowed && open { active = nil }
        }
    }

    private var menu: some View {
        SettingsSelectMenu(id: id, value: value, options: options, loading: loading) { option in
            active = nil
            focused = true
            if option != value { onSelect(option) }
        }
    }
}

struct SettingsSelectRow: View {
    let id: String
    let title: String
    var description: String? = nil
    let value: String
    let options: [SettingsSelectOption]
    var enabled = true
    @Binding var active: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    labels
                    Spacer(minLength: 8)
                    selector
                }
                VStack(alignment: .leading, spacing: 8) {
                    labels
                    selector.frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .opacity(enabled ? 1 : 0.5)
            Divider().padding(.leading, 16)
        }
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).foregroundStyle(T.ink)
            if let description, !description.isEmpty {
                Text(description).font(.caption).foregroundStyle(T.text3)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var selector: some View {
        SettingsSelect(id: id, title: title, value: value, options: options,
                       enabled: enabled, active: $active, onSelect: onSelect)
    }
}

struct SettingsSelectMenu: View {
    let id: String
    let value: String
    let options: [SettingsSelectOption]
    let loading: Bool
    let onSelect: (String) -> Void
    @ScaledMetric(relativeTo: .subheadline) private var fontSize: CGFloat = 13

    var body: some View {
        ViewThatFits(in: .vertical) {
            rows
            ScrollView { rows }
        }
        .padding(4)
        .background(T.surface2)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(mentionMenuSurfaceRadiusPoints)))
        .overlay(RoundedRectangle(cornerRadius: CGFloat(mentionMenuSurfaceRadiusPoints)).stroke(T.borderL1, lineWidth: CGFloat(mentionMenuStrokeWidthPoints)))
        .shadow(color: .black.opacity(mentionMenuShadowOpacity), radius: CGFloat(mentionMenuShadowRadiusPoints), y: CGFloat(mentionMenuShadowYPoints))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id == "permission" ? "settingsPermissionMenu" : "settingsSelectMenu.\(id)")
    }

    private var rows: some View {
        VStack(spacing: 0) {
            if loading { ProgressView().frame(maxWidth: .infinity).padding(8) }
            ForEach(options) { option in
                Button { onSelect(option.id) } label: {
                    HStack(spacing: 6) {
                        if let icon = option.icon { OfficialGlyph(kind: icon, size: 14, color: T.ink) }
                        Text(option.title)
                            .font(.system(size: fontSize))
                            .foregroundStyle(T.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        OfficialGlyph(kind: .checkOutline, size: 14, color: T.ink)
                            .opacity(option.id == value ? 1 : 0)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SettingsSelectItemStyle())
                .accessibilityAddTraits(option.id == value ? [.isSelected] : [])
                .accessibilityIdentifier("settingsSelectOption.\(id).\(option.id)")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SettingsSelectItemStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? T.hoverBg : .clear,
                                       in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SettingsSelectPresentation {
    let anchor: Anchor<CGRect>
    let content: AnyView?
}

private struct SettingsSelectAnchors: PreferenceKey {
    static var defaultValue: [String: SettingsSelectPresentation] = [:]
    static func reduce(value: inout [String: SettingsSelectPresentation], nextValue: () -> [String: SettingsSelectPresentation]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

struct SettingsSelectOverlay: ViewModifier {
    @Binding var active: String?

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(SettingsSelectAnchors.self) { anchors in
            if let active, let presentation = anchors[active], let menu = presentation.content {
                GeometryReader { canvas in
                    let anchor = canvas[presentation.anchor]
                    if canvas.frame(in: .local).intersects(anchor) {
                        SettingsSelectLayout(anchor: anchor, viewport: canvas.size) {
                            let backdrop = SettingsSelectBackdrop(holes: anchors.values.map { canvas[$0.anchor] })
                            Color.clear
                                .contentShape(backdrop, eoFill: true)
                                .onTapGesture { self.active = nil }
                                .gesture(DragGesture(minimumDistance: 8).onChanged { _ in self.active = nil })
                                .accessibilityHidden(true)
                            menu
                                .accessibilityAction(.escape) { self.active = nil }
                        }
                    }
                }
            }
        }
        .onDisappear { active = nil }
    }
}

/// Leave selector buttons hit-testable so another menu opens on the first tap.
private struct SettingsSelectBackdrop: Shape {
    let holes: [CGRect]
    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        for hole in holes where hole.intersects(rect) { path.addRect(hole.intersection(rect)) }
        return path
    }
}

struct SettingsSelectLayout: Layout {
    let anchor: CGRect
    let viewport: CGSize

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { viewport }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
        let width = min(max(144, anchor.width, subviews[1].sizeThatFits(.unspecified).width), min(360, max(0, viewport.width - 24)))
        let ideal = subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil))
        let frame = Self.menuFrame(anchor: anchor, viewport: viewport, size: CGSize(width: width, height: ideal.height))
        subviews[1].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          anchor: .topLeading, proposal: ProposedViewSize(frame.size))
    }

    static func menuFrame(anchor: CGRect, viewport: CGSize, size: CGSize) -> CGRect {
        let margin: CGFloat = 12
        let gap: CGFloat = 4
        let below = max(0, viewport.height - margin - anchor.maxY - gap)
        let above = max(0, anchor.minY - gap - margin)
        let opensBelow = size.height <= below || below >= above
        let height = min(size.height, opensBelow ? below : above)
        let width = min(size.width, max(0, viewport.width - 2 * margin))
        let x = max(margin, min(anchor.maxX - width, viewport.width - margin - width))
        let y = opensBelow ? anchor.maxY + gap : anchor.minY - gap - height
        return CGRect(x: x, y: max(margin, y), width: width, height: height)
    }
}
