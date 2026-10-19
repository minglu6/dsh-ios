import SwiftUI
import UIKit
import DSHProtocol

/// Desktop `ConversationRoot.module.css` `.titleRow` (min-height 30, header
/// padding-top 10). Shared by landing (headerBlank, no tabs) and ChatView.
struct ConversationTitleRow<Title: View>: View {
    var onOpenDrawer: () -> Void
    var onOpenStart: () -> Void
    var startDisabled: Bool
    @ViewBuilder var title: () -> Title

    var body: some View {
        HStack(spacing: CGFloat(conversationHeaderTitleClusterGapPoints)) {
            Button {
                Keyboard.dismiss()
                onOpenDrawer()
            } label: {
                OfficialGlyph(kind: .panelLeft, size: 16, color: T.ink)
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("openDrawer")
            title()
            Spacer(minLength: 0)
            Button {
                Keyboard.dismiss()
                onOpenStart()
            } label: {
                OfficialGlyph(kind: .panelRight, size: 16, color: T.ink)
            }
            .disabled(startDisabled)
            .accessibilityLabel(L.startPanel())
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("openStartPanel")
        }
        .frame(minHeight: CGFloat(conversationHeaderTitleRowMinHeightPoints), alignment: .center)
        .background {
            ConversationTitleRowBoundsHost()
        }
        .padding(.top, CGFloat(conversationHeaderPaddingTopPoints))
        .padding(.horizontal, CGFloat(conversationHeaderPaddingHorizontalPoints))
    }
}

/// XCUI geometry leaf the same size as `.titleRow` (min-height 30). Clear
/// UIKit view, hits disabled — same pattern as `PairingFieldBoundsHost`.
private struct ConversationTitleRowBoundsHost: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = UITestLaunch.isEnabled
        view.accessibilityIdentifier = conversationTitleRowIdentifier()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        view.isAccessibilityElement = UITestLaunch.isEnabled
        view.accessibilityIdentifier = conversationTitleRowIdentifier()
    }
}

func conversationHeaderTitleFont() -> Font {
    .system(size: CGFloat(conversationHeaderTitleFontSizePoints), weight: .medium)
}

func conversationHeaderTabFont() -> Font {
    .system(size: CGFloat(conversationHeaderTabFontSizePoints), weight: .medium)
}
