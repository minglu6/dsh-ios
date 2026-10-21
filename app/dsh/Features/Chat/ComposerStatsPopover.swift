import SwiftUI
import DSHProtocol

struct ComposerStatsPopover {
    let anchor: Anchor<CGRect>
    let content: AnyView
    let dismiss: () -> Void
}

struct ComposerStatsPopoverKey: PreferenceKey {
    static var defaultValue: ComposerStatsPopover? = nil
    static func reduce(value: inout ComposerStatsPopover?, nextValue: () -> ComposerStatsPopover?) {
        if let next = nextValue() { value = next }
    }
}

/// Like the desktop portal, leaves sibling statistic buttons interactive.
struct ComposerStatsPopoverLayer: View {
    let presentation: ComposerStatsPopover

    var body: some View {
        GeometryReader { canvas in
            let anchor = canvas[presentation.anchor]
            StatisticsPanelLayout(anchor: anchor, viewport: canvas.size) {
                Color.clear
                    .frame(height: max(0, anchor.minY))
                    .contentShape(Rectangle())
                    .onTapGesture(perform: presentation.dismiss)
                    .accessibilityHidden(true)
                    .frame(maxHeight: .infinity, alignment: .top)
                presentation.content
                    .background(T.settingsCard)
                    .clipShape(RoundedRectangle(cornerRadius: CGFloat(mentionMenuSurfaceRadiusPoints)))
                    .overlay(RoundedRectangle(cornerRadius: CGFloat(mentionMenuSurfaceRadiusPoints))
                        .stroke(T.borderL1, lineWidth: CGFloat(mentionMenuStrokeWidthPoints)))
                    .shadow(color: Color.black.opacity(mentionMenuShadowOpacity),
                            radius: CGFloat(mentionMenuShadowRadiusPoints), y: CGFloat(mentionMenuShadowYPoints))
            }
        }
    }
}

private struct StatisticsPanelLayout: Layout {
    let anchor: CGRect
    let viewport: CGSize

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { viewport }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
        let margin: CGFloat = 12
        let width = min(CGFloat(composerStatDialogMaxWidth(screenWidth: Double(viewport.width))), max(0, viewport.width - 2 * margin))
        let size = subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil))
        let x = max(margin, min(anchor.midX - size.width / 2, viewport.width - margin - size.width))
        let y = max(margin, anchor.minY - 8 - size.height)
        subviews[1].place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), anchor: .topLeading,
                          proposal: ProposedViewSize(size))
    }
}
