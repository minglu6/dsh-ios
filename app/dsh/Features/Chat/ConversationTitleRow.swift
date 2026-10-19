import SwiftUI
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
            Rectangle()
                .fill(T.surface)
                .accessibilityElement()
                .accessibilityIdentifier(conversationTitleRowIdentifier())
                .allowsHitTesting(false)
        }
        .padding(.top, CGFloat(conversationHeaderPaddingTopPoints))
        .padding(.horizontal, CGFloat(conversationHeaderPaddingHorizontalPoints))
    }
}

func conversationHeaderTitleFont() -> Font {
    .system(size: CGFloat(conversationHeaderTitleFontSizePoints), weight: .medium)
}

func conversationHeaderTabFont() -> Font {
    .system(size: CGFloat(conversationHeaderTabFontSizePoints), weight: .medium)
}
