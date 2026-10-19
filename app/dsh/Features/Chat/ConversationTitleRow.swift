import SwiftUI
import UIKit
import DSHProtocol

/// Full-screen phone column. `maxWidth: .infinity` is not a width — it is an
/// unbounded ideal size. After a model popover remasure the chat VStack kept
/// that infinity and `composerInput` landed at `{{inf, inf},{0,0}}`.
var phoneColumnMaxWidth: CGFloat {
    let width = UIScreen.main.bounds.width
    precondition(width.isFinite && width > 0, "phone column width must be the screen")
    return width
}

/// Desktop `ConversationRoot.module.css` `.titleRow` `{ min-height:30px }`
/// inside `.header` padding. Shared by landing (`headerBlank`, no tabs) and
/// ChatView (title row then `.tabs { margin-top:10px }`).
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
            .buttonStyle(.plain)
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
            .buttonStyle(.plain)
            .disabled(startDisabled)
            .accessibilityLabel(L.startPanel())
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("openStartPanel")
        }
        .frame(
            minHeight: CGFloat(conversationHeaderTitleRowMinHeightPoints),
            maxHeight: CGFloat(conversationHeaderTitleRowMinHeightPoints),
            alignment: .center
        )
    }
}

func conversationHeaderTitleFont() -> Font {
    .system(size: CGFloat(conversationHeaderTitleFontSizePoints), weight: .medium)
}

func conversationHeaderTabFont() -> Font {
    .system(size: CGFloat(conversationHeaderTabFontSizePoints), weight: .medium)
}

/// Desktop `.header` / `.headerBlank` box: padding `10 14 0 14`, tabs case
/// `min-height:76` and `border-bottom:.5px l3`.
struct ConversationHeaderBox: ViewModifier {
    var blank: Bool

    func body(content: Content) -> some View {
        content
            .padding(.top, CGFloat(conversationHeaderPaddingTopPoints))
            .padding(.horizontal, CGFloat(conversationHeaderPaddingHorizontalPoints))
            .padding(
                .bottom,
                CGFloat(blank ? conversationHeaderBlankPaddingBottomPoints : 0)
            )
            // Cap at the screen — never `.infinity`. Title/tabs Spacers still
            // eat the offered width (b65811e). Spacing tokens unchanged.
            .frame(
                maxWidth: phoneColumnMaxWidth,
                minHeight: blank ? 0 : CGFloat(conversationHeaderMinHeightPoints),
                alignment: .top
            )
            .background(T.surface)
            .overlay(alignment: .bottom) {
                if !blank {
                    T.borderL3.frame(height: CGFloat(conversationHeaderBorderWidthPoints))
                }
            }
    }
}
